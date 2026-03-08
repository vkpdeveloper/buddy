import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { eq, and, asc } from 'drizzle-orm';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateObject } from 'ai';
import { env } from '../lib/env';
import { db } from '../db';
import { userProfile, dietPlans, dietDays, dietMeals, dietMealLogs, dailyLogs, dietQuickLogs, mealMediaAttachments } from '../db/schema';
import { calculateBMR, calculateTDEE, calculateMacros } from '../lib/macros';

const router = new Hono();
const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const DietPlanSchema = z.object({
    title: z.string().describe('Title of the 7-day diet plan'),
    days: z.array(z.object({
        dayNumber: z.number().int().describe('Day number from 1 to 7'),
        dayName: z.string().describe('Day name: MON, TUE, WED, THU, FRI, SAT, or SUN'),
        totalCalories: z.number().describe('Total calories for the day in kcal'),
        proteinG: z.number().describe('Total protein for the day in grams'),
        carbsG: z.number().describe('Total carbohydrates for the day in grams'),
        fatG: z.number().describe('Total fat for the day in grams'),
        meals: z.array(z.object({
            mealType: z.string().describe('Meal type identifier matching one of the requested meal types (e.g. breakfast, lunch, dinner, morning_snack, evening_snack, pre_workout, post_workout)'),
            mealName: z.string().describe('Name of the meal or dish'),
            ingredients: z.array(z.object({
                name: z.string().describe('Raw ingredient name without quality adjectives'),
                quantity: z.string().describe('Exact quantity with unit (e.g. "100g", "2 medium pieces", "1 tbsp", "200ml")'),
            })).describe('All ingredients used in the meal with exact quantities'),
            calories: z.number().describe('Total calories of this meal in kcal'),
            proteinG: z.number().describe('Protein content of this meal in grams'),
            carbsG: z.number().describe('Carbohydrate content of this meal in grams'),
            fatG: z.number().describe('Fat content of this meal in grams'),
            notes: z.string().describe('Preparation tips, soaking instructions, or short serving notes'),
            recipe: z.string().describe('Full recipe written in markdown: 2-3 intro sentences then a bullet list of cooking steps. Total 350-500 words.'),
        })).describe('All meals for this day. The number of meals must exactly match the meal types requested in the prompt.'),
    })).describe('Exactly 7 days of the diet plan (Monday through Sunday). You MUST generate all 7 days — do not stop early.'),
});

const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

// ─── High-Protein Food Lists (per diet type) ────────────────────────────────

export const HIGH_PROTEIN_FOODS = {
    vegetarian: [
        'Paneer', 'Tofu', 'Moong Dal', 'Masoor Dal', 'Chana Dal',
        'Toor Dal', 'Urad Dal', 'Rajma', 'Chole (Chickpeas)',
        'Dahi (Curd)', 'Greek Yogurt', 'Moong Sprouts',
        'Sattu', 'Soya Chunks', 'Skimmed Milk',
        'Peanut Butter', 'Makhana', 'Whey Protein',
    ],
    non_vegetarian: [
        'Chicken Breast', 'Whole Eggs', 'Egg Whites',
        'Tuna', 'Salmon', 'Prawn/Shrimp',
        'Fish (Rohu/Catla)', 'Lean Mutton Keema', 'Turkey',
        'Paneer', 'Moong Dal', 'Dahi (Curd)',
        'Greek Yogurt', 'Chicken Liver', 'Whey Protein',
        'Soya Chunks', 'Rajma', 'Chole (Chickpeas)',
    ],
    vegan: [
        'Tofu', 'Tempeh', 'Seitan', 'Edamame',
        'Moong Dal', 'Masoor Dal', 'Chole (Chickpeas)',
        'Rajma', 'Quinoa', 'Hemp Seeds',
        'Soya Chunks', 'Sattu', 'Peanut Butter',
        'Lentil Sprouts', 'Black Beans',
        'Pumpkin Seeds', 'Chia Seeds', 'Mung Bean Sprouts',
    ],
} as const;

// Foods that should ONLY appear in plans if the user explicitly selected them in preferences
const NICHE_FOODS = new Set([
    'sattu',
    'makhana',
    'tempeh',
    'seitan',
    'quinoa',
    'hemp seeds',
    'chia seeds',
    'pumpkin seeds',
    'edamame',
    'turkey',
    'soya chunks',
    'mung bean sprouts',
    'lentil sprouts',
    'black beans',
]);

// Canonical eating-time order for all meal types
const MEAL_ORDER: Record<string, number> = {
    breakfast: 1,
    morning_snack: 2,
    lunch: 3,
    pre_workout: 4,
    post_workout: 5,
    dinner: 6,
    evening_snack: 7,
};

const MEAL_LABELS: Record<string, string> = {
    breakfast: 'Breakfast',
    morning_snack: 'Morning Snack',
    lunch: 'Lunch',
    pre_workout: 'Pre-Workout',
    post_workout: 'Post-Workout',
    dinner: 'Dinner',
    evening_snack: 'Evening Snack',
};

const DEFAULT_MEAL_TIMES: Record<string, string> = {
    breakfast: '08:00',
    morning_snack: '11:00',
    lunch: '13:30',
    pre_workout: '17:00',
    post_workout: '19:00',
    dinner: '20:30',
    evening_snack: '22:00',
};

function normalizeMealTime(value: string | undefined, mealType: string): string {
    if (!value) return DEFAULT_MEAL_TIMES[mealType] ?? '12:00';
    if (/^\d{2}:\d{2}$/.test(value)) return value;
    return DEFAULT_MEAL_TIMES[mealType] ?? '12:00';
}

// ─── GET /api/diet/foods ─────────────────────────────────────────────────────
router.get('/foods', (c) => {
    return c.json({ success: true, data: HIGH_PROTEIN_FOODS });
});

// ─── GET /api/diet/plans ─────────────────────────────────────────────────────
router.get('/plans', async (c) => {
    try {
        const userId = c.var.userId;
        const plans = await db.select().from(dietPlans).where(eq(dietPlans.userId, userId)).orderBy(dietPlans.createdAt);
        return c.json({ success: true, data: plans });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/diet/plans/:id ─────────────────────────────────────────────────
router.get('/plans/:id', async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const [plan] = await db.select().from(dietPlans).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id)));
        if (!plan) return c.json({ success: false, error: 'Plan not found' }, 404);

        const days = await db.select().from(dietDays)
            .where(eq(dietDays.planId, id))
            .orderBy(dietDays.dayNumber);

        const daysWithMeals = await Promise.all(days.map(async (day) => {
            const meals = await db.select().from(dietMeals)
                .where(eq(dietMeals.dayId, day.id))
                .orderBy(asc(dietMeals.orderIndex));
            return { ...day, meals };
        }));

        return c.json({ success: true, data: { ...plan, days: daysWithMeals } });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/diet/generate ─────────────────────────────────────────────────
router.post('/generate', async (c) => {
    try {
        const userId = c.var.userId;
        const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
        if (profiles.length === 0) return c.json({ success: false, error: 'Profile not found. Set up profile first.' }, 400);
        const profile = profiles[0];

        const bmr = calculateBMR(profile.weight, profile.height, profile.age, profile.sex as any);
        const tdee = calculateTDEE(bmr, profile.activityLevel as any);
        const macros = calculateMacros(profile.weight, tdee, profile.goal as any, bmr);

        const useProteinPowder = profile.useProteinPowder;
        const preferredMeals: string[] = profile.preferredMeals;
        // Sort preferred meals by canonical eating order
        preferredMeals.sort((a, b) => (MEAL_ORDER[a] ?? 99) - (MEAL_ORDER[b] ?? 99));
        const mealTypesList = preferredMeals.map(m => `${m} (${MEAL_LABELS[m] ?? m})`).join(', ');
        const mealCount = preferredMeals.length;

        const dietType = (profile.dietType ?? 'vegetarian') as keyof typeof HIGH_PROTEIN_FOODS;
        const mealPrepTime = profile.mealPrepTime ?? '30min';
        const cookingBy = profile.cookingBy ?? 'myself';
        const preferredFoods: string[] = profile.preferredFoods;
        const preferredFoodsLower = new Set(preferredFoods.map(f => f.toLowerCase()));

        const dietLabels: Record<string, string> = {
            vegetarian: 'Indian vegetarian',
            non_vegetarian: 'Indian non-vegetarian (includes chicken, eggs, fish)',
            vegan: 'Indian vegan (strictly plant-based)',
        };
        const dietLabel = dietLabels[dietType];

        // Only include niche foods in the allowed protein list if the user selected them
        const allowedProteinFoods = HIGH_PROTEIN_FOODS[dietType].filter(
            food => !NICHE_FOODS.has(food.toLowerCase()) || preferredFoodsLower.has(food.toLowerCase())
        );
        const proteinFoods = allowedProteinFoods.join(', ');

        // Build an explicit exclusion list for niche foods the user did NOT select
        const excludedNicheFoods = HIGH_PROTEIN_FOODS[dietType]
            .filter(food => NICHE_FOODS.has(food.toLowerCase()) && !preferredFoodsLower.has(food.toLowerCase()));


        const mealPrepLabels: Record<string, string> = {
            '15min': '15 minutes or less per meal',
            '30min': '30 minutes or less per meal',
            '1hour': 'up to 1 hour per meal',
        };
        const mealPrepLabel = mealPrepLabels[mealPrepTime];

        const cookingContexts: Record<string, string> = {
            myself: 'The person cooks for themselves — prefer quick, minimal-prep meals. Avoid elaborate multi-step recipes.',
            maid: 'A household maid cooks — standard simple Indian home-cooked meals, nothing too specialized.',
        };
        const cookingContext = cookingContexts[cookingBy];

        const dietRules: Record<string, string> = {
            vegetarian: `- ONLY vegetarian Indian foods: dal varieties, paneer, tofu, curd/dahi, sprouts, rajma, chana, roti, rice, oats, upma, poha, etc.
- NO meat, fish, or eggs AT ALL`,
            non_vegetarian: `- Indian non-vegetarian foods allowed: chicken breast, eggs, fish (rohu, catla, tuna), prawns, lean mutton keema, etc.
- Combine with Indian carbs: roti, rice, oats, poha, upma
- Prioritize lean proteins: chicken breast and eggs over fatty cuts`,
            vegan: `- STRICTLY plant-based: NO dairy (no paneer, no curd, no milk, no ghee), NO eggs, NO meat
- Use tofu, all dal varieties, legumes, sprouts, and the high-protein staples listed above
- Replace ghee/butter with cold-pressed oils (coconut, mustard, groundnut)`,
        };
        const dietRule = dietRules[dietType];

        const planTitle = {
            vegetarian: '7-Day High Protein Indian Vegetarian Plan',
            non_vegetarian: '7-Day High Protein Indian Non-Vegetarian Plan',
            vegan: '7-Day High Protein Indian Vegan Plan',
        }[dietType];

        const nicheFoodExclusionNote = excludedNicheFoods.length > 0
            ? `\nSPECIALTY / NICHE FOODS — DO NOT USE:\nThe following foods are niche or region-specific and have NOT been selected by the user. You MUST NOT include them anywhere in the plan:\n${excludedNicheFoods.map(f => `  - ${f}`).join('\n')}\n`
            : '';

        const systemPrompt = `You are an expert ${dietLabel} sports nutritionist. Generate a detailed, practical 7-day high-protein ${dietLabel} diet plan calibrated for South Asian physiology.

DIET TYPE: ${dietLabel.toUpperCase()}
${dietRule}

MEAL PREPARATION CONSTRAINTS:
- Maximum prep time: ${mealPrepLabel}
- Cooking context: ${cookingContext}
- High-protein staples available for this diet type: ${proteinFoods}
${nicheFoodExclusionNote}${preferredFoods.length > 0 ? `
FAVOURITE FOODS (treat these as the user's preferred ingredients — build meals around them as much as possible across the 7 days):
${preferredFoods.map(f => `  - ${f}`).join('\n')}
These are foods the user loves and eats regularly. Feature them prominently in breakfast, lunch, dinner and snacks. Rotate creatively but keep them as the backbone of the plan.
` : ''}

IMPORTANT RULES:
- ONLY Indian foods and flavors — dal, roti, rice, sabzi, Indian spices, etc.
- HIGH PROTEIN focus — at least ${Math.round(macros.proteinG * 0.85)}g protein per day, featuring the listed protein staples prominently
${useProteinPowder ? '- Include protein powder shakes: once post-workout (if post_workout is in the list) and once as evening_snack (if evening_snack is in the list). Each shake = 25g protein, 120 kcal' : '- No protein powder, use whole food proteins only'}
- CRITICAL: Keep each day's total EXACTLY at ${macros.calories} kcal ±50 kcal
- Protein target: ${macros.proteinG}g | Carbs: ${macros.carbsG}g | Fat: ${macros.fatG}g
- Indian portion sizes — realistic quantities (e.g., "2 medium rotis (60g)", "1 bowl dal (150ml)", "100g paneer")
- Vary meals each day — do NOT repeat the same meals across 7 days
- ONLY use these meal types (in this order): ${mealTypesList}
- Generate exactly ${mealCount} meals per day using ONLY the meal types listed above
- Meals must be feasible within the ${mealPrepLabel} prep time limit

INGREDIENT RULES:
- Each ingredient must have a RAW "name" (no quality adjectives like "fresh", "good quality") and an exact "quantity" (e.g., "100g", "2 medium pieces", "1 tbsp", "200ml")
- List every ingredient by its raw weight/volume as it would be measured before cooking
- Do NOT include a "description" field — ingredients replace it

RECIPE RULES:
- Include a "recipe" field for every meal written in markdown, formatted like a proper recipe book entry
- Start with 2–3 sentences introducing the dish: what it is, its flavour/texture, and why it fits the plan
- Then add a blank line, followed by the full cooking method as a markdown bullet list (use "- " prefix)
- Cover every meaningful step: soaking/marinating, prep work, cooking sequence, heat levels, timing cues, seasoning adjustments, and how to plate or serve
- Be specific — mention exact pan types, flame levels (low/medium/high), visual doneness cues ("until golden", "until oil separates"), and small tips that make the dish better
- Do NOT artificially limit the number of steps — use as many bullets as the recipe genuinely needs
- Total length: 350–500 words; do NOT exceed 550 words
- Use plain language; bold (**word**) only key technique words or timing cues if helpful

STRICT: Only use meal types from this list: ${preferredMeals.join(', ')}. Do not add any other meal types.`;

        const { object: planData } = await generateObject({
            model: google('gemini-3.1-flash-lite-preview'),
            schema: DietPlanSchema,
            system: systemPrompt,
            prompt: `Generate the complete 7-day diet plan (all 7 days, Monday through Sunday) for a ${profile.age}-year-old ${profile.sex} weighing ${profile.weight}kg, height ${profile.height}cm. Goal: ${profile.goal.replace('_', ' ')}. Activity: ${profile.activityLevel.replace('_', ' ')}. Each day must have exactly ${mealCount} meals: ${preferredMeals.join(', ')}.`,
            maxOutputTokens: 16000,
        });

        // Deactivate all existing plans for this user
        await db.update(dietPlans).set({ isActive: false }).where(eq(dietPlans.userId, userId));

        // Insert the new plan
        const [insertedPlan] = await db.insert(dietPlans).values({
            userId,
            title: planData.title ?? '7-Day Diet Plan',
            totalCalories: macros.calories,
            proteinG: macros.proteinG,
            carbsG: macros.carbsG,
            fatG: macros.fatG,
            isActive: true,
        }).returning();

        // Insert days and meals
        for (const day of planData.days) {
            const [insertedDay] = await db.insert(dietDays).values({
                planId: insertedPlan.id,
                dayNumber: day.dayNumber,
                dayName: day.dayName ?? DAY_NAMES[(day.dayNumber - 1) % 7],
                totalCalories: day.totalCalories ?? macros.calories,
                proteinG: day.proteinG ?? macros.proteinG,
                carbsG: day.carbsG ?? macros.carbsG,
                fatG: day.fatG ?? macros.fatG,
            }).returning();

            const sortedMeals = [...day.meals].sort((a, b) => {
                const left = MEAL_ORDER[a.mealType] ?? 99;
                const right = MEAL_ORDER[b.mealType] ?? 99;
                return left - right;
            });
            let index = 0;
            for (const meal of sortedMeals) {
                index += 1;
                await db.insert(dietMeals).values({
                    dayId: insertedDay.id,
                    orderIndex: index,
                    mealType: meal.mealType as any,
                    mealTime: normalizeMealTime(undefined, meal.mealType),
                    mealName: meal.mealName,
                    description: '',
                    ingredients: JSON.stringify(meal.ingredients),
                    calories: meal.calories,
                    proteinG: meal.proteinG,
                    carbsG: meal.carbsG,
                    fatG: meal.fatG,
                    notes: meal.notes,
                    recipe: meal.recipe,
                });
            }
        }

        return c.json({ success: true, data: { planId: insertedPlan.id, macros } });
    } catch (err) {
        console.error('[diet/generate]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/plans/:id ─────────────────────────────────────────────────
router.put('/plans/:id', zValidator('json', z.object({
    title: z.string().optional(),
    isActive: z.boolean().optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(dietPlans).set(body).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id))).returning();
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── DELETE /api/diet/plans/:id ──────────────────────────────────────────────
router.delete('/plans/:id', async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        await db.delete(dietPlans).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id)));
        return c.json({ success: true });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/meals/:id ─────────────────────────────────────────────────
router.put('/meals/:id', zValidator('json', z.object({
    mealName: z.string().optional(),
    mealTime: z.string().regex(/^\d{2}:\d{2}$/).optional(),
    description: z.string().optional(),
    ingredients: z.array(z.object({ name: z.string(), quantity: z.string() })).optional(),
    calories: z.number().optional(),
    proteinG: z.number().optional(),
    carbsG: z.number().optional(),
    fatG: z.number().optional(),
    orderIndex: z.number().int().positive().optional(),
    isCompleted: z.boolean().optional(),
    notes: z.string().optional(),
})), async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const { ingredients, ...rest } = c.req.valid('json');
        const body: Record<string, any> = { ...rest };
        if (ingredients !== undefined) body.ingredients = JSON.stringify(ingredients);
        const updated = await db.update(dietMeals).set(body).where(eq(dietMeals.id, id)).returning();
        if (updated.length === 0) return c.json({ success: false, error: 'Meal not found' }, 404);
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/days/:id/reorder ─────────────────────────────────────────
router.put('/days/:id/reorder', zValidator('json', z.object({
    mealIds: z.array(z.number().int().positive()).min(1),
})), async (c) => {
    try {
        const dayId = parseInt(c.req.param('id'));
        const { mealIds } = c.req.valid('json');
        const dayMeals = await db.select().from(dietMeals).where(eq(dietMeals.dayId, dayId));
        const dayMealIds = new Set(dayMeals.map((m) => m.id));

        for (const id of mealIds) {
            if (!dayMealIds.has(id)) {
                return c.json({ success: false, error: `Meal ${id} is not in this day` }, 400);
            }
        }

        for (let i = 0; i < mealIds.length; i += 1) {
            const mealId = mealIds[i];
            await db.update(dietMeals)
                .set({ orderIndex: i + 1 })
                .where(eq(dietMeals.id, mealId));
        }

        const reordered = await db.select().from(dietMeals)
            .where(eq(dietMeals.dayId, dayId))
            .orderBy(asc(dietMeals.orderIndex));
        return c.json({ success: true, data: reordered });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/days/:id ──────────────────────────────────────────────────
router.put('/days/:id', zValidator('json', z.object({
    isCompleted: z.boolean().optional(),
})), async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(dietDays).set(body).where(eq(dietDays.id, id)).returning();
        if (updated.length === 0) return c.json({ success: false, error: 'Day not found' }, 404);
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/diet/log/:date ─────────────────────────────────────────────────
// Returns daily meal completion + actual intake + hydration snapshot
router.get('/log/:date', async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date'); // YYYY-MM-DD
        const logs = await db.select().from(dietMealLogs).where(eq(dietMealLogs.date, date));
        const completionMap: Record<number, boolean> = {};
        const actualLogs: Record<number, {
            mealName: string;
            calories: number;
            proteinG: number;
            carbsG: number;
            fatG: number;
            notes: string;
            rawPayload: unknown;
        }> = {};
        let consumedCalories = 0;
        let consumedProteinG = 0;
        let consumedCarbsG = 0;
        let consumedFatG = 0;

        for (const log of logs) {
            completionMap[log.mealId] = log.isCompleted;

            if (log.actualMealName || log.actualCalories || log.actualProteinG || log.actualCarbsG || log.actualFatG) {
                const calories = log.actualCalories ?? 0;
                const proteinG = log.actualProteinG ?? 0;
                const carbsG = log.actualCarbsG ?? 0;
                const fatG = log.actualFatG ?? 0;
                consumedCalories += calories;
                consumedProteinG += proteinG;
                consumedCarbsG += carbsG;
                consumedFatG += fatG;

                let rawPayload: unknown = {};
                try {
                    rawPayload = JSON.parse(log.rawPayload);
                } catch {
                    rawPayload = {};
                }

                actualLogs[log.mealId] = {
                    mealName: log.actualMealName,
                    calories,
                    proteinG,
                    carbsG,
                    fatG,
                    notes: log.actualNotes,
                    rawPayload,
                };
            }
        }

        // Quick logs (standalone photo-captured meals)
        const quickLogRows = await db
            .select()
            .from(dietQuickLogs)
            .where(and(eq(dietQuickLogs.userId, userId), eq(dietQuickLogs.date, date)));

        // Fetch attachments for quick logs that have photos
        const attachmentIds = quickLogRows.map(q => q.attachmentId).filter((id): id is number => id != null);
        const attachmentMap = new Map<number, string>();
        if (attachmentIds.length > 0) {
            const { inArray } = await import('drizzle-orm');
            const { signPrivateObjectUrl } = await import('../lib/r2');
            const attachments = await db.select().from(mealMediaAttachments).where(inArray(mealMediaAttachments.id, attachmentIds));
            await Promise.all(attachments.map(async (att) => {
                const url = await signPrivateObjectUrl(att.objectKey);
                attachmentMap.set(att.id, url);
            }));
        }

        const quickLogs = quickLogRows.map(q => ({
            id: q.id,
            mealName: q.mealName,
            calories: q.calories,
            proteinG: q.proteinG,
            carbsG: q.carbsG,
            fatG: q.fatG,
            notes: q.notes,
            attachmentId: q.attachmentId,
            signedUrl: q.attachmentId != null ? (attachmentMap.get(q.attachmentId) ?? null) : null,
            loggedAt: q.loggedAt,
        }));

        for (const q of quickLogRows) {
            consumedCalories += q.calories;
            consumedProteinG += q.proteinG;
            consumedCarbsG += q.carbsG;
            consumedFatG += q.fatG;
        }

        const [daily] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
        const hydrationMl = daily?.waterMl ?? 0;

        return c.json({
            success: true,
            data: {
                completionMap,
                actualLogs,
                quickLogs,
                consumedTotals: {
                    calories: consumedCalories,
                    proteinG: consumedProteinG,
                    carbsG: consumedCarbsG,
                    fatG: consumedFatG,
                },
                hydrationMl,
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/log/:date ─────────────────────────────────────────────────
// Upsert meal completion for a specific date
router.put('/log/:date', zValidator('json', z.object({
    mealId: z.number().int(),
    isCompleted: z.boolean(),
})), async (c) => {
    try {
        const date = c.req.param('date');
        const { mealId, isCompleted } = c.req.valid('json');

        // Check if log entry exists
        const [existing] = await db.select().from(dietMealLogs)
            .where(and(eq(dietMealLogs.mealId, mealId), eq(dietMealLogs.date, date)));

        if (existing) {
            await db.update(dietMealLogs)
                .set({ isCompleted, loggedAt: new Date().toISOString() })
                .where(eq(dietMealLogs.id, existing.id));
        } else {
            await db.insert(dietMealLogs).values({ mealId, date, isCompleted });
        }

        return c.json({ success: true });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/log/:date/actual ─────────────────────────────────────────
router.put('/log/:date/actual', zValidator('json', z.object({
    mealId: z.number().int().positive(),
    mealName: z.string().min(1),
    calories: z.number().int().min(0),
    proteinG: z.number().min(0),
    carbsG: z.number().min(0),
    fatG: z.number().min(0),
    notes: z.string().optional(),
    rawPayload: z.record(z.string(), z.unknown()).optional(),
    attachmentId: z.number().int().positive().optional(),
})), async (c) => {
    try {
        const date = c.req.param('date');
        const {
            mealId,
            mealName,
            calories,
            proteinG,
            carbsG,
            fatG,
            notes,
            rawPayload,
            attachmentId,
        } = c.req.valid('json');

        const [existing] = await db.select().from(dietMealLogs)
            .where(and(eq(dietMealLogs.mealId, mealId), eq(dietMealLogs.date, date)));

        const mergedPayload: Record<string, unknown> = { ...(rawPayload ?? {}) };
        if (attachmentId != null) {
            mergedPayload.attachmentId = attachmentId;
            mergedPayload.source = mergedPayload.source ?? 'ai_photo_analysis';
        }

        const values = {
            isCompleted: true,
            actualMealName: mealName,
            actualCalories: calories,
            actualProteinG: proteinG,
            actualCarbsG: carbsG,
            actualFatG: fatG,
            actualNotes: notes ?? '',
            rawPayload: JSON.stringify(mergedPayload),
            loggedAt: new Date().toISOString(),
        };

        if (existing) {
            await db.update(dietMealLogs)
                .set(values)
                .where(eq(dietMealLogs.id, existing.id));
        } else {
            await db.insert(dietMealLogs).values({
                mealId,
                date,
                ...values,
            });
        }

        return c.json({ success: true });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/diet/log/:date/quick ──────────────────────────────────────────
// Logs a standalone photo-captured meal not tied to any meal plan entry
router.post('/log/:date/quick', zValidator('json', z.object({
    mealName: z.string().min(1),
    calories: z.number().int().min(0),
    proteinG: z.number().min(0),
    carbsG: z.number().min(0),
    fatG: z.number().min(0),
    notes: z.string().optional(),
    attachmentId: z.number().int().positive().optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date');
        const { mealName, calories, proteinG, carbsG, fatG, notes, attachmentId } = c.req.valid('json');

        const [inserted] = await db.insert(dietQuickLogs).values({
            userId,
            date,
            mealName,
            calories,
            proteinG,
            carbsG,
            fatG,
            notes: notes ?? '',
            attachmentId: attachmentId ?? null,
            loggedAt: new Date().toISOString(),
        }).returning();

        // Fetch signed URL for attachment if present
        let signedUrl: string | null = null;
        if (attachmentId) {
            const [att] = await db.select().from(mealMediaAttachments).where(eq(mealMediaAttachments.id, attachmentId)).limit(1);
            if (att) {
                const { signPrivateObjectUrl } = await import('../lib/r2');
                signedUrl = await signPrivateObjectUrl(att.objectKey);
            }
        }

        return c.json({
            success: true,
            data: { ...inserted, signedUrl },
        });
    } catch (err) {
        console.error('[diet/log/quick] error:', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

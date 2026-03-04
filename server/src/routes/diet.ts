import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { eq, and } from 'drizzle-orm';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateText } from 'ai';
import { env } from '../lib/env';
import { db } from '../db';
import { userProfile, dietPlans, dietDays, dietMeals, dietMealLogs } from '../db/schema';
import { calculateBMR, calculateTDEE, calculateMacros } from '../lib/macros';

const router = new Hono();
const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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

// ─── GET /api/diet/plans ─────────────────────────────────────────────────────
router.get('/plans', async (c) => {
    try {
        const plans = await db.select().from(dietPlans).orderBy(dietPlans.createdAt);
        return c.json({ success: true, data: plans });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/diet/plans/:id ─────────────────────────────────────────────────
router.get('/plans/:id', async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const [plan] = await db.select().from(dietPlans).where(eq(dietPlans.id, id));
        if (!plan) return c.json({ success: false, error: 'Plan not found' }, 404);

        const days = await db.select().from(dietDays)
            .where(eq(dietDays.planId, id))
            .orderBy(dietDays.dayNumber);

        const daysWithMeals = await Promise.all(days.map(async (day) => {
            const meals = await db.select().from(dietMeals)
                .where(eq(dietMeals.dayId, day.id));
            meals.sort((a, b) => (MEAL_ORDER[a.mealType] ?? 99) - (MEAL_ORDER[b.mealType] ?? 99));
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
        const profiles = await db.select().from(userProfile).limit(1);
        if (profiles.length === 0) return c.json({ success: false, error: 'Profile not found. Set up profile first.' }, 400);
        const profile = profiles[0];

        const bmr = calculateBMR(profile.weight, profile.height, profile.age, profile.sex as any);
        const tdee = calculateTDEE(bmr, profile.activityLevel as any);
        const macros = calculateMacros(profile.weight, tdee, profile.goal as any, bmr);

        const useProteinPowder = profile.useProteinPowder;
        const preferredMeals: string[] = JSON.parse(profile.preferredMeals);
        // Sort preferred meals by canonical eating order
        preferredMeals.sort((a, b) => (MEAL_ORDER[a] ?? 99) - (MEAL_ORDER[b] ?? 99));
        const mealTypesList = preferredMeals.map(m => `${m} (${MEAL_LABELS[m] ?? m})`).join(', ');
        const mealCount = preferredMeals.length;

        const systemPrompt = `You are an expert Indian vegetarian sports nutritionist. Generate a detailed, practical 7-day high-protein vegetarian diet plan calibrated for South Asian physiology.

IMPORTANT RULES:
- ONLY Indian foods: dal (moong, masoor, chana, toor, urad), roti, rice, sabzi, paneer, curd/dahi, sprouts, rajma, chana, tofu, oats (Indian style), upma, poha, sattu, makhana, etc.
- NO meat, eggs, or non-vegetarian items AT ALL
- HIGH PROTEIN focus — at least ${Math.round(macros.proteinG * 0.85)}g protein per day using dal-based proteins prominently
${useProteinPowder ? '- Include protein powder shakes: once post-workout (if post_workout is in the list) and once as evening_snack (if evening_snack is in the list). Each shake = 25g protein, 120 kcal' : '- No protein powder, use whole food proteins only'}
- CRITICAL: Keep each day's total EXACTLY at ${macros.calories} kcal ±50 kcal
- The calorie target is already adjusted for Indian BMR (South Asian correction applied) — do NOT increase it
- Protein target: ${macros.proteinG}g | Carbs: ${macros.carbsG}g | Fat: ${macros.fatG}g
- Indian portion sizes are typically smaller than Western — use realistic quantities (e.g., "2 medium rotis (60g)", "1 bowl dal (150ml)", "100g paneer")
- Vary meals each day — do NOT repeat the same meals across 7 days
- Keep it REALISTIC for an Indian home/office lifestyle
- Include quantities with every item
- ONLY use these meal types (in this order): ${mealTypesList}
- Generate exactly ${mealCount} meals per day using ONLY the meal types listed above

Return ONLY a valid JSON object in this EXACT structure (no markdown, no explanation):
{
  "title": "7-Day High Protein Indian Vegetarian Plan",
  "days": [
    {
      "dayNumber": 1,
      "dayName": "Monday",
      "totalCalories": 2100,
      "proteinG": 160,
      "carbsG": 220,
      "fatG": 58,
      "meals": [
        {
          "mealType": "breakfast",
          "mealName": "Moong Dal Chilla with Mint Chutney",
          "description": "3 moong dal chillas (100g batter each) with homemade mint-coriander chutney",
          "calories": 380,
          "proteinG": 22,
          "carbsG": 45,
          "fatG": 8,
          "notes": "Use green moong dal soaked overnight"
        }
      ]
    }
  ]
}

STRICT: Only use meal types from this list: ${preferredMeals.join(', ')}. Do not add any other meal types.`;

        const { text } = await generateText({
            model: google('gemini-3.1-flash-lite-preview'),
            system: systemPrompt,
            prompt: `Generate the full 7-day diet plan for a ${profile.age}-year-old ${profile.sex} weighing ${profile.weight}kg, height ${profile.height}cm. Goal: ${profile.goal.replace('_', ' ')}. Activity: ${profile.activityLevel.replace('_', ' ')}.`,
            maxOutputTokens: 8000,
        });

        let planData: any;
        try {
            const jsonMatch = text.match(/\{[\s\S]*\}/);
            if (!jsonMatch) throw new Error('No JSON found in response');
            planData = JSON.parse(jsonMatch[0]);
        } catch (parseErr) {
            console.error('Failed to parse AI response:', text.substring(0, 500));
            return c.json({ success: false, error: 'AI returned invalid JSON. Please try again.' }, 500);
        }

        // Deactivate all existing plans
        await db.update(dietPlans).set({ isActive: false });

        // Insert the new plan
        const [insertedPlan] = await db.insert(dietPlans).values({
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

            if (day.meals && Array.isArray(day.meals)) {
                for (const meal of day.meals) {
                    await db.insert(dietMeals).values({
                        dayId: insertedDay.id,
                        mealType: meal.mealType ?? 'breakfast',
                        mealName: meal.mealName ?? meal.name ?? 'Meal',
                        description: meal.description ?? '',
                        calories: meal.calories ?? 300,
                        proteinG: meal.proteinG ?? meal.protein_g ?? 20,
                        carbsG: meal.carbsG ?? meal.carbs_g ?? 30,
                        fatG: meal.fatG ?? meal.fat_g ?? 10,
                        notes: meal.notes ?? '',
                    });
                }
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
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(dietPlans).set(body).where(eq(dietPlans.id, id)).returning();
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── DELETE /api/diet/plans/:id ──────────────────────────────────────────────
router.delete('/plans/:id', async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        await db.delete(dietPlans).where(eq(dietPlans.id, id));
        return c.json({ success: true });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/diet/meals/:id ─────────────────────────────────────────────────
router.put('/meals/:id', zValidator('json', z.object({
    mealName: z.string().optional(),
    description: z.string().optional(),
    calories: z.number().optional(),
    proteinG: z.number().optional(),
    carbsG: z.number().optional(),
    fatG: z.number().optional(),
    isCompleted: z.boolean().optional(),
    notes: z.string().optional(),
})), async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(dietMeals).set(body).where(eq(dietMeals.id, id)).returning();
        if (updated.length === 0) return c.json({ success: false, error: 'Meal not found' }, 404);
        return c.json({ success: true, data: updated[0] });
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
// Returns a map of { mealId -> isCompleted } for the given date
router.get('/log/:date', async (c) => {
    try {
        const date = c.req.param('date'); // YYYY-MM-DD
        const logs = await db.select().from(dietMealLogs).where(eq(dietMealLogs.date, date));
        const map: Record<number, boolean> = {};
        for (const log of logs) {
            map[log.mealId] = log.isCompleted;
        }
        return c.json({ success: true, data: map });
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

export default router;

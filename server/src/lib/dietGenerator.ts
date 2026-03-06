import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateObject } from 'ai';
import { eq } from 'drizzle-orm';
import { env } from './env';
import { z } from 'zod';
import { db } from '../db';
import { userProfile, dietPlans, dietDays, dietMeals } from '../db/schema';
import { calculateBMR, calculateTDEE, calculateMacros } from './macros';

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
    })).describe('Exactly 7 days of the diet plan (Mon through Sun). You MUST generate all 7 days — do not stop early.'),
});

const DAY_NAMES = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

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

const NICHE_FOODS = new Set([
    'sattu', 'makhana', 'tempeh', 'seitan', 'quinoa', 'hemp seeds',
    'chia seeds', 'pumpkin seeds', 'edamame', 'turkey', 'soya chunks',
    'mung bean sprouts', 'lentil sprouts', 'black beans',
]);

const MEAL_ORDER: Record<string, number> = {
    breakfast: 1, morning_snack: 2, lunch: 3, pre_workout: 4,
    post_workout: 5, dinner: 6, evening_snack: 7,
};

const MEAL_LABELS: Record<string, string> = {
    breakfast: 'Breakfast', morning_snack: 'Morning Snack', lunch: 'Lunch',
    pre_workout: 'Pre-Workout', post_workout: 'Post-Workout',
    dinner: 'Dinner', evening_snack: 'Evening Snack',
};

export async function runDietGeneration(userId: string): Promise<{ planId: number }> {
    const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
    if (profiles.length === 0) throw new Error('Profile not found. Set up profile first.');
    const profile = profiles[0];

    const bmr = calculateBMR(profile.weight, profile.height, profile.age, profile.sex as any);
    const tdee = calculateTDEE(bmr, profile.activityLevel as any);
    const macros = calculateMacros(profile.weight, tdee, profile.goal as any, bmr);

    const useProteinPowder = profile.useProteinPowder;
    const preferredMeals: string[] = JSON.parse(profile.preferredMeals);
    preferredMeals.sort((a, b) => (MEAL_ORDER[a] ?? 99) - (MEAL_ORDER[b] ?? 99));
    const mealTypesList = preferredMeals.map(m => `${m} (${MEAL_LABELS[m] ?? m})`).join(', ');
    const mealCount = preferredMeals.length;

    const dietType = (profile.dietType ?? 'vegetarian') as keyof typeof HIGH_PROTEIN_FOODS;
    const mealPrepTime = profile.mealPrepTime ?? '30min';
    const cookingBy = profile.cookingBy ?? 'myself';
    const preferredFoods: string[] = JSON.parse(profile.preferredFoods ?? '[]');
    const preferredFoodsLower = new Set(preferredFoods.map(f => f.toLowerCase()));

    const dietLabels: Record<string, string> = {
        vegetarian: 'Indian vegetarian',
        non_vegetarian: 'Indian non-vegetarian (includes chicken, eggs, fish)',
        vegan: 'Indian vegan (strictly plant-based)',
    };
    const dietLabel = dietLabels[dietType];

    const allowedProteinFoods = HIGH_PROTEIN_FOODS[dietType].filter(
        food => !NICHE_FOODS.has(food.toLowerCase()) || preferredFoodsLower.has(food.toLowerCase())
    );
    const proteinFoods = allowedProteinFoods.join(', ');

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
        vegetarian: `- ONLY vegetarian Indian foods: dal varieties, paneer, tofu, curd/dahi, sprouts, rajma, chana, roti, rice, oats, upma, poha, etc.\n- NO meat, fish, or eggs AT ALL`,
        non_vegetarian: `- Indian non-vegetarian foods allowed: chicken breast, eggs, fish (rohu, catla, tuna), prawns, lean mutton keema, etc.\n- Combine with Indian carbs: roti, rice, oats, poha, upma\n- Prioritize lean proteins: chicken breast and eggs over fatty cuts`,
        vegan: `- STRICTLY plant-based: NO dairy (no paneer, no curd, no milk, no ghee), NO eggs, NO meat\n- Use tofu, all dal varieties, legumes, sprouts, and the high-protein staples listed above\n- Replace ghee/butter with cold-pressed oils (coconut, mustard, groundnut)`,
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
- Each ingredient must have a RAW "name" and an exact "quantity"
- Do NOT include a "description" field

RECIPE RULES:
- Include a "recipe" field for every meal written in markdown
- Start with 2–3 sentences introducing the dish
- Then add a blank line, followed by the full cooking method as a markdown bullet list
- Total length: 350–500 words

STRICT: Only use meal types from this list: ${preferredMeals.join(', ')}.`;

    const { object: planData } = await generateObject({
        model: google('gemini-3.1-flash-lite-preview'),
        schema: DietPlanSchema,
        system: systemPrompt,
        prompt: `Generate the complete 7-day diet plan (all 7 days, Monday through Sunday) for a ${profile.age}-year-old ${profile.sex} weighing ${profile.weight}kg, height ${profile.height}cm. Goal: ${profile.goal.replace('_', ' ')}. Activity: ${profile.activityLevel.replace('_', ' ')}. Each day must have exactly ${mealCount} meals: ${preferredMeals.join(', ')}.`,
        maxOutputTokens: 16000,
    });

    await db.update(dietPlans).set({ isActive: false });

    const [insertedPlan] = await db.insert(dietPlans).values({
        userId,
        title: planData.title ?? '7-Day Diet Plan',
        totalCalories: macros.calories,
        proteinG: macros.proteinG,
        carbsG: macros.carbsG,
        fatG: macros.fatG,
        isActive: true,
    }).returning();

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

        for (const meal of day.meals) {
            await db.insert(dietMeals).values({
                dayId: insertedDay.id,
                mealType: meal.mealType as any,
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

    return { planId: insertedPlan.id };
}

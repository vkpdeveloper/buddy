import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { userProfile } from '../db/schema';

const router = new Hono();

// GET /api/profile — get (or create default) profile
router.get('/', async (c) => {
    try {
        const profiles = await db.select().from(userProfile).limit(1);

        if (profiles.length === 0) {
            return c.json({ success: true, data: null, exists: false });
        }

        return c.json({ success: true, data: profiles[0], exists: true });
    } catch (err) {
        console.error('[profile GET]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

const profileSchema = z.object({
    name: z.string().optional(),
    height: z.number().min(100).max(250).optional(),
    weight: z.number().min(30).max(300).optional(),
    age: z.number().min(10).max(100).optional(),
    sex: z.enum(['male', 'female']).optional(),
    goal: z.enum(['muscle_gain', 'fat_loss', 'recomp', 'maintain', 'endurance']).optional(),
    activityLevel: z.enum(['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'athlete']).optional(),
    weeklyWorkoutDays: z.number().int().min(1).max(7).optional(),
    equipment: z.array(z.string()).optional(),
    workoutCycle: z.enum(['ppl', 'upper_lower', 'ppl_upper', 'full_body']).optional(),
    useProteinPowder: z.boolean().optional(),
    proteinLevel: z.enum(['high', 'moderate']).optional(),
    waterTargetMl: z.number().int().min(500).max(6000).optional(),
    weightGoalKg: z.number().min(30).max(300).optional(),
    preferredMeals: z.array(z.enum(['breakfast', 'morning_snack', 'lunch', 'pre_workout', 'post_workout', 'dinner', 'evening_snack'])).min(2).optional(),
    dietType: z.enum(['vegetarian', 'non_vegetarian', 'vegan']).optional(),
    mealPrepTime: z.enum(['15min', '30min', '1hour']).optional(),
    cookingBy: z.enum(['myself', 'maid']).optional(),
    preferredFoods: z.array(z.string()).optional(),
    profileCompleted: z.boolean().optional(),
});

// PUT /api/profile — upsert profile
router.put('/', zValidator('json', profileSchema), async (c) => {
    try {
        const body = c.req.valid('json');

        const profiles = await db.select().from(userProfile).limit(1);

        const updateData: typeof userProfile.$inferInsert = {};
        if (body.name !== undefined) updateData.name = body.name;
        if (body.height !== undefined) updateData.height = body.height;
        if (body.weight !== undefined) updateData.weight = body.weight;
        if (body.age !== undefined) updateData.age = body.age;
        if (body.sex !== undefined) updateData.sex = body.sex;
        if (body.goal !== undefined) updateData.goal = body.goal;
        if (body.activityLevel !== undefined) updateData.activityLevel = body.activityLevel;
        if (body.weeklyWorkoutDays !== undefined) updateData.weeklyWorkoutDays = body.weeklyWorkoutDays;
        if (body.equipment !== undefined) updateData.equipment = JSON.stringify(body.equipment);
        if (body.workoutCycle !== undefined) updateData.workoutCycle = body.workoutCycle;
        if (body.useProteinPowder !== undefined) updateData.useProteinPowder = body.useProteinPowder;
        if (body.proteinLevel !== undefined) updateData.proteinLevel = body.proteinLevel;
        if (body.waterTargetMl !== undefined) updateData.waterTargetMl = body.waterTargetMl;
        if (body.weightGoalKg !== undefined) updateData.weightGoalKg = body.weightGoalKg;
        if (body.preferredMeals !== undefined) updateData.preferredMeals = JSON.stringify(body.preferredMeals);
        if (body.dietType !== undefined) updateData.dietType = body.dietType;
        if (body.mealPrepTime !== undefined) updateData.mealPrepTime = body.mealPrepTime;
        if (body.cookingBy !== undefined) updateData.cookingBy = body.cookingBy as 'myself' | 'maid';
        if (body.preferredFoods !== undefined) updateData.preferredFoods = JSON.stringify(body.preferredFoods);
        if (body.profileCompleted !== undefined) updateData.profileCompleted = body.profileCompleted;

        let result;
        if (profiles.length === 0) {
            result = await db.insert(userProfile).values(updateData).returning();
        } else {
            result = await db.update(userProfile)
                .set(updateData)
                .where(eq(userProfile.id, profiles[0].id))
                .returning();
        }

        return c.json({ success: true, data: result[0] });
    } catch (err) {
        console.error('[profile PUT]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

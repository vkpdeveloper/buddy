import { Hono } from 'hono';
import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { userProfile } from '../db/schema';
import { ok } from '../lib/response';
import { notFound } from '../lib/errors';

const router = new Hono();

// GET /api/profile — get profile for the authenticated user
router.get('/', async (c) => {
    const userId = c.var.userId;
    const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);

    if (profiles.length === 0) {
        throw notFound('Profile not found');
    }

    return ok(c, profiles[0]);
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
    bodyFatGoalPercent: z.number().min(3).max(70).optional(),
    preferredMeals: z.array(z.enum(['breakfast', 'morning_snack', 'lunch', 'pre_workout', 'post_workout', 'dinner', 'evening_snack'])).min(2).optional(),
    dietType: z.enum(['vegetarian', 'non_vegetarian', 'vegan']).optional(),
    mealPrepTime: z.enum(['15min', '30min', '1hour']).optional(),
    cookingBy: z.enum(['myself', 'maid']).optional(),
    preferredFoods: z.array(z.string()).optional(),
    profileCompleted: z.boolean().optional(),
    preferSupersets: z.boolean().optional(),
    experienceLevel: z.enum(['beginner', 'intermediate', 'advanced']).optional(),
    whyNow: z.enum(['look_better', 'feel_better', 'perform_better', 'build_routine']).optional(),
    goalPace: z.enum(['relaxed', 'steady', 'aggressive']).optional(),
    primaryBlocker: z.enum(['consistency', 'food_choices', 'busy_schedule', 'lack_of_structure', 'low_motivation']).optional(),
    currentBodyShape: z.enum(['skinny', 'lean', 'fat']).optional(),
    goalBodyShape: z.enum(['skinny', 'lean', 'fat']).optional(),
});

// PUT /api/profile — upsert profile for the authenticated user
router.put('/', async (c) => {
    const userId = c.var.userId;

    let raw: Record<string, unknown>;
    try {
        raw = await c.req.json();
    } catch {
        return c.json({ success: false, error: 'Invalid JSON body' }, 400);
    }

    // Strip empty strings and nulls — Zod optional() rejects both
    const cleaned = Object.fromEntries(
        Object.entries(raw).filter(([, v]) => v !== null && v !== ''),
    );

    const parsed = profileSchema.safeParse(cleaned);
    if (!parsed.success) {
        console.error('[PUT /api/profile] Validation failed:');
        for (const issue of parsed.error.issues) {
            console.error(`  field="${issue.path.join('.')}" code=${issue.code} message="${issue.message}"`);
        }
        return c.json({ success: false, error: parsed.error }, 400);
    }

    const body = parsed.data;
    const profiles = await db.select({ id: userProfile.id }).from(userProfile).where(eq(userProfile.userId, userId)).limit(1);

    const updateData: Partial<typeof userProfile.$inferInsert> = { userId };
    if (body.name !== undefined) updateData.name = body.name;
    if (body.height !== undefined) updateData.height = body.height;
    if (body.weight !== undefined) updateData.weight = body.weight;
    if (body.age !== undefined) updateData.age = body.age;
    if (body.sex !== undefined) updateData.sex = body.sex;
    if (body.goal !== undefined) updateData.goal = body.goal;
    if (body.activityLevel !== undefined) updateData.activityLevel = body.activityLevel;
    if (body.weeklyWorkoutDays !== undefined) updateData.weeklyWorkoutDays = body.weeklyWorkoutDays;
    if (body.equipment !== undefined) updateData.equipment = body.equipment;
    if (body.workoutCycle !== undefined) updateData.workoutCycle = body.workoutCycle;
    if (body.useProteinPowder !== undefined) updateData.useProteinPowder = body.useProteinPowder;
    if (body.proteinLevel !== undefined) updateData.proteinLevel = body.proteinLevel;
    if (body.waterTargetMl !== undefined) updateData.waterTargetMl = body.waterTargetMl;
    if (body.weightGoalKg !== undefined) updateData.weightGoalKg = body.weightGoalKg;
    if (body.bodyFatGoalPercent !== undefined) updateData.bodyFatGoalPercent = body.bodyFatGoalPercent;
    if (body.preferredMeals !== undefined) updateData.preferredMeals = body.preferredMeals;
    if (body.dietType !== undefined) updateData.dietType = body.dietType;
    if (body.mealPrepTime !== undefined) updateData.mealPrepTime = body.mealPrepTime;
    if (body.cookingBy !== undefined) updateData.cookingBy = body.cookingBy as 'myself' | 'maid';
    if (body.preferredFoods !== undefined) updateData.preferredFoods = body.preferredFoods;
    if (body.profileCompleted !== undefined) updateData.profileCompleted = body.profileCompleted;
    if (body.preferSupersets !== undefined) updateData.preferSupersets = body.preferSupersets;
    if (body.experienceLevel !== undefined) updateData.experienceLevel = body.experienceLevel;
    if (body.whyNow !== undefined) updateData.whyNow = body.whyNow;
    if (body.goalPace !== undefined) updateData.goalPace = body.goalPace;
    if (body.primaryBlocker !== undefined) updateData.primaryBlocker = body.primaryBlocker;
    if (body.currentBodyShape !== undefined) updateData.currentBodyShape = body.currentBodyShape;
    if (body.goalBodyShape !== undefined) updateData.goalBodyShape = body.goalBodyShape;

    let result: (typeof userProfile.$inferSelect)[];
    if (profiles.length === 0) {
        result = await db.insert(userProfile).values(updateData as typeof userProfile.$inferInsert).returning();
    } else {
        result = await db.update(userProfile)
            .set(updateData)
            .where(eq(userProfile.userId, userId))
            .returning();
    }

    return ok(c, result[0]);
});

export default router;

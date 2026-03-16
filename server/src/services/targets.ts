import { eq } from 'drizzle-orm';
import { db } from '../db';
import { userProfile, userTargets } from '../db/schema';
import { ensureUserTargetsRow, syncProfileFromTargets, syncTargetsFromProfile } from '../lib/userTargets';

export type DailyTargetsInput = {
    dailySteps?: number;
    dailySleepTarget?: number;
    dailyWaterMl?: number;
    targetWeight?: number | null;
    dailyCalorieBurn?: number;
};

export type BodyGoalsInput = {
    weightGoalKg?: number | null;
    bodyFatGoalPercent?: number | null;
};

export async function updateDailyTargets(userId: number, input: DailyTargetsInput) {
    await ensureUserTargetsRow(userId);
    const [updated] = await db.update(userTargets).set({
        ...(input.dailySteps !== undefined ? { dailySteps: input.dailySteps } : {}),
        ...(input.dailySleepTarget !== undefined ? { dailySleepTarget: input.dailySleepTarget } : {}),
        ...(input.dailyWaterMl !== undefined ? { dailyWaterMl: input.dailyWaterMl } : {}),
        ...(input.targetWeight !== undefined ? { targetWeight: input.targetWeight } : {}),
        ...(input.dailyCalorieBurn !== undefined ? { dailyCalorieBurn: input.dailyCalorieBurn } : {}),
        updatedAt: new Date().toISOString(),
    }).where(eq(userTargets.userId, userId)).returning();

    await syncProfileFromTargets(userId, {
        dailyWaterMl: input.dailyWaterMl,
        targetWeight: input.targetWeight,
    });

    return updated;
}

export async function updateBodyGoals(userId: number, input: BodyGoalsInput) {
    const [updated] = await db.update(userProfile).set({
        ...(input.weightGoalKg !== undefined ? { weightGoalKg: input.weightGoalKg } : {}),
        ...(input.bodyFatGoalPercent !== undefined ? { bodyFatGoalPercent: input.bodyFatGoalPercent } : {}),
        updatedAt: new Date().toISOString(),
    }).where(eq(userProfile.userId, userId)).returning();

    await syncTargetsFromProfile(userId, {
        targetWeight: input.weightGoalKg,
    });

    return updated;
}

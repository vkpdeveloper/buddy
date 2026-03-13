import { eq } from 'drizzle-orm';
import { db } from '../db';
import { userProfile, userTargets } from '../db/schema';

export const DEFAULT_DAILY_STEPS = 10000;
export const DEFAULT_DAILY_SLEEP_TARGET = 7;
export const DEFAULT_DAILY_WATER_ML = 2500;
export const DEFAULT_DAILY_CALORIE_BURN = 500;

type ProfileSyncFields = {
  dailyWaterMl?: number;
  targetWeight?: number | null;
};

type TargetSyncFields = {
  dailyWaterMl?: number;
  targetWeight?: number | null;
};

export async function ensureUserTargetsRow(userId: number) {
  let rows = await db.select().from(userTargets).where(eq(userTargets.userId, userId)).limit(1);
  if (rows.length > 0) return rows[0];

  const [profile] = await db
    .select({
      waterTargetMl: userProfile.waterTargetMl,
      weightGoalKg: userProfile.weightGoalKg,
    })
    .from(userProfile)
    .where(eq(userProfile.userId, userId))
    .limit(1);

  const inserted = await db
    .insert(userTargets)
    .values({
      userId,
      dailySteps: DEFAULT_DAILY_STEPS,
      dailySleepTarget: DEFAULT_DAILY_SLEEP_TARGET,
      dailyWaterMl: profile?.waterTargetMl ?? DEFAULT_DAILY_WATER_ML,
      targetWeight: profile?.weightGoalKg ?? null,
      dailyCalorieBurn: DEFAULT_DAILY_CALORIE_BURN,
      updatedAt: new Date().toISOString(),
    })
    .returning();

  return inserted[0];
}

export async function syncProfileFromTargets(
  userId: number,
  fields: ProfileSyncFields,
) {
  const updateData: Partial<typeof userProfile.$inferInsert> = {};
  if (fields.dailyWaterMl !== undefined) {
    updateData.waterTargetMl = fields.dailyWaterMl;
  }
  if (fields.targetWeight !== undefined) {
    updateData.weightGoalKg = fields.targetWeight;
  }

  if (Object.keys(updateData).length == 0) return;

  const existing = await db
    .select({ id: userProfile.id })
    .from(userProfile)
    .where(eq(userProfile.userId, userId))
    .limit(1);

  if (existing.length == 0) {
    await db.insert(userProfile).values({
      userId,
      ...updateData,
      updatedAt: new Date().toISOString(),
    });
    return;
  }

  await db
    .update(userProfile)
    .set({
      ...updateData,
      updatedAt: new Date().toISOString(),
    })
    .where(eq(userProfile.userId, userId));
}

export async function syncTargetsFromProfile(
  userId: number,
  fields: TargetSyncFields,
) {
  const updateData: Partial<typeof userTargets.$inferInsert> = {};
  if (fields.dailyWaterMl !== undefined) {
    updateData.dailyWaterMl = fields.dailyWaterMl;
  }
  if (fields.targetWeight !== undefined) {
    updateData.targetWeight = fields.targetWeight;
  }

  if (Object.keys(updateData).length == 0) return;

  await ensureUserTargetsRow(userId);
  await db
    .update(userTargets)
    .set({
      ...updateData,
      updatedAt: new Date().toISOString(),
    })
    .where(eq(userTargets.userId, userId));
}

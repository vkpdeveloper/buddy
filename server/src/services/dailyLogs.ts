import { and, eq } from 'drizzle-orm';
import { db } from '../db';
import { dailyLogs } from '../db/schema';

export type DailyLogInput = {
    waterMl?: number;
    sleepMinutes?: number;
    stepsCount?: number;
    caloriesBurned?: number;
};

export async function getDailyLog(userId: number, date: string) {
    const [existing] = await db.select().from(dailyLogs)
        .where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
    return existing ?? null;
}

export async function upsertDailyLog(userId: number, date: string, input: DailyLogInput) {
    const existing = await getDailyLog(userId, date);
    if (existing) {
        const [updated] = await db.update(dailyLogs).set({
            ...(input.waterMl !== undefined ? { waterMl: input.waterMl } : {}),
            ...(input.sleepMinutes !== undefined ? { sleepMinutes: input.sleepMinutes } : {}),
            ...(input.stepsCount !== undefined ? { stepsCount: input.stepsCount } : {}),
            ...(input.caloriesBurned !== undefined ? { caloriesBurned: input.caloriesBurned } : {}),
            updatedAt: new Date().toISOString(),
        }).where(eq(dailyLogs.id, existing.id)).returning();
        return updated;
    }

    const [inserted] = await db.insert(dailyLogs).values({
        userId,
        date,
        waterMl: input.waterMl ?? 0,
        sleepMinutes: input.sleepMinutes ?? 0,
        stepsCount: input.stepsCount ?? 0,
        caloriesBurned: input.caloriesBurned ?? 0,
    }).returning();
    return inserted;
}

export async function incrementHydration(userId: number, date: string, amountMl: number) {
    const existing = await getDailyLog(userId, date);
    if (existing) {
        const [updated] = await db.update(dailyLogs).set({
            waterMl: existing.waterMl + amountMl,
            updatedAt: new Date().toISOString(),
        }).where(eq(dailyLogs.id, existing.id)).returning();
        return updated;
    }

    const [inserted] = await db.insert(dailyLogs).values({
        userId,
        date,
        waterMl: amountMl,
        sleepMinutes: 0,
        stepsCount: 0,
        caloriesBurned: 0,
    }).returning();
    return inserted;
}

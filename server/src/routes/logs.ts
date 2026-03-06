import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { and, asc, desc, eq, sql } from 'drizzle-orm';
import { db } from '../db';
import {
    dailyLogs,
    dietDays,
    dietMealLogs,
    dietMeals,
    dietPlans,
    workoutDays,
    workoutExercises,
    workoutPlans,
    workoutSessions,
} from '../db/schema';

const router = new Hono();
const mealTypeOrder: Record<string, number> = {
    breakfast: 1,
    morning_snack: 2,
    lunch: 3,
    pre_workout: 4,
    post_workout: 5,
    dinner: 6,
    evening_snack: 7,
};

const mealTypeLabel: Record<string, string> = {
    breakfast: 'Breakfast',
    morning_snack: 'Morning Snack',
    lunch: 'Lunch',
    pre_workout: 'Pre-Workout',
    post_workout: 'Post-Workout',
    dinner: 'Dinner',
    evening_snack: 'Evening Snack',
};

// ─── GET /api/logs/week ──────────────────────────────────────────────────────
router.get('/week', async (c) => {
    try {
        const userId = c.var.userId;
        const rows = await db.select().from(dailyLogs)
            .where(eq(dailyLogs.userId, userId))
            .orderBy(desc(dailyLogs.date))
            .limit(7);
        return c.json({ success: true, data: rows });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/logs/home-summary/:date ───────────────────────────────────────
router.get('/home-summary/:date', async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date');
        const weekday = new Date(`${date}T00:00:00`).getDay(); // 0=Sun...6=Sat
        const dayNumber = weekday === 0 ? 7 : weekday;

        const [logRow] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
        const hydrationMl = logRow?.waterMl ?? 0;
        const sleepMinutes = logRow?.sleepMinutes ?? 0;
        const activeEnergy = logRow?.caloriesBurned ?? 0;
        const steps = logRow?.stepsCount ?? 0;

        // Next meal from active diet plan, for the selected date.
        const [activeDietPlan] = await db.select().from(dietPlans).where(and(eq(dietPlans.userId, userId), eq(dietPlans.isActive, true))).limit(1);
        let nextMeal: null | { id: number; type: string; label: string; mealName: string; isCompleted: boolean } = null;
        if (activeDietPlan) {
            const [dietDay] = await db.select().from(dietDays)
                .where(and(eq(dietDays.planId, activeDietPlan.id), eq(dietDays.dayNumber, dayNumber)))
                .limit(1);

            if (dietDay) {
                const meals = await db.select().from(dietMeals)
                    .where(eq(dietMeals.dayId, dietDay.id))
                    .orderBy(asc(dietMeals.orderIndex));

                const logs = await db.select().from(dietMealLogs).where(eq(dietMealLogs.date, date));
                const logMap = new Map(logs.map((l) => [l.mealId, l.isCompleted]));
                const pending = meals.find((m) => !(logMap.get(m.id) ?? false));
                const fallback = meals[0];
                const chosen = pending ?? fallback;
                if (chosen) {
                    nextMeal = {
                        id: chosen.id,
                        type: chosen.mealType,
                        label: mealTypeLabel[chosen.mealType] ?? chosen.mealType,
                        mealName: chosen.mealName,
                        isCompleted: logMap.get(chosen.id) ?? false,
                    };
                }
            }
        }

        // Today's workout summary from active workout plan.
        const [activeWorkoutPlan] = await db.select().from(workoutPlans).where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true))).limit(1);
        let todayWorkoutSummary: null | {
            dayId: number;
            dayLabel: string;
            isRestDay: boolean;
            exerciseCount: number;
            isCompletedToday: boolean;
            hasInProgressSession: boolean;
        } = null;

        if (activeWorkoutPlan) {
            const [workoutDay] = await db.select().from(workoutDays)
                .where(and(eq(workoutDays.planId, activeWorkoutPlan.id), eq(workoutDays.dayNumber, dayNumber)))
                .limit(1);

            if (workoutDay) {
                const sessionsToday = await db.select().from(workoutSessions).where(and(
                    eq(workoutSessions.userId, userId),
                    eq(workoutSessions.planId, activeWorkoutPlan.id),
                    eq(workoutSessions.dayId, workoutDay.id),
                    sql`date(${workoutSessions.startedAt}) = ${date}`,
                ));

                const completedSession = sessionsToday.find((s) => !!s.completedAt);
                const inProgressSession = sessionsToday.find((s) => !s.completedAt);
                const exercisesCount = workoutDay.isRestDay
                    ? 0
                    : (await db.select().from(workoutExercises).where(eq(workoutExercises.dayId, workoutDay.id))).length;

                todayWorkoutSummary = {
                    dayId: workoutDay.id,
                    dayLabel: workoutDay.dayLabel,
                    isRestDay: workoutDay.isRestDay,
                    exerciseCount: exercisesCount,
                    isCompletedToday: !!completedSession,
                    hasInProgressSession: !!inProgressSession,
                };
            }
        }

        return c.json({
            success: true,
            data: {
                date,
                sleepMinutes,
                activeEnergy,
                restingHr: null,
                steps,
                hydrationMl,
                nextMeal,
                todayWorkoutSummary,
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/logs/:date ─────────────────────────────────────────────────────
router.get('/:date', async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date');
        const [row] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
        if (!row) {
            // Return zeroed log if none exists yet
            return c.json({
                success: true,
                data: { date, waterMl: 0, sleepMinutes: 0, stepsCount: 0, caloriesBurned: 0 },
            });
        }
        return c.json({ success: true, data: row });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

const logSchema = z.object({
    waterMl: z.number().int().min(0).optional(),
    sleepMinutes: z.number().int().min(0).optional(),
    stepsCount: z.number().int().min(0).optional(),
    caloriesBurned: z.number().int().min(0).optional(),
});

const hydrationIncrementSchema = z.object({
    amountMl: z.number().int().positive().max(2000).optional(),
});

// ─── POST /api/logs/:date/hydration/increment ───────────────────────────────
router.post('/:date/hydration/increment', zValidator('json', hydrationIncrementSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date');
        const amountMl = c.req.valid('json').amountMl ?? 250;

        const [existing] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
        if (existing) {
            const [updated] = await db.update(dailyLogs).set({
                waterMl: existing.waterMl + amountMl,
                updatedAt: new Date().toISOString(),
            }).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date))).returning();
            return c.json({ success: true, data: updated });
        }

        const [inserted] = await db.insert(dailyLogs).values({
            userId,
            date,
            waterMl: amountMl,
            sleepMinutes: 0,
            stepsCount: 0,
            caloriesBurned: 0,
        }).returning();
        return c.json({ success: true, data: inserted });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/logs/:date ─────────────────────────────────────────────────────
router.put('/:date', zValidator('json', logSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const date = c.req.param('date');
        const body = c.req.valid('json');

        const [existing] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));

        let result: (typeof dailyLogs.$inferSelect)[];
        if (existing) {
            const updateData: Partial<typeof dailyLogs.$inferInsert> = {
                updatedAt: new Date().toISOString(),
            };
            if (body.waterMl !== undefined) updateData.waterMl = body.waterMl;
            if (body.sleepMinutes !== undefined) updateData.sleepMinutes = body.sleepMinutes;
            if (body.stepsCount !== undefined) updateData.stepsCount = body.stepsCount;
            if (body.caloriesBurned !== undefined) updateData.caloriesBurned = body.caloriesBurned;
            result = await db.update(dailyLogs).set(updateData).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date))).returning();
        } else {
            result = await db.insert(dailyLogs).values({
                userId,
                date,
                waterMl: body.waterMl ?? 0,
                sleepMinutes: body.sleepMinutes ?? 0,
                stepsCount: body.stepsCount ?? 0,
                caloriesBurned: body.caloriesBurned ?? 0,
            }).returning();
        }

        return c.json({ success: true, data: result[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

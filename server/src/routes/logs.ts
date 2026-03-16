import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { and, asc, count, desc, eq, inArray, sql } from 'drizzle-orm';
import { db } from '../db';
import { ok } from '../lib/response';
import { getDayNumberFromDate } from '../lib/time';
import {
    dailyLogs,
    dietMealLogs,
    workoutExercises,
    workoutSessions,
    workoutDays,
    workoutPlans,
} from '../db/schema';
import { getDailyLog, incrementHydration, upsertDailyLog } from '../services/dailyLogs';
import { getEffectiveDietDayForDate } from '../services/diet';

const router = new Hono();

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
    const userId = c.var.userId;
    const rows = await db.select().from(dailyLogs)
        .where(eq(dailyLogs.userId, userId))
        .orderBy(desc(dailyLogs.date))
        .limit(7);
    return ok(c, rows);
});

// ─── GET /api/logs/home-summary/:date ───────────────────────────────────────
router.get('/home-summary/:date', async (c) => {
    const userId = c.var.userId;
    const date = c.req.param('date');
    const dayNumber = getDayNumberFromDate(date);
    const [logRow] = await db.select().from(dailyLogs).where(and(eq(dailyLogs.userId, userId), eq(dailyLogs.date, date)));
    const hydrationMl = logRow?.waterMl ?? 0;
    const sleepMinutes = logRow?.sleepMinutes ?? 0;
    const activeEnergy = logRow?.caloriesBurned ?? 0;
    const steps = logRow?.stepsCount ?? 0;

    // Next meal from active diet plan, for the selected date.
    let nextMeal: null | { id: number; type: string; label: string; mealName: string; isCompleted: boolean } = null;
    const effectiveDietDay = await getEffectiveDietDayForDate(userId, date);
    if (effectiveDietDay) {
        const mealIds = effectiveDietDay.meals.map((meal) => meal.sourceMealId as number);
        const logs = mealIds.length > 0
            ? await db
                .select({ mealId: dietMealLogs.mealId, isCompleted: dietMealLogs.isCompleted })
                .from(dietMealLogs)
                .where(and(eq(dietMealLogs.date, date), inArray(dietMealLogs.mealId, mealIds)))
            : [];
        const logMap = new Map(logs.map((log) => [log.mealId, log.isCompleted]));
        const pending = effectiveDietDay.meals.find((meal) => !(logMap.get(meal.sourceMealId) ?? false));
        const fallback = effectiveDietDay.meals[0];
        const chosen = pending ?? fallback;
        if (chosen) {
            nextMeal = {
                id: chosen.sourceMealId,
                type: chosen.mealType,
                label: mealTypeLabel[chosen.mealType] ?? chosen.mealType,
                mealName: chosen.mealName,
                isCompleted: logMap.get(chosen.sourceMealId) ?? false,
            };
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
                : (await db.select({ value: count() }).from(workoutExercises).where(eq(workoutExercises.dayId, workoutDay.id)))[0].value;

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

    return ok(c, {
        date,
        sleepMinutes,
        activeEnergy,
        restingHr: null,
        steps,
        hydrationMl,
        nextMeal,
        todayWorkoutSummary,
    });
});

// ─── GET /api/logs/:date ─────────────────────────────────────────────────────
router.get('/:date', async (c) => {
    const userId = c.var.userId;
    const date = c.req.param('date');
    const row = await getDailyLog(userId, date);
    if (!row) {
        // Return zeroed log if none exists yet
        return ok(c, { date, waterMl: 0, sleepMinutes: 0, stepsCount: 0, caloriesBurned: 0 });
    }
    return ok(c, row);
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
    const userId = c.var.userId;
    const date = c.req.param('date');
    const amountMl = c.req.valid('json').amountMl ?? 250;
    const updated = await incrementHydration(userId, date, amountMl);
    return ok(c, updated);
});

// ─── PUT /api/logs/:date ─────────────────────────────────────────────────────
router.put('/:date', zValidator('json', logSchema), async (c) => {
    const userId = c.var.userId;
    const date = c.req.param('date');
    const body = c.req.valid('json');
    const result = await upsertDailyLog(userId, date, body);
    return ok(c, result);
});

export default router;

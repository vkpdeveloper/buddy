import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { eq, and, asc, inArray } from 'drizzle-orm';
import { db } from '../db';
import { dietPlans, dietDays, dietMeals, dietMealLogs, dietMealOverrides, dailyLogs, dietQuickLogs, mealMediaAttachments } from '../db/schema';
import { DIET_FOOD_OPTIONS } from '../lib/dietGenerator';
import { ok, fail } from '../lib/response';
import { notFound } from '../lib/errors';
import { getEffectiveDietDayForDate, parseIngredientsJson, upsertActualMealLog, upsertQuickMealLog } from '../services/diet';

const router = new Hono();

// ─── GET /api/diet/foods ─────────────────────────────────────────────────────
router.get('/foods', (c) => {
    return ok(c, DIET_FOOD_OPTIONS);
});

// ─── GET /api/diet/plans ─────────────────────────────────────────────────────
router.get('/plans', async (c) => {
    const userId = c.var.userId;
    const plans = await db.select().from(dietPlans).where(eq(dietPlans.userId, userId)).orderBy(dietPlans.createdAt);
    return ok(c, plans);
});

// ─── GET /api/diet/plans/:id ─────────────────────────────────────────────────
router.get('/plans/:id', async (c) => {
    const userId = c.var.userId;
    const id = parseInt(c.req.param('id'));
    const effectiveDate = c.req.query('date');
    const [plan] = await db.select().from(dietPlans).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id)));
    if (!plan) throw notFound('Plan not found');

    const days = await db.select().from(dietDays)
        .where(eq(dietDays.planId, id))
        .orderBy(dietDays.dayNumber);

    const dayIds = days.map((d) => d.id);
    const allMeals = dayIds.length > 0
        ? await db.select().from(dietMeals)
            .where(inArray(dietMeals.dayId, dayIds))
            .orderBy(asc(dietMeals.orderIndex))
        : [];

    const mealsByDayId = new Map<number, (typeof dietMeals.$inferSelect)[]>();
    for (const meal of allMeals) {
        const arr = mealsByDayId.get(meal.dayId) ?? [];
        arr.push(meal);
        mealsByDayId.set(meal.dayId, arr);
    }
    const effective = effectiveDate ? await getEffectiveDietDayForDate(userId, effectiveDate) : null;
    const effectiveDayNumber = effectiveDate ? new Date(`${effectiveDate}T12:00:00.000Z`).getUTCDay() || 7 : null;
    const daysWithMeals = days.map((day) => {
        const baseMeals = (mealsByDayId.get(day.id) ?? []).map((meal) => ({
            ...meal,
            ingredients: parseIngredientsJson(meal.ingredients),
        }));
        if (effective && effectiveDayNumber != null && day.dayNumber === effectiveDayNumber) {
            return {
                ...day,
                totalCalories: effective.day.totalCalories,
                proteinG: effective.day.proteinG,
                carbsG: effective.day.carbsG,
                fatG: effective.day.fatG,
                meals: effective.meals,
                hasOverrides: effective.hasOverrides,
            };
        }
        return {
            ...day,
            meals: baseMeals,
        };
    });

    return ok(c, { ...plan, days: daysWithMeals });
});

// ─── PUT /api/diet/plans/:id ─────────────────────────────────────────────────
router.put('/plans/:id', zValidator('json', z.object({
    title: z.string().optional(),
    isActive: z.boolean().optional(),
})), async (c) => {
    const userId = c.var.userId;
    const id = parseInt(c.req.param('id'));
    const body = c.req.valid('json');
    const updated = await db.update(dietPlans).set(body).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id))).returning();
    return ok(c, updated[0]);
});

// ─── DELETE /api/diet/plans/:id ──────────────────────────────────────────────
router.delete('/plans/:id', async (c) => {
    const userId = c.var.userId;
    const id = parseInt(c.req.param('id'));
    await db.delete(dietPlans).where(and(eq(dietPlans.userId, userId), eq(dietPlans.id, id)));
    return ok(c, null);
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
    const id = parseInt(c.req.param('id'));
    const { ingredients, ...rest } = c.req.valid('json');
    const body: Record<string, any> = { ...rest };
    if (ingredients !== undefined) body.ingredients = JSON.stringify(ingredients);
    const updated = await db.update(dietMeals).set(body).where(eq(dietMeals.id, id)).returning();
    if (updated.length === 0) throw notFound('Meal not found');
    return ok(c, updated[0]);
});

// ─── PUT /api/diet/days/:id/reorder ─────────────────────────────────────────
router.put('/days/:id/reorder', zValidator('json', z.object({
    mealIds: z.array(z.number().int().positive()).min(1),
})), async (c) => {
    const dayId = parseInt(c.req.param('id'));
    const { mealIds } = c.req.valid('json');
    const dayMeals = await db.select().from(dietMeals).where(eq(dietMeals.dayId, dayId));
    const dayMealIds = new Set(dayMeals.map((m) => m.id));

    for (const id of mealIds) {
        if (!dayMealIds.has(id)) {
            return fail(c, `Meal ${id} is not in this day`, 400);
        }
    }

    await db.transaction(async (tx) => {
        for (let i = 0; i < mealIds.length; i += 1) {
            await tx.update(dietMeals)
                .set({ orderIndex: i + 1 })
                .where(eq(dietMeals.id, mealIds[i]));
        }
    });

    const reordered = await db.select().from(dietMeals)
        .where(eq(dietMeals.dayId, dayId))
        .orderBy(asc(dietMeals.orderIndex));
    return ok(c, reordered);
});

// ─── PUT /api/diet/days/:id ──────────────────────────────────────────────────
router.put('/days/:id', zValidator('json', z.object({
    isCompleted: z.boolean().optional(),
})), async (c) => {
    const id = parseInt(c.req.param('id'));
    const body = c.req.valid('json');
    const updated = await db.update(dietDays).set(body).where(eq(dietDays.id, id)).returning();
    if (updated.length === 0) throw notFound('Day not found');
    return ok(c, updated[0]);
});

// ─── GET /api/diet/log/:date ─────────────────────────────────────────────────
// Returns daily meal completion + actual intake + hydration snapshot
router.get('/log/:date', async (c) => {
    const userId = c.var.userId;
    const date = c.req.param('date'); // YYYY-MM-DD

    const effectiveDay = await getEffectiveDietDayForDate(userId, date);
    let logs: (typeof dietMealLogs.$inferSelect)[] = [];
    if (effectiveDay) {
        const mealIds = effectiveDay.meals.map((meal) => meal.sourceMealId as number);
        if (mealIds.length > 0) {
            logs = await db.select().from(dietMealLogs)
                .where(and(eq(dietMealLogs.date, date), inArray(dietMealLogs.mealId, mealIds)));
        }
    }
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

    return ok(c, {
        completionMap,
        actualLogs,
        effectiveDay: effectiveDay
            ? {
                ...effectiveDay.day,
                meals: effectiveDay.meals,
                hasOverrides: effectiveDay.hasOverrides,
            }
            : null,
        quickLogs,
        consumedTotals: {
            calories: consumedCalories,
            proteinG: consumedProteinG,
            carbsG: consumedCarbsG,
            fatG: consumedFatG,
        },
        hydrationMl,
    });
});

// ─── PUT /api/diet/log/:date ─────────────────────────────────────────────────
// Upsert meal completion for a specific date
router.put('/log/:date', zValidator('json', z.object({
    mealId: z.number().int(),
    isCompleted: z.boolean(),
})), async (c) => {
    const userId = c.var.userId;
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
        await db.insert(dietMealLogs).values({ userId, mealId, date, isCompleted });
    }

    return ok(c, null);
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
    const userId = c.var.userId;
    const date = c.req.param('date');
    const body = c.req.valid('json');
    await upsertActualMealLog(userId, {
        date,
        mealId: body.mealId,
        mealName: body.mealName,
        calories: body.calories,
        proteinG: body.proteinG,
        carbsG: body.carbsG,
        fatG: body.fatG,
        notes: body.notes,
        rawPayload: body.rawPayload,
        attachmentId: body.attachmentId,
    });
    return ok(c, null);
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
    const userId = c.var.userId;
    const date = c.req.param('date');
    const { mealName, calories, proteinG, carbsG, fatG, notes, attachmentId } = c.req.valid('json');

    const inserted = await upsertQuickMealLog(userId, {
        date,
        mealName,
        calories,
        proteinG,
        carbsG,
        fatG,
        notes,
        attachmentId,
    });

    // Fetch signed URL for attachment if present
    let signedUrl: string | null = null;
    if (attachmentId) {
        const [att] = await db.select().from(mealMediaAttachments).where(eq(mealMediaAttachments.id, attachmentId)).limit(1);
        if (att) {
            const { signPrivateObjectUrl } = await import('../lib/r2');
            signedUrl = await signPrivateObjectUrl(att.objectKey);
        }
    }

    return ok(c, { ...inserted, signedUrl });
});

// ─── DELETE /api/diet/log/:date/:mealId ──────────────────────────────────────
// Unlogs a meal: deletes the meal log entry and any override for that meal+date
router.delete('/log/:date/:mealId', async (c) => {
    const userId = c.var.userId;
    const date = c.req.param('date');
    const mealId = parseInt(c.req.param('mealId'));

    await db.delete(dietMealLogs)
        .where(and(eq(dietMealLogs.userId, userId), eq(dietMealLogs.mealId, mealId), eq(dietMealLogs.date, date)));

    await db.delete(dietMealOverrides)
        .where(and(eq(dietMealOverrides.userId, userId), eq(dietMealOverrides.mealId, mealId), eq(dietMealOverrides.date, date)));

    return ok(c, null);
});

export default router;

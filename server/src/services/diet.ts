import { and, asc, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import {
    dietDays,
    dietMealLogs,
    dietMealOverrides,
    dietMeals,
    dietPlans,
    dietQuickLogs,
    mealMediaAttachments,
} from '../db/schema';
import { getDayNumberFromDate } from '../lib/time';

type IngredientItem = { name: string; quantity: string };

export type DietMealShape = {
    mealType: string;
    mealTime: string;
    mealName: string;
    description: string;
    ingredients: IngredientItem[];
    recipe: string;
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
    notes: string;
};

export function parseIngredientsJson(value: string | null | undefined) {
    if (!value) return [] as IngredientItem[];
    try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed as IngredientItem[] : [];
    } catch {
        return [];
    }
}

export async function getActiveDietPlan(userId: number) {
    const [activePlan] = await db.select().from(dietPlans)
        .where(and(eq(dietPlans.userId, userId), eq(dietPlans.isActive, true)))
        .limit(1);
    return activePlan ?? null;
}

export async function getDietDayForDate(planId: number, date: string) {
    const dayNumber = getDayNumberFromDate(date);
    const [dietDay] = await db.select().from(dietDays)
        .where(and(eq(dietDays.planId, planId), eq(dietDays.dayNumber, dayNumber)))
        .limit(1);
    return dietDay ?? null;
}

export async function getEffectiveDietDayForDate(userId: number, date: string) {
    const activePlan = await getActiveDietPlan(userId);
    if (!activePlan) return null;

    const dietDay = await getDietDayForDate(activePlan.id, date);
    if (!dietDay) return null;

    const baseMeals = await db.select().from(dietMeals)
        .where(eq(dietMeals.dayId, dietDay.id))
        .orderBy(asc(dietMeals.orderIndex));

    const mealIds = baseMeals.map((meal) => meal.id);
    const overrides = mealIds.length > 0
        ? await db.select().from(dietMealOverrides)
            .where(and(eq(dietMealOverrides.userId, userId), eq(dietMealOverrides.date, date), inArray(dietMealOverrides.mealId, mealIds)))
        : [];

    const overrideByMealId = new Map(overrides.map((override) => [override.mealId, override]));

    const meals = baseMeals.map((meal) => {
        const override = overrideByMealId.get(meal.id);
        if (!override) {
            return {
                ...meal,
                ingredients: parseIngredientsJson(meal.ingredients),
                isOverride: false,
                sourceMealId: meal.id,
            };
        }
        return {
            id: meal.id,
            dayId: meal.dayId,
            orderIndex: meal.orderIndex,
            mealType: override.mealType,
            mealTime: override.mealTime,
            mealName: override.mealName,
            description: override.description,
            ingredients: parseIngredientsJson(override.ingredients),
            recipe: override.recipe,
            calories: override.calories,
            proteinG: override.proteinG,
            carbsG: override.carbsG,
            fatG: override.fatG,
            isCompleted: meal.isCompleted,
            notes: override.notes,
            isOverride: true,
            sourceMealId: meal.id,
            overrideId: override.id,
        };
    });

    const hasOverrides = overrides.length > 0;
    const totals = hasOverrides
        ? meals.reduce((acc, meal) => ({
            totalCalories: acc.totalCalories + meal.calories,
            proteinG: acc.proteinG + meal.proteinG,
            carbsG: acc.carbsG + meal.carbsG,
            fatG: acc.fatG + meal.fatG,
        }), {
            totalCalories: 0,
            proteinG: 0,
            carbsG: 0,
            fatG: 0,
        })
        : {
            totalCalories: dietDay.totalCalories,
            proteinG: dietDay.proteinG,
            carbsG: dietDay.carbsG,
            fatG: dietDay.fatG,
        };

    return {
        plan: activePlan,
        day: {
            ...dietDay,
            ...totals,
        },
        meals,
        hasOverrides,
    };
}

export async function getMealSlotForDate(userId: number, date: string, mealType: string) {
    const resolved = await getEffectiveDietDayForDate(userId, date);
    if (!resolved) return null;
    const meal = resolved.meals.find((item) => item.mealType === mealType);
    if (!meal) return null;
    return {
        plan: resolved.plan,
        day: resolved.day,
        meal,
    };
}

export async function upsertDietMealOverride(userId: number, params: {
    mealId: number;
    date: string;
    meal: DietMealShape;
}) {
    const ingredients = JSON.stringify(params.meal.ingredients);
    const [existing] = await db.select().from(dietMealOverrides)
        .where(and(
            eq(dietMealOverrides.userId, userId),
            eq(dietMealOverrides.mealId, params.mealId),
            eq(dietMealOverrides.date, params.date),
        ))
        .limit(1);

    if (existing) {
        const [updated] = await db.update(dietMealOverrides).set({
            mealType: params.meal.mealType as typeof dietMealOverrides.$inferInsert.mealType,
            mealTime: params.meal.mealTime,
            mealName: params.meal.mealName,
            description: params.meal.description,
            ingredients,
            recipe: params.meal.recipe,
            calories: params.meal.calories,
            proteinG: params.meal.proteinG,
            carbsG: params.meal.carbsG,
            fatG: params.meal.fatG,
            notes: params.meal.notes,
            updatedAt: new Date().toISOString(),
        }).where(eq(dietMealOverrides.id, existing.id)).returning();
        return updated;
    }

    const [inserted] = await db.insert(dietMealOverrides).values({
        userId,
        mealId: params.mealId,
        date: params.date,
        mealType: params.meal.mealType as typeof dietMealOverrides.$inferInsert.mealType,
        mealTime: params.meal.mealTime,
        mealName: params.meal.mealName,
        description: params.meal.description,
        ingredients,
        recipe: params.meal.recipe,
        calories: params.meal.calories,
        proteinG: params.meal.proteinG,
        carbsG: params.meal.carbsG,
        fatG: params.meal.fatG,
        notes: params.meal.notes,
    }).returning();
    return inserted;
}

export async function upsertActualMealLog(userId: number, params: {
    date: string;
    mealId: number;
    mealName: string;
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
    notes?: string;
    rawPayload?: Record<string, unknown>;
    attachmentId?: number;
}) {
    const [existing] = await db.select().from(dietMealLogs)
        .where(and(eq(dietMealLogs.mealId, params.mealId), eq(dietMealLogs.date, params.date)));

    const rawPayload = {
        ...(params.rawPayload ?? {}),
        ...(params.attachmentId != null ? {
            attachmentId: params.attachmentId,
            source: (params.rawPayload?.source as string | undefined) ?? 'ai_photo_analysis',
        } : {}),
    };

    const values = {
        isCompleted: true,
        actualMealName: params.mealName,
        actualCalories: params.calories,
        actualProteinG: params.proteinG,
        actualCarbsG: params.carbsG,
        actualFatG: params.fatG,
        actualNotes: params.notes ?? '',
        rawPayload: JSON.stringify(rawPayload),
        loggedAt: new Date().toISOString(),
    };

    if (existing) {
        const [updated] = await db.update(dietMealLogs).set(values).where(eq(dietMealLogs.id, existing.id)).returning();
        return updated;
    }

    const [inserted] = await db.insert(dietMealLogs).values({
        userId,
        mealId: params.mealId,
        date: params.date,
        ...values,
    }).returning();
    return inserted;
}

export async function createQuickMealLog(userId: number, params: {
    date: string;
    mealName: string;
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
    notes?: string;
    attachmentId?: number;
}) {
    const [inserted] = await db.insert(dietQuickLogs).values({
        userId,
        date: params.date,
        mealName: params.mealName,
        calories: params.calories,
        proteinG: params.proteinG,
        carbsG: params.carbsG,
        fatG: params.fatG,
        notes: params.notes ?? '',
        attachmentId: params.attachmentId ?? null,
        loggedAt: new Date().toISOString(),
    }).returning();
    return inserted;
}

export async function getMealAttachment(userId: number, attachmentId: number) {
    const [attachment] = await db.select().from(mealMediaAttachments)
        .where(and(eq(mealMediaAttachments.userId, userId), eq(mealMediaAttachments.id, attachmentId)))
        .limit(1);
    return attachment ?? null;
}

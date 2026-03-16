import { z } from 'zod';
import { and, eq, inArray } from 'drizzle-orm';
import { db } from '../../../db';
import { dietMealLogs } from '../../../db/schema';
import { Tool } from 'ai';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { getEffectiveDietDayForDate } from '../../../services/diet';

export function getTodayDietTool(userId: number, timeZone: string): Tool {
    return {
        description:
            "Get today's planned diet — all meals scheduled for today with their meal type, name, macro breakdown (calories, protein, carbs, fat), ingredients, and whether each meal has been completed/logged. Call this when the user asks about today's meals, what to eat today, today's calories, or meal completion status.",
        inputSchema: z.object({}),
        execute: async () => {
            const todayDate = getLocalDateInTimeZone(timeZone);
            const resolved = await getEffectiveDietDayForDate(userId, todayDate);
            if (!resolved) {
                throw new Error('No active diet plan found. User needs to generate one first.');
            }

            const meals = resolved.meals;
            const mealIds = meals.map(m => m.id);
            const logs = mealIds.length > 0
                ? await db
                    .select()
                    .from(dietMealLogs)
                    .where(and(
                        inArray(dietMealLogs.mealId, mealIds),
                        eq(dietMealLogs.date, todayDate),
                    ))
                : [];

            const logMap = new Map(logs.map(l => [l.mealId, l]));

            return {
                planTitle: resolved.plan.title,
                date: todayDate,
                dayName: resolved.day.dayName,
                targets: {
                    calories: resolved.day.totalCalories,
                    proteinG: Math.round(resolved.day.proteinG),
                    carbsG: Math.round(resolved.day.carbsG),
                    fatG: Math.round(resolved.day.fatG),
                },
                meals: meals.map(m => {
                    const log = logMap.get(m.id);
                    const base = {
                        mealType: m.mealType,
                        mealName: m.mealName,
                        calories: m.calories,
                        proteinG: Math.round(m.proteinG),
                        carbsG: Math.round(m.carbsG),
                        fatG: Math.round(m.fatG),
                        ingredients: m.ingredients,
                        notes: m.notes,
                        isCompleted: log?.isCompleted ?? false,
                        isOverride: m.isOverride,
                    };
                    if (log?.actualCalories) {
                        return {
                            ...base,
                            actual: {
                                mealName: log.actualMealName || m.mealName,
                                calories: log.actualCalories,
                                proteinG: log.actualProteinG,
                                carbsG: log.actualCarbsG,
                                fatG: log.actualFatG,
                            },
                        };
                    }
                    return base;
                }),
            };
        },
    };
}

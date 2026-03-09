import { z } from 'zod';
import { and, eq, inArray } from 'drizzle-orm';
import { db } from '../../../db';
import { dietPlans, dietDays, dietMeals, dietMealLogs } from '../../../db/schema';
import { Tool } from 'ai';

/** Maps JS getDay() → dietDays.dayNumber (1=Mon … 7=Sun) */
function todayDayNumber(): number {
    const jsDay = new Date().getDay(); // 0=Sun…6=Sat
    return jsDay === 0 ? 7 : jsDay;
}

export function getTodayDietTool(userId: number): Tool {
    return {
        description:
            "Get today's planned diet — all meals scheduled for today with their meal type, name, macro breakdown (calories, protein, carbs, fat), ingredients, and whether each meal has been completed/logged. Call this when the user asks about today's meals, what to eat today, today's calories, or meal completion status.",
        inputSchema: z.object({}),
        execute: async () => {
            const [activePlan] = await db
                .select()
                .from(dietPlans)
                .where(and(eq(dietPlans.userId, userId), eq(dietPlans.isActive, true)))
                .limit(1);

            if (!activePlan) throw new Error('No active diet plan found. User needs to generate one first.');

            const dayNumber = todayDayNumber();
            const [todayDay] = await db
                .select()
                .from(dietDays)
                .where(and(eq(dietDays.planId, activePlan.id), eq(dietDays.dayNumber, dayNumber)))
                .limit(1);

            if (!todayDay) throw new Error(`No diet day found for today (dayNumber=${dayNumber})`);

            const meals = await db
                .select()
                .from(dietMeals)
                .where(eq(dietMeals.dayId, todayDay.id));

            const todayDate = new Date().toISOString().slice(0, 10);
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
                planTitle: activePlan.title,
                date: todayDate,
                dayName: todayDay.dayName,
                targets: {
                    calories: todayDay.totalCalories,
                    proteinG: Math.round(todayDay.proteinG),
                    carbsG: Math.round(todayDay.carbsG),
                    fatG: Math.round(todayDay.fatG),
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
                        ingredients: (() => { try { return JSON.parse(m.ingredients); } catch { return []; } })(),
                        notes: m.notes,
                        isCompleted: log?.isCompleted ?? false,
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

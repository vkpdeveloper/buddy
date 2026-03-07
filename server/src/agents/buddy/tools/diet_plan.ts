import { z } from 'zod';
import { and, eq } from 'drizzle-orm';
import { db } from '../../../db';
import { dietPlans, dietDays, dietMeals } from '../../../db/schema';
import { Tool } from 'ai';

export function getFullDietPlanTool(userId: string): Tool {
    return {
        description:
            "Get the user's full 7-day diet plan — every day (Mon–Sun) with each meal's name, type, and macros. Call this when the user asks about their weekly diet, a specific day of the week's meals, overall meal plan structure, or wants to compare days.",
        inputSchema: z.object({}),
        execute: async () => {
            const [activePlan] = await db
                .select()
                .from(dietPlans)
                .where(and(eq(dietPlans.userId, userId), eq(dietPlans.isActive, true)))
                .limit(1);

            if (!activePlan) throw new Error('No active diet plan found.');

            const days = await db
                .select()
                .from(dietDays)
                .where(eq(dietDays.planId, activePlan.id));

            const daysWithMeals = await Promise.all(
                days.sort((a, b) => a.dayNumber - b.dayNumber).map(async day => {
                    const meals = await db
                        .select({
                            mealType: dietMeals.mealType,
                            mealName: dietMeals.mealName,
                            calories: dietMeals.calories,
                            proteinG: dietMeals.proteinG,
                            carbsG: dietMeals.carbsG,
                            fatG: dietMeals.fatG,
                        })
                        .from(dietMeals)
                        .where(eq(dietMeals.dayId, day.id));

                    return {
                        dayNumber: day.dayNumber,
                        dayName: day.dayName,
                        totalCalories: day.totalCalories,
                        proteinG: Math.round(day.proteinG),
                        carbsG: Math.round(day.carbsG),
                        fatG: Math.round(day.fatG),
                        meals: meals.map(m => ({
                            mealType: m.mealType,
                            mealName: m.mealName,
                            calories: m.calories,
                            proteinG: Math.round(m.proteinG),
                            carbsG: Math.round(m.carbsG),
                            fatG: Math.round(m.fatG),
                        })),
                    };
                }),
            );

            return {
                planTitle: activePlan.title,
                dailyTargets: {
                    calories: activePlan.totalCalories,
                    proteinG: Math.round(activePlan.proteinG),
                    carbsG: Math.round(activePlan.carbsG),
                    fatG: Math.round(activePlan.fatG),
                },
                days: daysWithMeals,
            };
        },
    };
}

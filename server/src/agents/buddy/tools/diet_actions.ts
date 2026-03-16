import { Tool } from 'ai';
import { z } from 'zod';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { getMealSlotForDate, upsertDietMealOverride } from '../../../services/diet';
import { immediateWriteResult } from './tool_output';

const MealTypeSchema = z.enum([
    'breakfast',
    'morning_snack',
    'lunch',
    'pre_workout',
    'post_workout',
    'dinner',
    'evening_snack',
]);

const IngredientSchema = z.object({
    name: z.string().min(1),
    quantity: z.string().min(1),
});

function prettyMealType(mealType: string) {
    return mealType.replace(/_/g, ' ');
}

export function replaceDietMealTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Replace a planned meal for a specific date without editing the recurring base diet plan. This tool requires approval before it executes.',
        inputSchema: z.object({
            mealType: MealTypeSchema,
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            mealTime: z.string().min(1),
            mealName: z.string().min(1),
            description: z.string().optional(),
            ingredients: z.array(IngredientSchema).min(1),
            recipe: z.string().min(1),
            calories: z.number().int().positive(),
            proteinG: z.number().nonnegative(),
            carbsG: z.number().nonnegative(),
            fatG: z.number().nonnegative(),
            notes: z.string().optional(),
        }),
        needsApproval: true,
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const mealSlot = await getMealSlotForDate(userId, date, input.mealType);
            if (!mealSlot) {
                throw new Error(`No ${prettyMealType(input.mealType)} meal was found for ${date}.`);
            }

            await upsertDietMealOverride(userId, {
                mealId: mealSlot.meal.sourceMealId ?? mealSlot.meal.id,
                date,
                meal: {
                    mealType: input.mealType,
                    mealTime: input.mealTime,
                    mealName: input.mealName,
                    description: input.description ?? '',
                    ingredients: input.ingredients,
                    recipe: input.recipe,
                    calories: input.calories,
                    proteinG: input.proteinG,
                    carbsG: input.carbsG,
                    fatG: input.fatG,
                    notes: input.notes ?? '',
                },
            });

            return immediateWriteResult({
                message: `Replaced your ${prettyMealType(input.mealType)} for ${date}.`,
                refreshDomains: ['diet', 'home'],
            });
        },
    };
}

export function getDietMealSlotTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Get the current planned meal slot for a specific meal type on a local date, including any existing override already applied for that date.',
        inputSchema: z.object({
            mealType: MealTypeSchema,
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
        }),
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const slot = await getMealSlotForDate(userId, date, input.mealType);
            if (!slot) {
                throw new Error(`No ${prettyMealType(input.mealType)} meal was found for ${date}.`);
            }

            return {
                date,
                planTitle: slot.plan.title,
                dayName: slot.day.dayName,
                meal: slot.meal,
            };
        },
    };
}

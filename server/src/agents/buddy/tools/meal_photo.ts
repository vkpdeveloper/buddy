import { Tool } from 'ai';
import { z } from 'zod';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { createQuickMealLog, getMealSlotForDate, upsertActualMealLog } from '../../../services/diet';
import { ensureMealAnalysisReady } from '../../../services/mealMedia';
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

function prettyMealType(mealType: string) {
    return mealType.replace(/_/g, ' ');
}

export function getMealPhotoAttachmentTool(userId: number): Tool {
    return {
        description: 'Read a meal photo attachment by attachmentId. If analysis is not finished yet, wait for it to complete and then return the final meal analysis, signed image URL, and estimated macros.',
        inputSchema: z.object({
            attachmentId: z.number().int().positive(),
        }),
        execute: async ({ attachmentId }: { attachmentId: number }) => {
            const attachment = await ensureMealAnalysisReady(userId, attachmentId);

            return {
                attachmentId: attachment.id,
                status: attachment.aiAnalysisStatus,
                analysisResult: attachment.aiAnalysisResult,
                signedUrl: attachment.signedUrl,
                imageMarkdown: `![Meal photo](${attachment.signedUrl})`,
                createdAt: attachment.createdAt,
            };
        },
    };
}

export function logMealPhotoTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Log a meal photo either as a quick meal or against a planned meal slot. This tool requires approval before it executes.',
        inputSchema: z.object({
            attachmentId: z.number().int().positive(),
            mode: z.enum(['quick', 'actual']),
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            mealType: MealTypeSchema.optional(),
            mealName: z.string().min(1),
            calories: z.number().int().nonnegative(),
            proteinG: z.number().nonnegative(),
            carbsG: z.number().nonnegative(),
            fatG: z.number().nonnegative(),
            notes: z.string().optional(),
        }),
        needsApproval: true,
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const attachment = await ensureMealAnalysisReady(userId, input.attachmentId);

            if (input.mode === 'actual') {
                if (!input.mealType) {
                    throw new Error('mealType is required when logging the photo against a planned meal.');
                }

                const mealSlot = await getMealSlotForDate(userId, date, input.mealType);
                if (!mealSlot) {
                    throw new Error(`No ${prettyMealType(input.mealType)} meal was found for ${date}.`);
                }

                await upsertActualMealLog(userId, {
                    date,
                    mealId: mealSlot.meal.sourceMealId ?? mealSlot.meal.id,
                    mealName: input.mealName,
                    calories: input.calories,
                    proteinG: input.proteinG,
                    carbsG: input.carbsG,
                    fatG: input.fatG,
                    notes: input.notes,
                    rawPayload: {
                        source: 'meal_photo_attachment',
                        analysis: attachment.aiAnalysisResult,
                    },
                    attachmentId: input.attachmentId,
                });

                return immediateWriteResult({
                    message: `Logged that meal photo as your ${prettyMealType(input.mealType)} for ${date}.`,
                    refreshDomains: ['diet', 'home'],
                });
            }

            await createQuickMealLog(userId, {
                date,
                mealName: input.mealName,
                calories: input.calories,
                proteinG: input.proteinG,
                carbsG: input.carbsG,
                fatG: input.fatG,
                notes: input.notes,
                attachmentId: input.attachmentId,
            });

            return immediateWriteResult({
                message: `Logged that meal photo for ${date}.`,
                refreshDomains: ['diet', 'home'],
            });
        },
    };
}

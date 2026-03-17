import { and, eq } from 'drizzle-orm';
import { db } from '../db';
import { mealMediaAttachments } from '../db/schema';
import { mealAnalysisQueue } from '../lib/queue';
import { signPrivateObjectUrl } from '../lib/r2';

const MEAL_ANALYSIS_POLL_INTERVAL_MS = 1500;
const MEAL_ANALYSIS_TIMEOUT_MS = 45_000;

type MealMediaAttachmentRow = typeof mealMediaAttachments.$inferSelect;

function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

export function getMealAnalysisJobId(attachmentId: number) {
    return `meal-analysis-${attachmentId}`;
}

export async function getMealAttachmentForUser(userId: number, attachmentId: number) {
    const [attachment] = await db.select().from(mealMediaAttachments)
        .where(and(eq(mealMediaAttachments.userId, userId), eq(mealMediaAttachments.id, attachmentId)))
        .limit(1);
    return attachment ?? null;
}

export async function ensureMealAnalysisQueued(attachment: MealMediaAttachmentRow) {
    const previousStatus = attachment.aiAnalysisStatus;
    const previousResult = attachment.aiAnalysisResult;

    try {
        if (attachment.aiAnalysisStatus !== 'analyzing') {
            await db
                .update(mealMediaAttachments)
                .set({
                    aiAnalysisStatus: 'analyzing',
                    aiAnalysisResult: attachment.aiAnalysisStatus === 'failed'
                        ? null
                        : attachment.aiAnalysisResult,
                })
                .where(eq(mealMediaAttachments.id, attachment.id));
        }

        const jobId = getMealAnalysisJobId(attachment.id);
        const existingJob = await mealAnalysisQueue.getJob(jobId);
        if (existingJob) {
            const state = await existingJob.getState();
            if (state === 'failed' || state === 'completed') {
                await existingJob.remove();
            } else {
                return;
            }
        }

        await mealAnalysisQueue.add(
            'analyze-meal-photo',
            { attachmentId: attachment.id },
            { jobId },
        );
    } catch (err) {
        await db
            .update(mealMediaAttachments)
            .set({
                aiAnalysisStatus: previousStatus,
                aiAnalysisResult: previousResult,
            })
            .where(eq(mealMediaAttachments.id, attachment.id));
        throw err;
    }
}

export async function waitForMealAnalysisCompletion(
    userId: number,
    attachmentId: number,
    timeoutMs = MEAL_ANALYSIS_TIMEOUT_MS,
    pollIntervalMs = MEAL_ANALYSIS_POLL_INTERVAL_MS,
) {
    const deadline = Date.now() + timeoutMs;

    while (Date.now() < deadline) {
        const attachment = await getMealAttachmentForUser(userId, attachmentId);
        if (!attachment) {
            throw new Error('Meal photo attachment not found.');
        }

        if (attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult) {
            return attachment;
        }

        if (attachment.aiAnalysisStatus === 'failed') {
            throw new Error('Meal photo analysis failed.');
        }

        await sleep(pollIntervalMs);
    }

    throw new Error('Meal photo analysis is taking longer than expected.');
}

export async function ensureMealAnalysisReady(userId: number, attachmentId: number) {
    const attachment = await getMealAttachmentForUser(userId, attachmentId);
    if (!attachment) {
        throw new Error('Meal photo attachment not found.');
    }

    let resolved = attachment;
    if (!(attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult)) {
        await ensureMealAnalysisQueued(attachment);
        resolved = await waitForMealAnalysisCompletion(userId, attachmentId);
    }

    const signedUrl = await signPrivateObjectUrl(resolved.objectKey);
    return {
        ...resolved,
        signedUrl,
    };
}

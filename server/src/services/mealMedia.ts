import { and, eq } from 'drizzle-orm';
import { db } from '../db';
import { mealMediaAttachments, userProfile } from '../db/schema';
import { mealAnalysisQueue } from '../lib/queue';
import { signPrivateObjectUrl } from '../lib/r2';
import type { MealAnalysisResult } from '../lib/mealAnalyzer';
import { getLocalDateInTimeZone, normalizeIanaTimeZone } from '../lib/time';
import {
    createMealAnalysisJobProgress,
    getMealAnalysisPhaseLabel,
    isMealAnalysisJobProgress,
    type MealAnalysisPipelineEvent,
} from '../lib/mealAnalysisPipeline';
import { getQuickMealLogByAttachmentId, upsertQuickMealLog } from './diet';

const MEAL_ANALYSIS_POLL_INTERVAL_MS = 600;
const MEAL_ANALYSIS_TIMEOUT_MS = 180_000;

type MealMediaAttachmentRow = typeof mealMediaAttachments.$inferSelect;
type MealAnalysisProgressReporter = (
    event: MealAnalysisPipelineEvent,
) => Promise<void> | void;

function getAttachmentCreatedAtDate(value: MealMediaAttachmentRow['createdAt']) {
    return value instanceof Date ? value : new Date(value);
}

function buildMealNameFromAnalysis(result: MealAnalysisResult) {
    const names = result.ingredients
        .map((ingredient) => ingredient.name.trim())
        .filter((name) => name.length > 0)
        .slice(0, 2);

    return names.length > 0 ? names.join(', ') : 'Photo meal';
}

function sleep(ms: number) {
    return new Promise((resolve) => setTimeout(resolve, ms));
}

function logMealAnalysisInfo(message: string, details: Record<string, unknown>) {
    console.info('[meal-analysis]', message, details);
}

function mealAnalysisEventKey(event: MealAnalysisPipelineEvent) {
    return JSON.stringify({
        phase: event.phase,
        label: event.label ?? '',
        message: event.message ?? '',
    });
}

function formatMacroValue(value: number) {
    return Number.isInteger(value) ? `${value}` : value.toFixed(1);
}

function buildMealAnalysisSummaryText(result: MealAnalysisResult) {
    const ingredientNames = result.ingredients
        .map((ingredient) => ingredient.name.trim())
        .filter((name) => name.length > 0)
        .slice(0, 3);
    const ingredientPrefix = ingredientNames.length > 0
        ? `It looks like ${ingredientNames.join(', ')} with roughly `
        : 'It looks like roughly ';

    return `I have finished the analysis of the meal. ${ingredientPrefix}**${Math.round(result.macros.calories)} kcal**, **${formatMacroValue(result.macros.proteinG)}g protein**, **${formatMacroValue(result.macros.carbsG)}g carbs**, and **${formatMacroValue(result.macros.fatG)}g fat**. I am logging it now.`;
}

async function reportMealAnalysisProgress(
    reporter: MealAnalysisProgressReporter | undefined,
    sentEvents: Set<string>,
    event: MealAnalysisPipelineEvent,
) {
    if (!reporter) return;

    const key = mealAnalysisEventKey(event);
    if (sentEvents.has(key)) {
        return;
    }

    sentEvents.add(key);
    await reporter(event);
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

async function getUserTimeZone(userId: number) {
    const [profile] = await db.select({
        timezoneIana: userProfile.timezoneIana,
    }).from(userProfile)
        .where(eq(userProfile.userId, userId))
        .limit(1);

    return normalizeIanaTimeZone(profile?.timezoneIana ?? 'UTC');
}

export async function ensureMealAnalysisQueued(attachment: MealMediaAttachmentRow) {
    const previousStatus = attachment.aiAnalysisStatus;
    const previousResult = attachment.aiAnalysisResult;
    logMealAnalysisInfo('queue requested', {
        attachmentId: attachment.id,
        userId: attachment.userId,
        previousStatus,
    });

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
            logMealAnalysisInfo('existing job found', {
                attachmentId: attachment.id,
                jobId,
                state,
            });
            if (state === 'failed' || state === 'completed') {
                await existingJob.remove();
                logMealAnalysisInfo('stale job removed', {
                    attachmentId: attachment.id,
                    jobId,
                    state,
                });
            } else {
                logMealAnalysisInfo('queue request skipped because job is already active', {
                    attachmentId: attachment.id,
                    jobId,
                    state,
                });
                return;
            }
        }

        const job = await mealAnalysisQueue.add(
            'analyze-meal-photo',
            { attachmentId: attachment.id },
            { jobId },
        );
        await job.updateProgress(createMealAnalysisJobProgress('queued'));
        logMealAnalysisInfo('job queued', {
            attachmentId: attachment.id,
            userId: attachment.userId,
            jobId,
        });
    } catch (err) {
        await db
            .update(mealMediaAttachments)
            .set({
                aiAnalysisStatus: previousStatus,
                aiAnalysisResult: previousResult,
            })
            .where(eq(mealMediaAttachments.id, attachment.id));
        console.error('[meal-analysis] queue request failed', {
            attachmentId: attachment.id,
            userId: attachment.userId,
            error: err,
        });
        throw err;
    }
}

export async function waitForMealAnalysisCompletion(
    userId: number,
    attachmentId: number,
    timeoutMs = MEAL_ANALYSIS_TIMEOUT_MS,
    pollIntervalMs = MEAL_ANALYSIS_POLL_INTERVAL_MS,
    onProgress?: MealAnalysisProgressReporter,
    sentEvents: Set<string> = new Set(),
) {
    const deadline = Date.now() + timeoutMs;
    logMealAnalysisInfo('waiting for analysis completion', {
        attachmentId,
        userId,
        timeoutMs,
        pollIntervalMs,
    });

    while (Date.now() < deadline) {
        const attachment = await getMealAttachmentForUser(userId, attachmentId);
        if (!attachment) {
            throw new Error('Meal photo attachment not found.');
        }

        if (attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult) {
            return attachment;
        }

        if (attachment.aiAnalysisStatus === 'failed') {
            await reportMealAnalysisProgress(onProgress, sentEvents, {
                pipeline: 'meal_photo',
                phase: 'failed',
                label: 'Meal analysis failed.',
            });
            throw new Error('Meal photo analysis failed.');
        }

        const job = await mealAnalysisQueue.getJob(getMealAnalysisJobId(attachmentId));
        const jobProgress = job?.progress;
        if (isMealAnalysisJobProgress(jobProgress)) {
            logMealAnalysisInfo('polled job progress', {
                attachmentId,
                userId,
                phase: jobProgress.phase,
                label: jobProgress.label,
            });
            await reportMealAnalysisProgress(onProgress, sentEvents, {
                pipeline: 'meal_photo',
                phase: jobProgress.phase,
                label: jobProgress.label,
            });
        } else if (attachment.aiAnalysisStatus === 'analyzing') {
            await reportMealAnalysisProgress(onProgress, sentEvents, {
                pipeline: 'meal_photo',
                phase: 'running_analysis',
                label: getMealAnalysisPhaseLabel('running_analysis'),
            });
        } else {
            await reportMealAnalysisProgress(onProgress, sentEvents, {
                pipeline: 'meal_photo',
                phase: 'queued',
                label: getMealAnalysisPhaseLabel('queued'),
            });
        }

        await sleep(pollIntervalMs);
    }

    console.error('[meal-analysis] wait timed out', {
        attachmentId,
        userId,
        timeoutMs,
    });
    throw new Error('Meal photo analysis is taking longer than expected.');
}

export async function ensureMealAnalysisLogged(
    userId: number,
    attachment: MealMediaAttachmentRow,
    analysisResult: MealAnalysisResult,
) {
    const timeZone = await getUserTimeZone(userId);
    const date = getLocalDateInTimeZone(
        timeZone,
        getAttachmentCreatedAtDate(attachment.createdAt),
    );

    logMealAnalysisInfo('writing quick meal log from analysis', {
        attachmentId: attachment.id,
        userId,
        date,
        calories: analysisResult.macros.calories,
        proteinG: analysisResult.macros.proteinG,
        carbsG: analysisResult.macros.carbsG,
        fatG: analysisResult.macros.fatG,
    });

    return upsertQuickMealLog(userId, {
        date,
        mealName: buildMealNameFromAnalysis(analysisResult),
        calories: analysisResult.macros.calories,
        proteinG: analysisResult.macros.proteinG,
        carbsG: analysisResult.macros.carbsG,
        fatG: analysisResult.macros.fatG,
        attachmentId: attachment.id,
    });
}

export async function ensureLoggedQuickMealForAttachment(
    userId: number,
    attachment: MealMediaAttachmentRow,
) {
    if (!(attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult)) {
        logMealAnalysisInfo('skip quick log because analysis is not completed', {
            attachmentId: attachment.id,
            userId,
            status: attachment.aiAnalysisStatus,
        });
        return null;
    }

    const existing = await getQuickMealLogByAttachmentId(userId, attachment.id);
    if (existing) {
        logMealAnalysisInfo('existing quick log found for attachment', {
            attachmentId: attachment.id,
            userId,
            quickLogId: existing.id,
        });
        return existing;
    }

    logMealAnalysisInfo('no existing quick log found; creating one from stored analysis', {
        attachmentId: attachment.id,
        userId,
    });
    return ensureMealAnalysisLogged(
        userId,
        attachment,
        attachment.aiAnalysisResult as MealAnalysisResult,
    );
}

export async function ensureMealAnalysisReady(
    userId: number,
    attachmentId: number,
    options?: {
        onProgress?: MealAnalysisProgressReporter;
    },
) {
    const attachment = await getMealAttachmentForUser(userId, attachmentId);
    if (!attachment) {
        throw new Error('Meal photo attachment not found.');
    }
    logMealAnalysisInfo('ensuring analysis is ready', {
        attachmentId,
        userId,
        status: attachment.aiAnalysisStatus,
    });

    const sentEvents = new Set<string>();
    let resolved = attachment;
    if (!(attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult)) {
        await ensureMealAnalysisQueued(attachment);
        resolved = await waitForMealAnalysisCompletion(
            userId,
            attachmentId,
            MEAL_ANALYSIS_TIMEOUT_MS,
            MEAL_ANALYSIS_POLL_INTERVAL_MS,
            options?.onProgress,
            sentEvents,
        );
    }

    const analysisResult = resolved.aiAnalysisResult as MealAnalysisResult;
    logMealAnalysisInfo('analysis result is ready', {
        attachmentId,
        userId,
        calories: analysisResult.macros.calories,
        proteinG: analysisResult.macros.proteinG,
        carbsG: analysisResult.macros.carbsG,
        fatG: analysisResult.macros.fatG,
        confidence: analysisResult.confidence,
    });
    await reportMealAnalysisProgress(options?.onProgress, sentEvents, {
        pipeline: 'meal_photo',
        phase: 'analysis_complete',
        message: buildMealAnalysisSummaryText(analysisResult),
    });

    let loggedQuickMeal = await getQuickMealLogByAttachmentId(userId, resolved.id);
    if (!loggedQuickMeal) {
        logMealAnalysisInfo('no quick log found after analysis; logging meal now', {
            attachmentId,
            userId,
        });
        await reportMealAnalysisProgress(options?.onProgress, sentEvents, {
            pipeline: 'meal_photo',
            phase: 'logging_meal',
            label: 'Logging the meal...',
        });

        loggedQuickMeal = await ensureMealAnalysisLogged(
            userId,
            resolved,
            analysisResult,
        );
        logMealAnalysisInfo('quick meal log written', {
            attachmentId,
            userId,
            quickLogId: loggedQuickMeal.id,
        });

        await reportMealAnalysisProgress(options?.onProgress, sentEvents, {
            pipeline: 'meal_photo',
            phase: 'completed',
            message: 'Logging is done. Hope the food tasted awesome.',
        });
    } else {
        logMealAnalysisInfo('quick meal log already existed after analysis', {
            attachmentId,
            userId,
            quickLogId: loggedQuickMeal.id,
        });
    }

    const signedUrl = await signPrivateObjectUrl(resolved.objectKey);
    return {
        ...resolved,
        signedUrl,
        loggedQuickMeal,
    };
}

export async function getLoggedQuickMealForAttachment(userId: number, attachmentId: number) {
    return getQuickMealLogByAttachmentId(userId, attachmentId);
}

import { Worker } from 'bullmq';
import { eq } from 'drizzle-orm';
import { connection } from '../lib/queue';
import { db } from '../db';
import { mealMediaAttachments } from '../db/schema';
import { analyzeMealImage } from '../lib/mealAnalyzer';
import { createMealAnalysisJobProgress } from '../lib/mealAnalysisPipeline';

export const mealAnalysisWorker = new Worker(
    'meal-analysis',
    async (job) => {
        const { attachmentId } = job.data as { attachmentId: number };

        console.info('[meal-analysis/worker] job started', {
            jobId: job.id,
            attachmentId,
        });

        const [attachment] = await db
            .select()
            .from(mealMediaAttachments)
            .where(eq(mealMediaAttachments.id, attachmentId))
            .limit(1);

        if (!attachment) {
            throw new Error(`Attachment ${attachmentId} not found`);
        }

        try {
            const analysisResult = await analyzeMealImage(
                attachment.objectKey,
                attachment.mimeType,
                async (phase) => {
                    await job.updateProgress(createMealAnalysisJobProgress(phase));
                    console.info('[meal-analysis/worker] phase updated', {
                        jobId: job.id,
                        attachmentId,
                        phase,
                    });
                },
            );
            await job.updateProgress(createMealAnalysisJobProgress('saving_analysis'));
            console.info('[meal-analysis/worker] saving analysis result', {
                jobId: job.id,
                attachmentId,
            });

            await db
                .update(mealMediaAttachments)
                .set({
                    aiAnalysisStatus: 'completed',
                    aiAnalysisResult: analysisResult,
                })
                .where(eq(mealMediaAttachments.id, attachmentId));
            console.info('[meal-analysis/worker] analysis result persisted', {
                jobId: job.id,
                attachmentId,
                calories: analysisResult.macros.calories,
                proteinG: analysisResult.macros.proteinG,
                carbsG: analysisResult.macros.carbsG,
                fatG: analysisResult.macros.fatG,
                confidence: analysisResult.confidence,
            });
        } catch (err) {
            await db
                .update(mealMediaAttachments)
                .set({ aiAnalysisStatus: 'failed' })
                .where(eq(mealMediaAttachments.id, attachmentId));
            throw err;
        }
    },
    { connection, concurrency: 3 },
);

mealAnalysisWorker.on('active', (job) => {
    console.info('[meal-analysis/worker] job active', {
        jobId: job.id,
        attachmentId: (job.data as { attachmentId?: number }).attachmentId,
    });
});

mealAnalysisWorker.on('completed', (job) => {
    console.info('[meal-analysis/worker] job completed', {
        jobId: job.id,
        attachmentId: (job.data as { attachmentId?: number }).attachmentId,
    });
});

mealAnalysisWorker.on('failed', (job, err) => {
    console.error('[meal-analysis/worker] job failed', {
        jobId: job?.id,
        attachmentId: (job?.data as { attachmentId?: number } | undefined)
            ?.attachmentId,
        error: err.message,
    });
});

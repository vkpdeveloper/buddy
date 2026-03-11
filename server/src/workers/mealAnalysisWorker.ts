import { Worker } from 'bullmq';
import { eq } from 'drizzle-orm';
import { connection } from '../lib/queue';
import { db } from '../db';
import { mealMediaAttachments } from '../db/schema';
import { analyzeMealImage } from '../lib/mealAnalyzer';

export const mealAnalysisWorker = new Worker(
    'meal-analysis',
    async (job) => {
        const { attachmentId } = job.data as { attachmentId: number };

        console.log(`[worker] Starting meal analysis for attachment ${attachmentId}`);

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
            );

            await db
                .update(mealMediaAttachments)
                .set({
                    aiAnalysisStatus: 'completed',
                    aiAnalysisResult: analysisResult,
                })
                .where(eq(mealMediaAttachments.id, attachmentId));
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

mealAnalysisWorker.on('completed', (job) => {
    console.log(`[worker] Meal analysis job ${job.id} completed`);
});

mealAnalysisWorker.on('failed', (job, err) => {
    console.error(`[worker] Meal analysis job ${job?.id} failed:`, err.message);
});

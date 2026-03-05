import { Worker } from 'bullmq';
import { eq } from 'drizzle-orm';
import { connection } from '../lib/queue';
import { db } from '../db';
import { generationJobs } from '../db/schema';
import { runDietGeneration } from '../lib/dietGenerator';
import { runWorkoutGeneration } from '../lib/workoutGenerator';

export const plansWorker = new Worker(
    'plans-generation',
    async (job) => {
        const { type, jobRowId } = job.data as { type: 'diet' | 'workout'; jobRowId: number };

        console.log(`[worker] Starting ${type} generation (job row ${jobRowId})`);

        await db.update(generationJobs)
            .set({ status: 'generating', updatedAt: new Date().toISOString() })
            .where(eq(generationJobs.id, jobRowId));

        try {
            if (type === 'diet') {
                const { planId } = await runDietGeneration();
                console.log(`[worker] Diet plan generated: planId=${planId}`);
            } else {
                const { planId } = await runWorkoutGeneration();
                console.log(`[worker] Workout plan generated: planId=${planId}`);
            }

            await db.update(generationJobs)
                .set({ status: 'done', updatedAt: new Date().toISOString() })
                .where(eq(generationJobs.id, jobRowId));
        } catch (err) {
            const error = String(err);
            console.error(`[worker] ${type} generation failed:`, error);
            await db.update(generationJobs)
                .set({ status: 'failed', error, updatedAt: new Date().toISOString() })
                .where(eq(generationJobs.id, jobRowId));
            throw err;
        }
    },
    { connection },
);

plansWorker.on('completed', (job) => {
    console.log(`[worker] Job ${job.id} (${job.data.type}) completed`);
});

plansWorker.on('failed', (job, err) => {
    console.error(`[worker] Job ${job?.id} (${job?.data?.type}) failed:`, err.message);
});

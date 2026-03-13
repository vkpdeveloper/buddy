import { Hono } from 'hono';
import { and, desc, eq } from 'drizzle-orm';
import { db } from '../db';
import { generationJobs } from '../db/schema';
import { plansQueue } from '../lib/queue';
import {
    getGenerationStage,
    getIdleGenerationJobState,
    type GenerationJobType,
} from '../lib/generationProgress';
import { ok } from '../lib/response';

const router = new Hono();

// ─── POST /api/generation/trigger ────────────────────────────────────────────
// Enqueues diet + workout generation jobs; returns immediately.
router.post('/trigger', async (c) => {
    try {
        const userId = c.var.userId;
        const body = await c.req.json<{ types?: GenerationJobType[] }>().catch(
            () => ({ types: undefined } as { types?: GenerationJobType[] }),
        );
        const requestedTypes = (body.types?.length ? body.types : ['diet', 'workout']) as GenerationJobType[];
        const types = requestedTypes.filter((type, index) => requestedTypes.indexOf(type) === index);
        const enqueuedIds: Record<string, number> = {};

        for (const type of types) {
            // Upsert: if a pending/generating row already exists, reuse it;
            // otherwise insert a fresh pending row.
            const [existing] = await db
                .select()
                .from(generationJobs)
                .where(and(eq(generationJobs.userId, userId), eq(generationJobs.type, type)))
                .orderBy(desc(generationJobs.id))
                .limit(1);

            let jobRowId: number;

            if (existing && (existing.status === 'pending' || existing.status === 'generating')) {
                jobRowId = existing.id;
            } else {
                const initialStage = getGenerationStage(type, 'queued');
                const [inserted] = await db
                    .insert(generationJobs)
                    .values({
                        userId,
                        type,
                        status: initialStage.status,
                        stageKey: initialStage.key,
                        stageMessage: initialStage.message,
                        progressPercent: initialStage.progressPercent,
                    })
                    .returning();
                jobRowId = inserted.id;
            }

            await plansQueue.add(`generate-${type}`, { type, jobRowId });
            enqueuedIds[type] = jobRowId;
        }

        return ok(c, enqueuedIds);
    } catch (err) {
        console.error('[generation/trigger]', err);
        throw err;
    }
});

// ─── GET /api/generation/status ──────────────────────────────────────────────
// Returns the latest status for diet and workout generation.
router.get('/status', async (c) => {
    try {
        const userId = c.var.userId;
        const types: GenerationJobType[] = ['diet', 'workout'];
        const jobs: Record<
            GenerationJobType,
            {
                type: GenerationJobType;
                status: string;
                stageKey: string;
                stageMessage: string;
                progressPercent: number;
                error: string | null;
            }
        > = {
            diet: getIdleGenerationJobState('diet'),
            workout: getIdleGenerationJobState('workout'),
        };

        for (const type of types) {
            const [latest] = await db
                .select()
                .from(generationJobs)
                .where(and(eq(generationJobs.userId, userId), eq(generationJobs.type, type)))
                .orderBy(desc(generationJobs.id))
                .limit(1);

            if (latest) {
                jobs[type] = {
                    type,
                    status: latest.status,
                    stageKey: latest.stageKey,
                    stageMessage: latest.stageMessage,
                    progressPercent: latest.progressPercent,
                    error: latest.error,
                };
            }
        }

        const jobStates = Object.values(jobs);
        const overallStatus =
            jobStates.some((job) => job.status === 'failed')
                ? 'failed'
                : jobStates.every((job) => job.status === 'done')
                ? 'done'
                : jobStates.every((job) => job.status === 'idle')
                ? 'idle'
                : 'generating';

        const unfinishedJobs = jobStates.filter(
            (job) => job.status === 'pending' || job.status === 'generating',
        );
        const primarySource =
            unfinishedJobs.sort((left, right) => left.progressPercent - right.progressPercent)[0]
            ?? jobStates.find((job) => job.status === 'failed')
            ?? jobStates.find((job) => job.status === 'done')
            ?? jobStates[0];

        const overallProgressPercent = Math.round(
            jobStates.reduce((sum, job) => sum + job.progressPercent, 0) / jobStates.length,
        );

        return ok(c, {
            overallStatus,
            overallProgressPercent,
            primaryMessage: primarySource.stageMessage,
            jobs,
        });
    } catch (err) {
        throw err;
    }
});

export default router;

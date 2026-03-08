import { Hono } from 'hono';
import { and, desc, eq } from 'drizzle-orm';
import { db } from '../db';
import { generationJobs } from '../db/schema';
import { plansQueue } from '../lib/queue';
import { ok } from '../lib/response';

const router = new Hono();

// ─── POST /api/generation/trigger ────────────────────────────────────────────
// Enqueues diet + workout generation jobs; returns immediately.
router.post('/trigger', async (c) => {
    try {
        const userId = c.var.userId;
        const types: Array<'diet' | 'workout'> = ['diet', 'workout'];
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
                const [inserted] = await db
                    .insert(generationJobs)
                    .values({ userId, type, status: 'pending' })
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
        const types: Array<'diet' | 'workout'> = ['diet', 'workout'];
        const result: Record<string, string> = { diet: 'idle', workout: 'idle' };

        for (const type of types) {
            const [latest] = await db
                .select()
                .from(generationJobs)
                .where(and(eq(generationJobs.userId, userId), eq(generationJobs.type, type)))
                .orderBy(desc(generationJobs.id))
                .limit(1);

            if (latest) result[type] = latest.status;
        }

        return ok(c, result);
    } catch (err) {
        throw err;
    }
});

export default router;

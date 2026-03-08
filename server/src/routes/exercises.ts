import { Hono } from 'hono';
import { and, eq } from 'drizzle-orm';
import { db } from '../db';
import { exerciseCatalog, personalRecords } from '../db/schema';
import { ok } from '../lib/response';

const router = new Hono();

// ─── GET /api/exercises ───────────────────────────────────────────────────────
router.get('/', async (c) => {
    const muscleGroup = c.req.query('muscleGroup');
    const equipment = c.req.query('equipment');

    const results = await db.select().from(exerciseCatalog);
    const filtered = results.filter((ex) => {
        if (muscleGroup && ex.muscleGroup.toLowerCase() !== muscleGroup.toLowerCase()) return false;
        if (equipment && ex.equipment.toLowerCase() !== equipment.toLowerCase()) return false;
        return true;
    });

    return ok(c, filtered);
});

// ─── GET /api/exercises/prs ───────────────────────────────────────────────────
router.get('/prs', async (c) => {
    const userId = c.var.userId;
    const prs = await db.select().from(personalRecords).where(eq(personalRecords.userId, userId));
    const prMap: Record<string, typeof personalRecords.$inferSelect> = {};
    for (const pr of prs) {
        prMap[pr.exerciseNameNormalized] = pr;
    }
    return ok(c, prMap);
});

// ─── GET /api/exercises/prs/:name ────────────────────────────────────────────
router.get('/prs/:name', async (c) => {
    const userId = c.var.userId;
    const name = decodeURIComponent(c.req.param('name'));
    const [pr] = await db.select().from(personalRecords)
        .where(and(eq(personalRecords.userId, userId), eq(personalRecords.exerciseNameNormalized, name)))
        .limit(1);
    return ok(c, pr ?? null);
});

export default router;

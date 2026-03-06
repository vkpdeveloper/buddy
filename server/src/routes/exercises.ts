import { Hono } from 'hono';
import { and, eq } from 'drizzle-orm';
import { db } from '../db';
import { exerciseCatalog, personalRecords } from '../db/schema';

const router = new Hono();

// ─── GET /api/exercises ───────────────────────────────────────────────────────
router.get('/', async (c) => {
    try {
        const muscleGroup = c.req.query('muscleGroup');
        const equipment = c.req.query('equipment');

        let query = db.select().from(exerciseCatalog);

        const results = await query;
        const filtered = results.filter((ex) => {
            if (muscleGroup && ex.muscleGroup.toLowerCase() !== muscleGroup.toLowerCase()) return false;
            if (equipment && ex.equipment.toLowerCase() !== equipment.toLowerCase()) return false;
            return true;
        });

        return c.json({ success: true, data: filtered });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/exercises/prs ───────────────────────────────────────────────────
router.get('/prs', async (c) => {
    try {
        const userId = c.var.userId;
        const prs = await db.select().from(personalRecords).where(eq(personalRecords.userId, userId));
        const prMap: Record<string, typeof personalRecords.$inferSelect> = {};
        for (const pr of prs) {
            prMap[pr.exerciseNameNormalized] = pr;
        }
        return c.json({ success: true, data: prMap });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/exercises/prs/:name ────────────────────────────────────────────
router.get('/prs/:name', async (c) => {
    try {
        const userId = c.var.userId;
        const name = decodeURIComponent(c.req.param('name'));
        const [pr] = await db.select().from(personalRecords)
            .where(and(eq(personalRecords.userId, userId), eq(personalRecords.exerciseNameNormalized, name)))
            .limit(1);
        if (!pr) return c.json({ success: true, data: null });
        return c.json({ success: true, data: pr });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

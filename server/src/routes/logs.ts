import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { eq, desc } from 'drizzle-orm';
import { db } from '../db';
import { dailyLogs } from '../db/schema';

const router = new Hono();

// ─── GET /api/logs/week ──────────────────────────────────────────────────────
router.get('/week', async (c) => {
    try {
        const rows = await db.select().from(dailyLogs)
            .orderBy(desc(dailyLogs.date))
            .limit(7);
        return c.json({ success: true, data: rows });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/logs/:date ─────────────────────────────────────────────────────
router.get('/:date', async (c) => {
    try {
        const date = c.req.param('date');
        const [row] = await db.select().from(dailyLogs).where(eq(dailyLogs.date, date));
        if (!row) {
            // Return zeroed log if none exists yet
            return c.json({
                success: true,
                data: { date, waterMl: 0, sleepMinutes: 0, stepsCount: 0, caloriesBurned: 0 },
            });
        }
        return c.json({ success: true, data: row });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

const logSchema = z.object({
    waterMl: z.number().int().min(0).optional(),
    sleepMinutes: z.number().int().min(0).optional(),
    stepsCount: z.number().int().min(0).optional(),
    caloriesBurned: z.number().int().min(0).optional(),
});

// ─── PUT /api/logs/:date ─────────────────────────────────────────────────────
router.put('/:date', zValidator('json', logSchema), async (c) => {
    try {
        const date = c.req.param('date');
        const body = c.req.valid('json');

        const [existing] = await db.select().from(dailyLogs).where(eq(dailyLogs.date, date));

        let result;
        if (existing) {
            const updateData: Partial<typeof dailyLogs.$inferInsert> = {
                updatedAt: new Date().toISOString(),
            };
            if (body.waterMl !== undefined) updateData.waterMl = body.waterMl;
            if (body.sleepMinutes !== undefined) updateData.sleepMinutes = body.sleepMinutes;
            if (body.stepsCount !== undefined) updateData.stepsCount = body.stepsCount;
            if (body.caloriesBurned !== undefined) updateData.caloriesBurned = body.caloriesBurned;
            result = await db.update(dailyLogs).set(updateData).where(eq(dailyLogs.date, date)).returning();
        } else {
            result = await db.insert(dailyLogs).values({
                date,
                waterMl: body.waterMl ?? 0,
                sleepMinutes: body.sleepMinutes ?? 0,
                stepsCount: body.stepsCount ?? 0,
                caloriesBurned: body.caloriesBurned ?? 0,
            }).returning();
        }

        return c.json({ success: true, data: result[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

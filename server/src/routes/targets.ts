import { Hono } from 'hono';
import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { ok } from '../lib/response';
import { ensureUserTargetsRow, syncProfileFromTargets } from '../lib/userTargets';
import { userTargets } from '../db/schema';

const router = new Hono();

const targetsSchema = z.object({
  dailySteps: z.number().int().min(2000).max(50000).optional(),
  dailySleepTarget: z.number().min(4).max(12).optional(),
  dailyWaterMl: z.number().int().min(500).max(6000).optional(),
  targetWeight: z.number().min(30).max(300).nullable().optional(),
  dailyCalorieBurn: z.number().int().min(0).max(5000).optional(),
});

router.get('/', async (c) => {
  const userId = c.var.userId;
  const targets = await ensureUserTargetsRow(userId);
  return ok(c, targets);
});

router.put('/', async (c) => {
  const userId = c.var.userId;

  let raw: Record<string, unknown>;
  try {
    raw = await c.req.json();
  } catch {
    return c.json({ success: false, error: 'Invalid JSON body' }, 400);
  }

  const cleaned = Object.fromEntries(
    Object.entries(raw).filter(([, value]) => value !== undefined),
  );

  const parsed = targetsSchema.safeParse(cleaned);
  if (!parsed.success) {
    return c.json({ success: false, error: parsed.error }, 400);
  }

  await ensureUserTargetsRow(userId);
  const body = parsed.data;
  const updateData: Partial<typeof userTargets.$inferInsert> = {
    updatedAt: new Date().toISOString(),
  };

  if (body.dailySteps !== undefined) updateData.dailySteps = body.dailySteps;
  if (body.dailySleepTarget !== undefined) {
    updateData.dailySleepTarget = body.dailySleepTarget;
  }
  if (body.dailyWaterMl !== undefined) updateData.dailyWaterMl = body.dailyWaterMl;
  if (body.targetWeight !== undefined) updateData.targetWeight = body.targetWeight;
  if (body.dailyCalorieBurn !== undefined) {
    updateData.dailyCalorieBurn = body.dailyCalorieBurn;
  }

  const updated = await db
    .update(userTargets)
    .set(updateData)
    .where(eq(userTargets.userId, userId))
    .returning();

  await syncProfileFromTargets(userId, {
    dailyWaterMl: body.dailyWaterMl,
    targetWeight: body.targetWeight,
  });

  return ok(c, updated[0]);
});

export default router;

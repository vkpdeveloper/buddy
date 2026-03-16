import { Hono } from 'hono';
import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { ok } from '../lib/response';
import { ensureUserTargetsRow, syncProfileFromTargets } from '../lib/userTargets';
import { userTargets } from '../db/schema';
import { updateDailyTargets } from '../services/targets';

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

  const updated = await updateDailyTargets(userId, parsed.data);
  return ok(c, updated);
});

export default router;

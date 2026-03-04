import { Hono } from 'hono';
import { desc, eq } from 'drizzle-orm';
import { db } from '../db';
import {
    bodyMeasurements,
    userProgress,
    achievements,
    userAchievements,
} from '../db/schema';
import { getLevel, getLevelLabel, getStreakMultiplier } from '../lib/xp';

const router = new Hono();

// XP awarded per body measurement log
const BODY_LOG_XP_BASE = 75;

// ─── POST /api/body/log ───────────────────────────────────────────────────────
router.post('/log', async (c) => {
    try {
        const body = await c.req.json() as {
            date: string;
            weightKg?: number | null;
            chestCm?: number | null;
            waistCm?: number | null;
            hipsCm?: number | null;
            armsCm?: number | null;
            thighsCm?: number | null;
            notes?: string;
        };

        if (!body.date) {
            return c.json({ success: false, error: 'date is required' }, 400);
        }

        // ── Get / ensure user progress row ──────────────────────────────────
        let progRows = await db.select().from(userProgress).limit(1);
        if (progRows.length === 0) {
            await db.insert(userProgress).values({});
            progRows = await db.select().from(userProgress).limit(1);
        }
        const prog = progRows[0];

        // ── Calculate XP ────────────────────────────────────────────────────
        const multiplier = getStreakMultiplier(prog.currentStreak);
        const xpEarned = Math.round(BODY_LOG_XP_BASE * multiplier);

        // ── Insert measurement ───────────────────────────────────────────────
        await db.insert(bodyMeasurements).values({
            date: body.date,
            weightKg: body.weightKg ?? null,
            chestCm: body.chestCm ?? null,
            waistCm: body.waistCm ?? null,
            hipsCm: body.hipsCm ?? null,
            armsCm: body.armsCm ?? null,
            thighsCm: body.thighsCm ?? null,
            notes: body.notes ?? '',
            xpEarned,
        });

        // ── Award XP ─────────────────────────────────────────────────────────
        const previousLevel = getLevel(prog.totalXp);
        const newTotalXp = prog.totalXp + xpEarned;
        const newLevel = getLevel(newTotalXp);
        const didLevelUp = newLevel > previousLevel;

        await db.update(userProgress)
            .set({
                totalXp: newTotalXp,
                currentLevel: newLevel,
                updatedAt: new Date().toISOString(),
            })
            .where(eq(userProgress.id, prog.id));

        // ── Check achievements ────────────────────────────────────────────────
        const unlockedRows = await db.select().from(userAchievements);
        const unlockedSlugs = new Set(
            (await Promise.all(
                unlockedRows.map(u =>
                    db.select().from(achievements).where(eq(achievements.id, u.achievementId)).limit(1)
                )
            )).map(r => r[0]?.slug).filter(Boolean) as string[]
        );

        const newAchievements: typeof achievements.$inferSelect[] = [];
        const totalLogs = await db.select().from(bodyMeasurements);

        // first_body_log achievement
        if (totalLogs.length === 1 && !unlockedSlugs.has('first_body_log')) {
            const ach = await db.select().from(achievements)
                .where(eq(achievements.slug, 'first_body_log'))
                .limit(1);
            if (ach.length > 0) {
                await db.insert(userAchievements).values({ achievementId: ach[0].id });
                // Award achievement XP too
                await db.update(userProgress)
                    .set({ totalXp: newTotalXp + xpEarned + ach[0].xpReward })
                    .where(eq(userProgress.id, prog.id));
                newAchievements.push(ach[0]);
            }
        }

        return c.json({
            success: true,
            data: {
                xpEarned,
                multiplier,
                previousLevel,
                newLevel,
                newTotalXp,
                levelLabel: getLevelLabel(newLevel),
                didLevelUp,
                newAchievements: newAchievements.map(a => ({
                    slug: a.slug,
                    name: a.name,
                    description: a.description,
                    xpReward: a.xpReward,
                    iconName: a.iconName,
                })),
            },
        });
    } catch (err) {
        console.error('[body/log] error:', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/body/history ────────────────────────────────────────────────────
router.get('/history', async (c) => {
    try {
        const rows = await db.select()
            .from(bodyMeasurements)
            .orderBy(desc(bodyMeasurements.date))
            .limit(60);

        return c.json({ success: true, data: rows });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/body/latest ─────────────────────────────────────────────────────
router.get('/latest', async (c) => {
    try {
        const rows = await db.select()
            .from(bodyMeasurements)
            .orderBy(desc(bodyMeasurements.date))
            .limit(1);

        return c.json({ success: true, data: rows[0] ?? null });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

import { Hono } from 'hono';
import { inArray } from 'drizzle-orm';
import { db } from '../db';
import { userProgress, achievements, userAchievements } from '../db/schema';
import { getLevel, getLevelLabel, getLevelProgressFraction, ACHIEVEMENT_SEED } from '../lib/xp';

const router = new Hono();

// ─── Seed achievements if needed ─────────────────────────────────────────────
export async function seedAchievements() {
    const existing = await db.select().from(achievements);
    if (existing.length === 0) {
        await db.insert(achievements).values(ACHIEVEMENT_SEED);
        console.log('[achievements] seeded 12 rows');
    }
}

// ─── Ensure user_progress row exists ─────────────────────────────────────────
export async function ensureUserProgress() {
    const rows = await db.select().from(userProgress).limit(1);
    if (rows.length === 0) {
        await db.insert(userProgress).values({});
        console.log('[user_progress] initialized');
    }
}

// ─── GET /api/progress ───────────────────────────────────────────────────────
router.get('/', async (c) => {
    try {
        await ensureUserProgress();
        const [prog] = await db.select().from(userProgress).limit(1);

        const level = getLevel(prog.totalXp);
        const levelLabel = getLevelLabel(level);
        const levelProgressFraction = getLevelProgressFraction(prog.totalXp);

        // Get recent achievements (last 5)
        const recentUnlocks = await db.select({
            id: userAchievements.id,
            unlockedAt: userAchievements.unlockedAt,
            achievementId: userAchievements.achievementId,
        }).from(userAchievements)
            .orderBy(userAchievements.unlockedAt)
            .limit(5);

        const achievementIds = recentUnlocks.map(u => u.achievementId);
        const achievementRows = achievementIds.length > 0
            ? await db.select().from(achievements).where(inArray(achievements.id, achievementIds))
            : [];

        const recentAchievements = recentUnlocks.map(u => {
            const a = achievementRows.find(r => r.id === u.achievementId);
            return a ? { ...a, unlockedAt: u.unlockedAt } : null;
        }).filter(Boolean);

        return c.json({
            success: true,
            data: {
                totalXp: prog.totalXp,
                currentLevel: level,
                levelLabel,
                levelProgressFraction,
                currentStreak: prog.currentStreak,
                longestStreak: prog.longestStreak,
                totalWorkoutsCompleted: prog.totalWorkoutsCompleted,
                lastWorkoutDate: prog.lastWorkoutDate,
                recentAchievements,
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/progress/achievements ─────────────────────────────────────────
router.get('/achievements', async (c) => {
    try {
        const all = await db.select().from(achievements);
        const unlocked = await db.select().from(userAchievements);

        const unlockedMap = new Map(unlocked.map(u => [u.achievementId, u.unlockedAt]));

        const result = all.map(a => ({
            ...a,
            isUnlocked: unlockedMap.has(a.id),
            unlockedAt: unlockedMap.get(a.id) ?? null,
        }));

        return c.json({ success: true, data: result });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

import { Hono } from 'hono';
import { and, eq, inArray, isNotNull } from 'drizzle-orm';
import { ok } from '../lib/response';
import { db } from '../db';
import {
    userProgress,
    achievements,
    userAchievements,
    workoutDays,
    workoutPlans,
    workoutSessions,
} from '../db/schema';
import { getLevel, getLevelLabel, getLevelProgressFraction, ACHIEVEMENT_SEED } from '../lib/xp';

const router = new Hono();
const WEEK_MILLISECONDS = 7 * 24 * 60 * 60 * 1000;

type WeekAggregate = {
    weekStart: string;
    weekEndExclusive: string;
    sessionsCompleted: number;
    totalXp: number;
    plannedWorkouts: number;
    completionFraction: number;
    score: number;
    challengeXp: number;
    streakProtectionUsed: boolean;
};

function isoDate(date: Date): string {
    return date.toISOString().slice(0, 10);
}

function startOfWeek(date: Date): Date {
    const value = new Date(date);
    const day = value.getDay(); // 0..6 (Sun..Sat)
    const diffToMonday = day === 0 ? -6 : 1 - day;
    value.setDate(value.getDate() + diffToMonday);
    value.setHours(0, 0, 0, 0);
    return value;
}

function getWeekRange(date: Date): { start: Date; end: Date } {
    const start = startOfWeek(date);
    const end = new Date(start);
    end.setDate(start.getDate() + 7);
    return { start, end };
}

function scoreWeek(input: {
    sessionsCompleted: number;
    totalXp: number;
    plannedWorkouts: number;
}): number {
    const completionFraction = input.plannedWorkouts > 0
        ? Math.min(input.sessionsCompleted / input.plannedWorkouts, 1)
        : 0;
    return Math.round(
        input.totalXp + (input.sessionsCompleted * 120) + (completionFraction * 200),
    );
}

function buildWeekAggregate(
    weekStartDate: Date,
    input: {
        sessionsCompleted: number;
        totalXp: number;
        plannedWorkouts: number;
    },
): WeekAggregate {
    const weekEnd = new Date(weekStartDate);
    weekEnd.setDate(weekStartDate.getDate() + 7);
    const completionFraction = input.plannedWorkouts > 0
        ? Math.min(input.sessionsCompleted / input.plannedWorkouts, 1)
        : 0;
    return {
        weekStart: isoDate(weekStartDate),
        weekEndExclusive: isoDate(weekEnd),
        sessionsCompleted: input.sessionsCompleted,
        totalXp: input.totalXp,
        plannedWorkouts: input.plannedWorkouts,
        completionFraction,
        score: scoreWeek(input),
        challengeXp: 0,
        streakProtectionUsed: false,
    };
}

async function getPlannedWorkoutsByPlanId(planIds: number[]) {
    if (planIds.length === 0) return new Map<number, number>();

    const [days, plans] = await Promise.all([
        db.select().from(workoutDays).where(inArray(workoutDays.planId, planIds)),
        db.select().from(workoutPlans).where(inArray(workoutPlans.id, planIds)),
    ]);

    const plannedByPlan = new Map<number, number>();
    for (const plan of plans) {
        plannedByPlan.set(plan.id, Math.max(plan.daysPerWeek, 0));
    }

    const nonRestByPlan = new Map<number, number>();
    for (const day of days) {
        if (day.isRestDay) continue;
        nonRestByPlan.set(day.planId, (nonRestByPlan.get(day.planId) ?? 0) + 1);
    }

    for (const [planId, nonRestCount] of nonRestByPlan.entries()) {
        if (nonRestCount > 0) plannedByPlan.set(planId, nonRestCount);
    }

    return plannedByPlan;
}

async function getSoloLeaderboard(userId: string) {
    const now = new Date();
    const currentWeek = getWeekRange(now);
    const [activePlan] = await db.select().from(workoutPlans)
        .where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true)))
        .limit(1);

    const completedSessions = await db.select({
        planId: workoutSessions.planId,
        completedAt: workoutSessions.completedAt,
        xpEarned: workoutSessions.xpEarned,
    }).from(workoutSessions).where(and(
        eq(workoutSessions.userId, userId),
        isNotNull(workoutSessions.completedAt),
        eq(workoutSessions.completedExercises, workoutSessions.totalExercises),
    ));

    const planIds = [
        ...new Set([
            ...completedSessions.map((session) => session.planId),
            activePlan?.id,
        ].filter((value): value is number => typeof value === 'number')),
    ];
    const plannedByPlanId = await getPlannedWorkoutsByPlanId(planIds);
    const fallbackPlanned = Math.max(activePlan?.daysPerWeek ?? 0, 0);

    const weeklyMap = new Map<string, {
        weekStartDate: Date;
        sessionsCompleted: number;
        totalXp: number;
        plannedWorkouts: number;
    }>();

    for (const session of completedSessions) {
        if (!session.completedAt) continue;
        const weekStartDate = startOfWeek(new Date(session.completedAt));
        const key = isoDate(weekStartDate);
        const plannedForSession = plannedByPlanId.get(session.planId) ?? fallbackPlanned;
        const existing = weeklyMap.get(key);
        if (!existing) {
            weeklyMap.set(key, {
                weekStartDate,
                sessionsCompleted: 1,
                totalXp: session.xpEarned ?? 0,
                plannedWorkouts: plannedForSession,
            });
            continue;
        }
        existing.sessionsCompleted += 1;
        existing.totalXp += session.xpEarned ?? 0;
        existing.plannedWorkouts = Math.max(existing.plannedWorkouts, plannedForSession);
    }

    const currentWeekKey = isoDate(currentWeek.start);
    if (!weeklyMap.has(currentWeekKey)) {
        weeklyMap.set(currentWeekKey, {
            weekStartDate: currentWeek.start,
            sessionsCompleted: 0,
            totalXp: 0,
            plannedWorkouts: fallbackPlanned,
        });
    }

    const allWeeks = [...weeklyMap.values()].map((week) =>
        buildWeekAggregate(week.weekStartDate, {
            sessionsCompleted: week.sessionsCompleted,
            totalXp: week.totalXp,
            plannedWorkouts: week.plannedWorkouts,
        }),
    );

    const sortedAllWeeks = [...allWeeks].sort((a, b) => {
        if (b.score !== a.score) return b.score - a.score;
        if (b.sessionsCompleted !== a.sessionsCompleted) return b.sessionsCompleted - a.sessionsCompleted;
        return b.weekStart.localeCompare(a.weekStart);
    });

    const currentWeekSummary = allWeeks.find((week) => week.weekStart === currentWeekKey)
        ?? buildWeekAggregate(currentWeek.start, {
            sessionsCompleted: 0,
            totalXp: 0,
            plannedWorkouts: fallbackPlanned,
        });

    const currentRank = sortedAllWeeks.findIndex((week) => week.weekStart === currentWeekKey) + 1;
    const historicalWeeks = sortedAllWeeks.filter((week) => week.weekStart !== currentWeekKey);
    const topHistoricalWeeks = historicalWeeks.slice(0, 5).map((week, index) => ({
        ...week,
        rank: index + 1,
    }));

    const elapsedRaw = Math.ceil((now.getTime() - currentWeek.start.getTime()) / (24 * 60 * 60 * 1000));
    const daysElapsed = Math.max(1, Math.min(elapsedRaw, 7));
    const daysRemaining = Math.max(0, 7 - daysElapsed);
    const projectedScore = Math.round((currentWeekSummary.score / daysElapsed) * 7);

    const historicalBestScore = topHistoricalWeeks.length > 0 ? topHistoricalWeeks[0].score : 0;
    const projectedGapToBest = Math.max(0, historicalBestScore - projectedScore);

    return {
        metric: {
            label: 'Weekly Momentum Score',
            formula:
                'score = weekly XP + 120 x completed sessions + completion bonus (up to 200)',
        },
        topWeeks: topHistoricalWeeks,
        currentWeek: {
            ...currentWeekSummary,
            rank: currentRank === 0 ? null : currentRank,
            projectedScore,
            projectedGapToBest,
        },
        trajectory: {
            daysElapsed,
            daysRemaining,
            currentScore: currentWeekSummary.score,
            projectedScore,
            currentRank: currentRank === 0 ? null : currentRank,
            weeksTracked: historicalWeeks.length,
        },
        phase2: {
            challengeRewardsEnabled: false,
            streakProtectionEnabled: false,
        },
        generatedAt: new Date().toISOString(),
        lookbackWeeks: Math.max(
            0,
            Math.ceil((now.getTime() - (sortedAllWeeks.at(-1)?.weekStart
                ? new Date(sortedAllWeeks.at(-1)!.weekStart).getTime()
                : now.getTime())) / WEEK_MILLISECONDS),
        ),
    };
}

// ─── Seed achievements if needed ─────────────────────────────────────────────
export async function seedAchievements() {
    const existing = await db.select().from(achievements);
    if (existing.length === 0) {
        await db.insert(achievements).values(ACHIEVEMENT_SEED);
        console.log('[achievements] seeded 12 rows');
    }
}

// ─── Ensure user_progress row exists ─────────────────────────────────────────
export async function ensureUserProgress(userId: string) {
    const rows = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
    if (rows.length === 0) {
        await db.insert(userProgress).values({ userId });
        console.log('[user_progress] initialized for', userId);
    }
}

// ─── GET /api/progress ───────────────────────────────────────────────────────
router.get('/', async (c) => {
    const userId = c.var.userId;
        await ensureUserProgress(userId);
        const [prog] = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);

        const level = getLevel(prog.totalXp);
        const levelLabel = getLevelLabel(level);
        const levelProgressFraction = getLevelProgressFraction(prog.totalXp);
        const soloLeaderboard = await getSoloLeaderboard(userId);

        // Get recent achievements (last 5)
        const recentUnlocks = await db.select({
            id: userAchievements.id,
            unlockedAt: userAchievements.unlockedAt,
            achievementId: userAchievements.achievementId,
        }).from(userAchievements)
            .where(eq(userAchievements.userId, userId))
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

        return ok(c, {
            totalXp: prog.totalXp,
            currentLevel: level,
            levelLabel,
            levelProgressFraction,
            currentStreak: prog.currentStreak,
            longestStreak: prog.longestStreak,
            totalWorkoutsCompleted: prog.totalWorkoutsCompleted,
            lastWorkoutDate: prog.lastWorkoutDate,
            recentAchievements,
            soloLeaderboard,
        });
});

// ─── GET /api/progress/achievements ─────────────────────────────────────────
router.get('/achievements', async (c) => {
    const userId = c.var.userId;
        const all = await db.select().from(achievements);
        const unlocked = await db.select().from(userAchievements).where(eq(userAchievements.userId, userId));

        const unlockedMap = new Map(unlocked.map(u => [u.achievementId, u.unlockedAt]));

        const result = all.map(a => ({
            ...a,
            isUnlocked: unlockedMap.has(a.id),
            unlockedAt: unlockedMap.get(a.id) ?? null,
        }));

        return ok(c, result);
});

export default router;

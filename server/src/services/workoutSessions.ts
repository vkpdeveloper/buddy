import { and, desc, eq, inArray, isNotNull, sql } from 'drizzle-orm';
import { db } from '../db';
import {
    achievements,
    personalRecords,
    userAchievements,
    userProgress,
    workoutDays,
    workoutExercises,
    workoutPlans,
    workoutSessions,
} from '../db/schema';
import { calculateNewStreak, calculateXp, checkAchievements, getLevel, getLevelLabel } from '../lib/xp';
import { ensureUserProgress } from '../routes/progress';
import { getDayNumberFromDate } from '../lib/time';

type SessionSetLog = Record<string, unknown>;
type SessionNote = Record<string, unknown>;

export async function getActiveWorkoutDayForDate(userId: number, date: string) {
    const dayNumber = getDayNumberFromDate(date);
    const [activePlan] = await db.select().from(workoutPlans)
        .where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true)))
        .limit(1);
    if (!activePlan) return null;

    const [day] = await db.select().from(workoutDays)
        .where(and(eq(workoutDays.planId, activePlan.id), eq(workoutDays.dayNumber, dayNumber)))
        .limit(1);
    if (!day) return null;

    const exercises = await db.select().from(workoutExercises)
        .where(eq(workoutExercises.dayId, day.id))
        .orderBy(workoutExercises.orderIndex);

    return { plan: activePlan, day, exercises };
}

export async function getWorkoutSessionForDate(userId: number, planId: number, dayId: number, date: string) {
    const [session] = await db.select().from(workoutSessions)
        .where(and(
            eq(workoutSessions.userId, userId),
            eq(workoutSessions.planId, planId),
            eq(workoutSessions.dayId, dayId),
            sql`date(${workoutSessions.startedAt}) = ${date}`,
        ))
        .orderBy(desc(workoutSessions.id))
        .limit(1);
    return session ?? null;
}

export async function ensureWorkoutSessionForDate(userId: number, planId: number, dayId: number, date: string) {
    const existing = await getWorkoutSessionForDate(userId, planId, dayId, date);
    if (existing) return existing;
    const [session] = await db.insert(workoutSessions).values({
        userId,
        planId,
        dayId,
        startedAt: `${date}T08:00:00.000Z`,
    }).returning();
    return session;
}

function normalizeExerciseName(name: string): string {
    return name
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

function parseRepsLowerBound(repsOrTime: string): number | null {
    const raw = repsOrTime.trim();
    if (/^[\d.]+\s*(s|sec|secs|second|seconds|m|min|minute|minutes)$/i.test(raw)) return null;
    const rangeMatch = raw.match(/(\d+)\s*[-–]\s*\d+/);
    if (rangeMatch) return Number(rangeMatch[1]);
    const numMatch = raw.match(/^(\d+)/);
    return numMatch ? Number(numMatch[1]) : null;
}

async function completeWorkoutSession(userId: number, params: {
    sessionId: number;
    date: string;
    totalDurationSeconds: number;
    totalExercises: number;
    completedExercises: number;
    totalRests: number;
    skippedRests: number;
    completedSets: number;
    setLogs?: SessionSetLog[];
    sessionNotes?: SessionNote[];
    dayLabel?: string;
}) {
    await ensureUserProgress(userId);
    const [progress] = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
    const today = params.date;

    let newStreak = progress.currentStreak;
    const streakResult = calculateNewStreak(progress.lastWorkoutDate, today);
    if (streakResult === 999) {
        newStreak = progress.currentStreak + 1;
    } else if (streakResult === 0) {
        newStreak = progress.currentStreak;
    } else {
        newStreak = 1;
    }

    const breakdown = calculateXp({
        completedSets: params.completedSets,
        totalRests: params.totalRests,
        skippedRests: params.skippedRests,
        totalExercises: params.totalExercises,
        completedExercises: params.completedExercises,
        durationSeconds: params.totalDurationSeconds,
        currentStreak: progress.currentStreak,
    });

    const previousLevel = getLevel(progress.totalXp);
    const newTotalXp = progress.totalXp + breakdown.total;
    const newWorkoutsCompleted = progress.totalWorkoutsCompleted + 1;

    const weekLabels: string[] = [];
    if (params.dayLabel) weekLabels.push(params.dayLabel);

    const existingUnlocks = await db.select({ achievementId: userAchievements.achievementId })
        .from(userAchievements)
        .where(eq(userAchievements.userId, userId));
    const allAchievements = await db.select().from(achievements);
    const unlockedSlugs = new Set(
        existingUnlocks.map((unlock) => allAchievements.find((achievement) => achievement.id === unlock.achievementId)?.slug)
            .filter(Boolean) as string[],
    );

    const [session] = await db.select().from(workoutSessions).where(eq(workoutSessions.id, params.sessionId)).limit(1);
    const startedAt = session?.startedAt ?? `${params.date}T08:00:00.000Z`;

    const earnedSlugs = checkAchievements({
        totalWorkoutsCompleted: newWorkoutsCompleted,
        currentStreak: newStreak,
        completedExercises: params.completedExercises,
        totalExercises: params.totalExercises,
        skippedRests: params.skippedRests,
        totalRests: params.totalRests,
        durationSeconds: params.totalDurationSeconds,
        startedAt,
        dayLabels: weekLabels,
        unlockedSlugs,
    });

    const earnedAchievementRows = earnedSlugs.length > 0
        ? allAchievements.filter((achievement) => earnedSlugs.includes(achievement.slug))
        : [];
    const achievementXp = earnedAchievementRows.reduce((sum, achievement) => sum + achievement.xpReward, 0);
    const finalTotalXp = newTotalXp + achievementXp;
    const finalLevel = getLevel(finalTotalXp);

    await db.update(workoutSessions).set({
        completedAt: `${params.date}T18:00:00.000Z`,
        totalDurationSeconds: params.totalDurationSeconds,
        totalExercises: params.totalExercises,
        completedExercises: params.completedExercises,
        totalRests: params.totalRests,
        skippedRests: params.skippedRests,
        pausedDurationSeconds: 0,
        warmupData: JSON.stringify({}),
        cooldownData: JSON.stringify({}),
        setLogs: JSON.stringify(params.setLogs ?? []),
        sessionNotes: JSON.stringify(params.sessionNotes ?? []),
        hrSnapshots: JSON.stringify([]),
        xpEarned: breakdown.total,
    }).where(eq(workoutSessions.id, params.sessionId));

    for (const achievement of earnedAchievementRows) {
        await db.insert(userAchievements).values({
            userId,
            achievementId: achievement.id,
            sessionId: params.sessionId,
        });
    }

    await db.update(userProgress).set({
        totalXp: finalTotalXp,
        currentLevel: finalLevel,
        currentStreak: newStreak,
        longestStreak: Math.max(progress.longestStreak, newStreak),
        lastWorkoutDate: today,
        totalWorkoutsCompleted: newWorkoutsCompleted,
        updatedAt: new Date().toISOString(),
    }).where(eq(userProgress.userId, userId));

    const newPrs: typeof personalRecords.$inferSelect[] = [];
    try {
        if (session) {
            const dayExercises = await db.select().from(workoutExercises)
                .where(eq(workoutExercises.dayId, session.dayId))
                .orderBy(workoutExercises.orderIndex);
            const achievedAt = `${params.date}T18:00:00.000Z`;
            for (const log of params.setLogs ?? []) {
                const status = String(log.status ?? '');
                if (status !== 'completed') continue;
                const weightKg = Number(log.weightKg);
                if (!Number.isFinite(weightKg) || weightKg <= 0) continue;

                const exerciseName = String(log.exerciseName ?? '');
                if (!exerciseName) continue;
                const normalized = normalizeExerciseName(exerciseName);
                const exerciseIndex = Number(log.exerciseIndex ?? -1);
                const dayExercise = dayExercises[exerciseIndex];
                const reps = parseRepsLowerBound(dayExercise?.repsOrTime ?? '10-12');
                if (reps === null) continue;

                const [existing] = await db.select().from(personalRecords)
                    .where(and(eq(personalRecords.userId, userId), eq(personalRecords.exerciseNameNormalized, normalized)))
                    .limit(1);
                if (!existing || weightKg >= existing.weightKg) {
                    const [upserted] = await db.insert(personalRecords).values({
                        userId,
                        exerciseNameNormalized: normalized,
                        exerciseNameDisplay: exerciseName,
                        weightKg,
                        reps,
                        achievedAt,
                        sessionId: params.sessionId,
                    }).onConflictDoUpdate({
                        target: [personalRecords.userId, personalRecords.exerciseNameNormalized],
                        set: {
                            weightKg,
                            reps,
                            achievedAt,
                            sessionId: params.sessionId,
                            exerciseNameDisplay: exerciseName,
                        },
                    }).returning();
                    if (upserted && (!existing || weightKg > existing.weightKg)) {
                        newPrs.push(upserted);
                    }
                }
            }
        }
    } catch (error) {
        console.error('[workoutSessions] PR tracking error:', error);
    }

    return {
        xpEarned: breakdown.total,
        xpBreakdown: breakdown,
        achievementXp,
        previousLevel,
        newLevel: finalLevel,
        didLevelUp: finalLevel > previousLevel,
        levelLabel: getLevelLabel(finalLevel),
        currentStreak: newStreak,
        newAchievements: earnedAchievementRows,
        newPrs,
    };
}

export async function completeWorkoutFromDetailedLog(userId: number, params: {
    date: string;
    durationSeconds: number;
    setLogs: SessionSetLog[];
    sessionNotes?: SessionNote[];
    skippedRests?: number;
}) {
    const active = await getActiveWorkoutDayForDate(userId, params.date);
    if (!active || active.day.isRestDay) {
        throw new Error('No active planned workout available for that date.');
    }

    const session = await ensureWorkoutSessionForDate(userId, active.plan.id, active.day.id, params.date);
    if (session.completedAt) {
        throw new Error('A workout is already logged for that date.');
    }
    const completedSetLogs = params.setLogs.filter((log) => String(log.status ?? '') === 'completed');
    const completedExerciseIndexes = new Set(
        completedSetLogs
            .map((log) => Number(log.exerciseIndex))
            .filter((value) => Number.isInteger(value) && value >= 0),
    );
    const totalExercises = active.exercises.length;
    const completedExercises = Math.min(totalExercises, completedExerciseIndexes.size);
    const completedSets = completedSetLogs.length;
    const totalRests = Math.max(completedSets - completedExercises, 0);

    return completeWorkoutSession(userId, {
        sessionId: session.id,
        date: params.date,
        totalDurationSeconds: params.durationSeconds,
        totalExercises,
        completedExercises,
        totalRests,
        skippedRests: Math.max(params.skippedRests ?? 0, 0),
        completedSets,
        setLogs: params.setLogs,
        sessionNotes: params.sessionNotes,
        dayLabel: active.day.dayLabel,
    });
}

export async function completeWorkoutFromSummary(userId: number, params: {
    date: string;
    durationSeconds: number;
    completedExerciseCount?: number;
    notes?: string;
}) {
    const active = await getActiveWorkoutDayForDate(userId, params.date);
    if (!active || active.day.isRestDay) {
        throw new Error('No active planned workout available for that date.');
    }

    const session = await ensureWorkoutSessionForDate(userId, active.plan.id, active.day.id, params.date);
    if (session.completedAt) {
        throw new Error('A workout is already logged for that date.');
    }
    const totalExercises = active.exercises.length;
    const completedExercises = Math.min(
        totalExercises,
        Math.max(params.completedExerciseCount ?? totalExercises, 1),
    );
    const completedSets = active.exercises
        .slice(0, completedExercises)
        .reduce((sum, exercise) => sum + exercise.sets, 0);
    const totalRests = Math.max(completedSets - completedExercises, 0);
    const sessionNotes = params.notes
        ? [{ source: 'buddy_summary', note: params.notes }]
        : [];

    return completeWorkoutSession(userId, {
        sessionId: session.id,
        date: params.date,
        totalDurationSeconds: params.durationSeconds,
        totalExercises,
        completedExercises,
        totalRests,
        skippedRests: 0,
        completedSets,
        setLogs: [],
        sessionNotes,
        dayLabel: active.day.dayLabel,
    });
}

export async function getRecentCompletedSessions(userId: number, limit = 10) {
    const sessions = await db.select({
        id: workoutSessions.id,
        dayId: workoutSessions.dayId,
        completedAt: workoutSessions.completedAt,
        totalDurationSeconds: workoutSessions.totalDurationSeconds,
        completedExercises: workoutSessions.completedExercises,
        totalExercises: workoutSessions.totalExercises,
        totalRests: workoutSessions.totalRests,
        skippedRests: workoutSessions.skippedRests,
        xpEarned: workoutSessions.xpEarned,
    }).from(workoutSessions).where(and(
        eq(workoutSessions.userId, userId),
        isNotNull(workoutSessions.completedAt),
    )).orderBy(desc(workoutSessions.completedAt)).limit(limit);

    const dayIds = [...new Set(sessions.map((session) => session.dayId))];
    const days = dayIds.length > 0
        ? await db.select({ id: workoutDays.id, dayLabel: workoutDays.dayLabel })
            .from(workoutDays)
            .where(inArray(workoutDays.id, dayIds))
        : [];
    const dayMap = new Map(days.map((day) => [day.id, day.dayLabel]));

    return sessions.map((session) => ({
        date: session.completedAt?.slice(0, 10) ?? 'unknown',
        dayLabel: dayMap.get(session.dayId) ?? 'Unknown',
        durationMinutes: Math.round((session.totalDurationSeconds ?? 0) / 60),
        completedExercises: session.completedExercises,
        totalExercises: session.totalExercises,
        completionRate: session.totalExercises > 0
            ? `${Math.round((session.completedExercises / session.totalExercises) * 100)}%`
            : 'N/A',
        xpEarned: session.xpEarned,
        restDiscipline: session.skippedRests === 0
            ? 'perfect'
            : `skipped ${session.skippedRests} of ${session.totalRests} rests`,
    }));
}

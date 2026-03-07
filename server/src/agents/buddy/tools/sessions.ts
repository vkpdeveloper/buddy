import { z } from 'zod';
import { and, eq, desc, inArray, isNotNull } from 'drizzle-orm';
import { db } from '../../../db';
import { workoutSessions, workoutDays } from '../../../db/schema';
import { Tool } from 'ai';

export function getRecentSessionsTool(userId: string): Tool {
    return {
        description:
            "Get the user's recent completed workout sessions — dates, which day they trained (Push/Pull/Legs/etc.), duration, exercise completion rate, and XP earned. Call this when the user asks about workout history, recent sessions, consistency, how they've been doing lately, or patterns in their training.",
        inputSchema: z.object({
            limit: z
                .number()
                .int()
                .min(1)
                .max(30)
                .optional()
                .describe('Number of recent sessions to return (default: 10, max: 30)'),
        }),
        execute: async ({ limit = 10 }: { limit?: number }) => {
            const sessions = await db
                .select({
                    id: workoutSessions.id,
                    dayId: workoutSessions.dayId,
                    completedAt: workoutSessions.completedAt,
                    totalDurationSeconds: workoutSessions.totalDurationSeconds,
                    completedExercises: workoutSessions.completedExercises,
                    totalExercises: workoutSessions.totalExercises,
                    totalRests: workoutSessions.totalRests,
                    skippedRests: workoutSessions.skippedRests,
                    xpEarned: workoutSessions.xpEarned,
                })
                .from(workoutSessions)
                .where(and(eq(workoutSessions.userId, userId), isNotNull(workoutSessions.completedAt)))
                .orderBy(desc(workoutSessions.completedAt))
                .limit(limit);

            if (sessions.length === 0) return { sessions: [], message: 'No completed sessions yet.' };

            // Enrich with day labels
            const dayIds = [...new Set(sessions.map(s => s.dayId))];
            const days = dayIds.length > 0
                ? await db
                    .select({ id: workoutDays.id, dayLabel: workoutDays.dayLabel })
                    .from(workoutDays)
                    .where(inArray(workoutDays.id, dayIds))
                : [];
            const dayMap = new Map(days.map(d => [d.id, d.dayLabel]));

            return {
                sessions: sessions.map(s => ({
                    date: s.completedAt?.slice(0, 10) ?? 'unknown',
                    dayLabel: dayMap.get(s.dayId) ?? 'Unknown',
                    durationMinutes: Math.round((s.totalDurationSeconds ?? 0) / 60),
                    completedExercises: s.completedExercises,
                    totalExercises: s.totalExercises,
                    completionRate: s.totalExercises > 0
                        ? `${Math.round((s.completedExercises / s.totalExercises) * 100)}%`
                        : 'N/A',
                    xpEarned: s.xpEarned,
                    restDiscipline: s.skippedRests === 0
                        ? 'perfect'
                        : `skipped ${s.skippedRests} of ${s.totalRests} rests`,
                })),
            };
        },
    };
}

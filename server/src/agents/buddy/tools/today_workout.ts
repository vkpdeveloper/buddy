import { z } from 'zod';
import { Tool } from 'ai';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { getActiveWorkoutDayForDate, getWorkoutSessionForDate } from '../../../services/workoutSessions';

export function getTodayWorkoutTool(userId: number, timeZone: string): Tool {
    return {
        description:
            "Get today's recommended workout — which training day is up next in the user's cycle (Push/Pull/Legs/Upper/Lower/etc.) and all the exercises with sets, reps, and rest times. Call this when the user asks what workout to do today, today's training, today's exercises, or what's next in their program.",
        inputSchema: z.object({}),
        execute: async () => {
            const todayDate = getLocalDateInTimeZone(timeZone);
            const active = await getActiveWorkoutDayForDate(userId, todayDate);
            if (!active) {
                throw new Error('No active workout plan found. User needs to generate one first.');
            }

            const session = await getWorkoutSessionForDate(userId, active.plan.id, active.day.id, todayDate);
            const isTodayAlreadyCompleted = Boolean(session?.completedAt);

            return {
                date: todayDate,
                planTitle: active.plan.title,
                cycleType: active.plan.cycleType,
                todayDayLabel: active.day.dayLabel,
                isRestDay: active.day.isRestDay,
                sessionId: session?.id ?? null,
                sessionStartedAt: session?.startedAt ?? null,
                sessionCompletedAt: session?.completedAt ?? null,
                isTodayAlreadyCompleted: isTodayAlreadyCompleted,
                exercises: active.exercises.map(e => ({
                    name: e.name,
                    sets: e.sets,
                    repsOrTime: e.repsOrTime,
                    restSeconds: e.restSeconds,
                    muscleGroup: e.muscleGroup,
                    equipment: e.equipment,
                    notes: e.notes,
                    ...(e.supersetGroupId != null ? { supersetGroupId: e.supersetGroupId, supersetOrder: e.supersetOrder } : {}),
                })),
            };
        },
    };
}

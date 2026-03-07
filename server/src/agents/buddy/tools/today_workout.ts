import { z } from 'zod';
import { and, eq, desc, isNotNull } from 'drizzle-orm';
import { db } from '../../../db';
import { workoutPlans, workoutDays, workoutExercises, workoutSessions } from '../../../db/schema';
import { Tool } from 'ai';

export function getTodayWorkoutTool(userId: string): Tool {
    return {
        description:
            "Get today's recommended workout — which training day is up next in the user's cycle (Push/Pull/Legs/Upper/Lower/etc.) and all the exercises with sets, reps, and rest times. Call this when the user asks what workout to do today, today's training, today's exercises, or what's next in their program.",
        inputSchema: z.object({}),
        execute: async () => {

            const todayDayNumber = new Date().getDay() + 1;

            const [activePlan] = await db
                .select({
                    id: workoutPlans.id,
                    title: workoutPlans.title,
                    cycleType: workoutPlans.cycleType,
                })
                .from(workoutPlans)
                .where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true)))
                .limit(1);

            if (!activePlan) throw new Error('No active workout plan found. User needs to generate one first.');

            const [todaysWorkoutDay] = await db
                .select({
                    isRestDay: workoutDays.isRestDay,
                    dayNumber: workoutDays.dayNumber,
                    dayLabel: workoutDays.dayLabel,
                    id: workoutDays.id,
                })
                .from(workoutDays)
                .where(and(eq(workoutDays.planId, activePlan.id), eq(workoutDays.dayNumber, todayDayNumber)))
                .limit(1);

            // Find last completed session to determine which day is next
            const [lastSession] = await db
                .select({ dayId: workoutSessions.dayId, completedAt: workoutSessions.completedAt, dayLabel: workoutDays.dayLabel })
                .from(workoutSessions)
                .leftJoin(workoutDays, eq(workoutSessions.dayId, workoutDays.id))
                .where(and(eq(workoutSessions.userId, userId), isNotNull(workoutSessions.completedAt)))
                .orderBy(desc(workoutSessions.completedAt))
                .limit(1);

            const exercises = await db
                .select()
                .from(workoutExercises)
                .where(eq(workoutExercises.dayId, todaysWorkoutDay.id));

            exercises.sort((a, b) => a.orderIndex - b.orderIndex);

            const isTodayAlreadyCompleted = lastSession?.dayId == todaysWorkoutDay.id;

            return {
                planTitle: activePlan.title,
                cycleType: activePlan.cycleType,
                todayDayLabel: todaysWorkoutDay.dayLabel,
                isRestDay: todaysWorkoutDay.isRestDay,
                lastWorkoutDayLabel: lastSession
                    ? lastSession.dayLabel
                    : null,
                lastWorkoutDate: lastSession?.completedAt?.slice(0, 10) ?? null,
                isTodayAlreadyCompleted: isTodayAlreadyCompleted,
                exercises: exercises.map(e => ({
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

import { z } from 'zod';
import { and, eq } from 'drizzle-orm';
import { db } from '../../../db';
import { workoutPlans, workoutDays, workoutExercises } from '../../../db/schema';
import { Tool } from 'ai';

export function getFullWorkoutPlanTool(userId: string): Tool {
    return {
        description:
            "Get the user's full workout plan — every training day with all exercises, sets, reps, rest times, and muscle groups. Call this when the user asks about their workout program, training split, all exercises, a specific workout day (e.g. 'what's my Pull day?'), or equipment being used.",
        inputSchema: z.object({}),
        execute: async () => {
            const [activePlan] = await db
                .select()
                .from(workoutPlans)
                .where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true)))
                .limit(1);

            if (!activePlan) throw new Error('No active workout plan found.');

            const days = await db
                .select()
                .from(workoutDays)
                .where(eq(workoutDays.planId, activePlan.id));

            const daysWithExercises = await Promise.all(
                days.sort((a, b) => a.dayNumber - b.dayNumber).map(async day => {
                    if (day.isRestDay) {
                        return { dayNumber: day.dayNumber, dayLabel: day.dayLabel, isRestDay: true, exercises: [] };
                    }

                    const exercises = await db
                        .select({
                            name: workoutExercises.name,
                            sets: workoutExercises.sets,
                            repsOrTime: workoutExercises.repsOrTime,
                            restSeconds: workoutExercises.restSeconds,
                            muscleGroup: workoutExercises.muscleGroup,
                            equipment: workoutExercises.equipment,
                            notes: workoutExercises.notes,
                            orderIndex: workoutExercises.orderIndex,
                            supersetGroupId: workoutExercises.supersetGroupId,
                        })
                        .from(workoutExercises)
                        .where(eq(workoutExercises.dayId, day.id));

                    exercises.sort((a, b) => a.orderIndex - b.orderIndex);

                    return {
                        dayNumber: day.dayNumber,
                        dayLabel: day.dayLabel,
                        isRestDay: false,
                        exercises: exercises.map(({ orderIndex: _, ...e }) => e),
                    };
                }),
            );

            return {
                planTitle: activePlan.title,
                cycleType: activePlan.cycleType,
                daysPerWeek: activePlan.daysPerWeek,
                equipment: JSON.parse(activePlan.equipment ?? '["dumbbells"]'),
                days: daysWithExercises,
            };
        },
    };
}

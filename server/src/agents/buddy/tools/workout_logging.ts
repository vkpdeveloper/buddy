import { Tool } from 'ai';
import { z } from 'zod';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { poundsToKg } from '../../../lib/unitConversions';
import {
    completeWorkoutFromDetailedLog,
    completeWorkoutFromSummary,
    getActiveWorkoutDayForDate,
    getWorkoutSessionForDate,
} from '../../../services/workoutSessions';
import { immediateWriteResult } from './tool_output';

const WeightInputSchema = z.object({
    value: z.number().positive(),
    unit: z.enum(['kg', 'lb']),
});

const WorkoutSetLogSchema = z.object({
    exerciseName: z.string().min(1),
    setNumber: z.number().int().positive(),
    status: z.enum(['completed', 'skipped']).default('completed'),
    repsCompleted: z.number().int().positive().optional(),
    weight: WeightInputSchema.optional(),
});

type WorkoutSetLogInput = z.infer<typeof WorkoutSetLogSchema>;

function normalizeWeight(weight?: z.infer<typeof WeightInputSchema>) {
    if (!weight) return undefined;
    return weight.unit === 'kg' ? weight.value : poundsToKg(weight.value);
}

function normalizeExerciseName(name: string) {
    return name
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, '')
        .replace(/\s+/g, ' ')
        .trim();
}

function resolveExerciseIndex(exerciseName: string, exerciseNames: string[]) {
    const normalizedInput = normalizeExerciseName(exerciseName);

    const exactIndex = exerciseNames.findIndex(
        (name) => normalizeExerciseName(name) === normalizedInput,
    );
    if (exactIndex >= 0) return exactIndex;

    const containsIndex = exerciseNames.findIndex((name) => {
        const normalizedName = normalizeExerciseName(name);
        return normalizedName.includes(normalizedInput) || normalizedInput.includes(normalizedName);
    });
    return containsIndex;
}

function parseSessionPayload(sessionValue: string | null | undefined) {
    if (!sessionValue) return [];
    try {
        const parsed = JSON.parse(sessionValue);
        return Array.isArray(parsed) ? parsed : [];
    } catch {
        return [];
    }
}

export function getWorkoutLoggingContextTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Get the active planned workout day for the user’s local date, plus any existing same-day workout session state and logged set data.',
        inputSchema: z.object({
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
        }),
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const active = await getActiveWorkoutDayForDate(userId, date);
            if (!active) {
                return {
                    date,
                    hasWorkout: false,
                };
            }

            const session = await getWorkoutSessionForDate(userId, active.plan.id, active.day.id, date);

            return {
                date,
                hasWorkout: !active.day.isRestDay,
                planTitle: active.plan.title,
                cycleType: active.plan.cycleType,
                dayLabel: active.day.dayLabel,
                isRestDay: active.day.isRestDay,
                exercises: active.exercises.map((exercise, index) => ({
                    index,
                    name: exercise.name,
                    sets: exercise.sets,
                    repsOrTime: exercise.repsOrTime,
                    restSeconds: exercise.restSeconds,
                })),
                session: session
                    ? {
                        id: session.id,
                        startedAt: session.startedAt,
                        completedAt: session.completedAt,
                        totalDurationSeconds: session.totalDurationSeconds,
                        completedExercises: session.completedExercises,
                        totalExercises: session.totalExercises,
                        skippedRests: session.skippedRests,
                        setLogs: parseSessionPayload(session.setLogs),
                        sessionNotes: parseSessionPayload(session.sessionNotes),
                    }
                    : null,
            };
        },
    };
}

export function logDetailedWorkoutTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Immediately log a workout when the user explicitly provides exercise-by-exercise set details for today’s planned workout.',
        inputSchema: z.object({
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            durationMinutes: z.number().positive(),
            skippedRests: z.number().int().min(0).optional(),
            notes: z.string().optional(),
            setLogs: z.array(WorkoutSetLogSchema).min(1),
        }),
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const active = await getActiveWorkoutDayForDate(userId, date);
            if (!active || active.day.isRestDay) {
                throw new Error('No active planned workout is available for that date.');
            }

            const exerciseNames = active.exercises.map((exercise) => exercise.name);
            const mappedSetLogs = input.setLogs.map((log: WorkoutSetLogInput) => {
                const exerciseIndex = resolveExerciseIndex(log.exerciseName, exerciseNames);
                if (exerciseIndex < 0) {
                    throw new Error(`Could not match "${log.exerciseName}" to today’s planned workout.`);
                }

                return {
                    exerciseName: active.exercises[exerciseIndex]?.name ?? log.exerciseName,
                    exerciseIndex,
                    setNumber: log.setNumber,
                    status: log.status,
                    ...(log.repsCompleted !== undefined ? { repsCompleted: log.repsCompleted } : {}),
                    ...(log.weight ? { weightKg: normalizeWeight(log.weight) } : {}),
                };
            });

            const result = await completeWorkoutFromDetailedLog(userId, {
                date,
                durationSeconds: Math.round(input.durationMinutes * 60),
                skippedRests: input.skippedRests,
                setLogs: mappedSetLogs,
                sessionNotes: input.notes ? [{ source: 'buddy_detailed', note: input.notes }] : [],
            });

            return immediateWriteResult({
                message: `Logged your ${active.day.dayLabel} workout for ${date}.`,
                refreshDomains: ['workout', 'home', 'progress'],
                data: {
                    xpEarned: result.xpEarned,
                    currentStreak: result.currentStreak,
                    didLevelUp: result.didLevelUp,
                    newPrCount: result.newPrs.length,
                },
            });
        },
    };
}

export function logWorkoutSummaryTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Log a workout from a high-level summary when the user does not provide explicit set-by-set details. This tool requires approval before it executes.',
        inputSchema: z.object({
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            durationMinutes: z.number().positive(),
            completedExerciseCount: z.number().int().positive().optional(),
            notes: z.string().optional(),
        }),
        needsApproval: true,
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const active = await getActiveWorkoutDayForDate(userId, date);
            if (!active || active.day.isRestDay) {
                throw new Error('No active planned workout is available for that date.');
            }

            const completedExerciseCount = Math.min(
                input.completedExerciseCount ?? active.exercises.length,
                active.exercises.length,
            );

            const result = await completeWorkoutFromSummary(userId, {
                date,
                durationSeconds: Math.round(input.durationMinutes * 60),
                completedExerciseCount,
                notes: input.notes,
            });

            return immediateWriteResult({
                message: `Logged your ${active.day.dayLabel} workout for ${date}.`,
                refreshDomains: ['workout', 'home', 'progress'],
                data: {
                    xpEarned: result.xpEarned,
                    currentStreak: result.currentStreak,
                    didLevelUp: result.didLevelUp,
                },
            });
        },
    };
}

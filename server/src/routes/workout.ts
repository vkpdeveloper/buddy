import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { and, desc, eq, gte, inArray, isNull, lt, sql } from 'drizzle-orm';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateObject } from 'ai';
import { env } from '../lib/env';
import { db } from '../db';
import { userProfile, workoutPlans, workoutDays, workoutExercises, workoutSessions, userProgress, achievements, userAchievements, personalRecords } from '../db/schema';
import { calculateXp, calculateNewStreak, checkAchievements, getLevel, getLevelLabel } from '../lib/xp';
import { ensureUserProgress } from './progress';

const router = new Hono();
const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const WorkoutExerciseSchema = z.object({
    orderIndex: z.number().int(),
    name: z.string(),
    sets: z.number().int(),
    repsOrTime: z.string(),
    restSeconds: z.number().int(),
    muscleGroup: z.string(),
    equipment: z.string(),
    notes: z.string(),
    supersetGroupId: z.number().int().nullable().optional(),
    supersetOrder: z.number().int().nullable().optional(),
});

const WorkoutPlanSchema = z.object({
    title: z.string(),
    days: z.array(z.object({
        dayLabel: z.string(),
        exercises: z.array(WorkoutExerciseSchema),
    })),
});

const ExerciseReplacementResultSchema = z.object({
    name: z.string(),
    sets: z.number().int(),
    repsOrTime: z.string(),
    restSeconds: z.number().int(),
    muscleGroup: z.string(),
    equipment: z.string(),
    notes: z.string(),
});

type WorkoutExerciseRow = typeof workoutExercises.$inferSelect;

const safeParseArray = (value: string | null | undefined): any[] => {
    if (!value) return [];
    try {
        const parsed = JSON.parse(value);
        return Array.isArray(parsed) ? parsed : [];
    } catch {
        return [];
    }
};

const safeParseObject = (value: string | null | undefined): Record<string, unknown> => {
    if (!value) return {};
    try {
        const parsed = JSON.parse(value);
        return parsed && typeof parsed === 'object' && !Array.isArray(parsed) ? parsed : {};
    } catch {
        return {};
    }
};

const sessionWithParsedPayload = (session: typeof workoutSessions.$inferSelect) => ({
    ...session,
    warmupData: safeParseObject(session.warmupData),
    cooldownData: safeParseObject(session.cooldownData),
    setLogs: safeParseArray(session.setLogs),
    sessionNotes: safeParseArray(session.sessionNotes),
    hrSnapshots: safeParseArray(session.hrSnapshots),
});

const parseSeconds = (value: string): number | null => {
    const raw = value.toLowerCase().trim();
    const minMatch = raw.match(/(\d+(?:\.\d+)?)\s*(m|min|minute|minutes)/);
    if (minMatch) return Math.round(Number(minMatch[1]) * 60);
    const secMatch = raw.match(/(\d+(?:\.\d+)?)\s*(s|sec|secs|second|seconds)/);
    if (secMatch) return Math.round(Number(secMatch[1]));
    if (/^\d+$/.test(raw)) return Number(raw);
    return null;
};

const averageRepCount = (repsOrTime: string): number | null => {
    const rangeMatch = repsOrTime.match(/(\d+)\s*[-–]\s*(\d+)/);
    if (rangeMatch) {
        const low = Number(rangeMatch[1]);
        const high = Number(rangeMatch[2]);
        return Math.round((low + high) / 2);
    }
    const numberMatch = repsOrTime.match(/(\d+)/);
    return numberMatch ? Number(numberMatch[1]) : null;
};

const estimateExerciseDurationSeconds = (exercise: Pick<WorkoutExerciseRow, 'sets' | 'repsOrTime' | 'restSeconds'>): number => {
    const sets = Math.max(exercise.sets || 0, 1);
    const repsOrTime = (exercise.repsOrTime || '').toString();
    const directSetSeconds = parseSeconds(repsOrTime);
    const avgReps = averageRepCount(repsOrTime) ?? 10;
    const perSetWorkSeconds = directSetSeconds
        ? Math.min(Math.max(directSetSeconds, 20), 180)
        : Math.min(Math.max(avgReps * 4 + 20, 25), 140);
    const restSeconds = Math.max(exercise.restSeconds || 0, 0);
    const workBlock = sets * perSetWorkSeconds;
    const restBlock = Math.max(sets - 1, 0) * restSeconds;
    const setupBlock = sets * 10;
    return workBlock + restBlock + setupBlock;
};

const estimateDayDurationSeconds = (exercises: WorkoutExerciseRow[]): number => {
    if (exercises.length === 0) return 0;
    const exerciseSeconds = exercises.reduce(
        (sum, exercise) => sum + estimateExerciseDurationSeconds(exercise),
        0,
    );
    const transitions = Math.max(exercises.length - 1, 0) * 45;
    const warmupAndCooldown = 8 * 60;
    return exerciseSeconds + transitions + warmupAndCooldown;
};

const estimateSessionVolume = (
    session: typeof workoutSessions.$inferSelect,
    dayExercises: WorkoutExerciseRow[],
): number => {
    const setLogs = safeParseArray(session.setLogs);
    const weightedLogs = setLogs
        .filter((log) => log && typeof log === 'object')
        .map((log) => {
            const map = log as Record<string, unknown>;
            const status = (map.status ?? '').toString();
            const weightKg = Number(map.weightKg);
            const exerciseIndex = Number(map.exerciseIndex);
            const setNumber = Number(map.setNumber);
            if (status !== 'completed' || !Number.isFinite(weightKg) || weightKg <= 0) return 0;
            if (!Number.isInteger(exerciseIndex) || !Number.isInteger(setNumber)) return 0;
            const exercise = dayExercises[exerciseIndex];
            if (!exercise) return 0;
            const reps = averageRepCount(exercise.repsOrTime) ?? 10;
            return weightKg * reps;
        })
        .reduce((sum, item) => sum + item, 0);

    if (weightedLogs > 0) return Math.round(weightedLogs);

    return dayExercises.reduce((sum, exercise) => {
        const reps = averageRepCount(exercise.repsOrTime) ?? 10;
        return sum + reps * exercise.sets;
    }, 0);
};

const normalizeExerciseName = (name: string): string => name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, '')
    .replace(/\s+/g, ' ')
    .trim();

const parseRepsLowerBound = (repsOrTime: string): number | null => {
    const raw = repsOrTime.trim();
    // Skip time-based entries like "30s", "2min", "45 seconds"
    if (/^[\d.]+\s*(s|sec|secs|second|seconds|m|min|minute|minutes)$/i.test(raw)) return null;
    const rangeMatch = raw.match(/(\d+)\s*[-–]\s*\d+/);
    if (rangeMatch) return Number(rangeMatch[1]);
    const numMatch = raw.match(/^(\d+)/);
    return numMatch ? Number(numMatch[1]) : null;
};

const fallbackExercisePool: Record<string, Array<{
    name: string;
    sets: number;
    repsOrTime: string;
    restSeconds: number;
    equipment: string;
    notes: string;
}>> = {
    chest: [
        { name: 'Incline Dumbbell Press', sets: 4, repsOrTime: '8-12', restSeconds: 90, equipment: 'Dumbbell', notes: 'Keep elbows 45° from torso.' },
        { name: 'Dumbbell Floor Press', sets: 4, repsOrTime: '8-12', restSeconds: 75, equipment: 'Dumbbell', notes: 'Pause briefly at the bottom.' },
    ],
    back: [
        { name: 'Chest-Supported Dumbbell Row', sets: 4, repsOrTime: '8-12', restSeconds: 90, equipment: 'Dumbbell', notes: 'Pull elbows toward hips.' },
        { name: 'Single-Arm Cable Row', sets: 3, repsOrTime: '10-12', restSeconds: 75, equipment: 'Cable', notes: 'Control eccentric on every rep.' },
    ],
    legs: [
        { name: 'Goblet Squat', sets: 4, repsOrTime: '8-12', restSeconds: 90, equipment: 'Dumbbell', notes: 'Keep torso tall and core braced.' },
        { name: 'Reverse Lunge', sets: 3, repsOrTime: '10-12', restSeconds: 75, equipment: 'Bodyweight', notes: 'Drive through front heel.' },
    ],
    shoulders: [
        { name: 'Seated Dumbbell Shoulder Press', sets: 4, repsOrTime: '8-10', restSeconds: 90, equipment: 'Dumbbell', notes: 'Avoid lumbar extension.' },
        { name: 'Lean-Away Lateral Raise', sets: 3, repsOrTime: '12-15', restSeconds: 60, equipment: 'Dumbbell', notes: 'Lead with elbows.' },
    ],
    arms: [
        { name: 'Alternating Dumbbell Curl', sets: 3, repsOrTime: '10-12', restSeconds: 60, equipment: 'Dumbbell', notes: 'Keep shoulders down.' },
        { name: 'Overhead Triceps Extension', sets: 3, repsOrTime: '10-12', restSeconds: 60, equipment: 'Dumbbell', notes: 'Lock upper arms in place.' },
    ],
    core: [
        { name: 'Dead Bug', sets: 3, repsOrTime: '30s', restSeconds: 45, equipment: 'Bodyweight', notes: 'Keep lower back pressed down.' },
        { name: 'Cable Pallof Press', sets: 3, repsOrTime: '12-15', restSeconds: 45, equipment: 'Cable', notes: 'Avoid torso rotation.' },
    ],
};

const CYCLE_TEMPLATES: Record<string, { days: { label: string; isRest: boolean }[] }> = {
    ppl: {
        days: [
            { label: 'Push', isRest: false },
            { label: 'Pull', isRest: false },
            { label: 'Legs', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Push', isRest: false },
            { label: 'Pull', isRest: false },
            { label: 'Legs', isRest: false },
        ],
    },
    upper_lower: {
        days: [
            { label: 'Upper', isRest: false },
            { label: 'Lower', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Upper', isRest: false },
            { label: 'Lower', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Rest', isRest: true },
        ],
    },
    ppl_upper: {
        days: [
            { label: 'Push', isRest: false },
            { label: 'Pull', isRest: false },
            { label: 'Legs', isRest: false },
            { label: 'Upper', isRest: false },
            { label: 'Push', isRest: false },
            { label: 'Pull', isRest: false },
            { label: 'Rest', isRest: true },
        ],
    },
    full_body: {
        days: [
            { label: 'Full Body', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Full Body', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Full Body', isRest: false },
            { label: 'Rest', isRest: true },
            { label: 'Rest', isRest: true },
        ],
    },
};

// ─── GET /api/workout/plans ──────────────────────────────────────────────────
router.get('/plans', async (c) => {
    try {
        const userId = c.var.userId;
        const plans = await db.select().from(workoutPlans).where(eq(workoutPlans.userId, userId)).orderBy(workoutPlans.createdAt);
        return c.json({ success: true, data: plans });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/plans/:id ──────────────────────────────────────────────
router.get('/plans/:id', async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const [plan] = await db.select().from(workoutPlans).where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.id, id)));
        if (!plan) return c.json({ success: false, error: 'Plan not found' }, 404);

        const days = await db.select().from(workoutDays)
            .where(eq(workoutDays.planId, id))
            .orderBy(workoutDays.dayNumber);

        const daysWithExercises = await Promise.all(days.map(async (day) => {
            if (day.isRestDay) return { ...day, exercises: [], estimatedDurationSeconds: 0 };
            const exercises = await db.select().from(workoutExercises)
                .where(eq(workoutExercises.dayId, day.id))
                .orderBy(workoutExercises.orderIndex);
            return {
                ...day,
                exercises,
                estimatedDurationSeconds: estimateDayDurationSeconds(exercises),
            };
        }));

        return c.json({ success: true, data: { ...plan, days: daysWithExercises } });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/summary/weekly ────────────────────────────────────────
router.get('/summary/weekly', async (c) => {
    try {
        const userId = c.var.userId;
        const now = new Date();
        const day = now.getDay(); // 0..6 (Sun..Sat)
        const diffToMonday = day === 0 ? -6 : 1 - day;
        const start = new Date(now);
        start.setDate(now.getDate() + diffToMonday);
        start.setHours(0, 0, 0, 0);
        const end = new Date(start);
        end.setDate(start.getDate() + 7);

        const [activePlan] = await db.select().from(workoutPlans).where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.isActive, true))).limit(1);
        if (!activePlan) {
            return c.json({
                success: true,
                data: {
                    weekStart: start.toISOString().slice(0, 10),
                    weekEndExclusive: end.toISOString().slice(0, 10),
                    workoutsCompleted: 0,
                    plannedWorkouts: 0,
                    completionFraction: 0,
                },
            });
        }

        const planDays = await db.select().from(workoutDays).where(eq(workoutDays.planId, activePlan.id));
        const plannedWorkouts = planDays.filter((d) => !d.isRestDay).length || activePlan.daysPerWeek;

        const completed = await db.select().from(workoutSessions).where(and(
            eq(workoutSessions.userId, userId),
            eq(workoutSessions.planId, activePlan.id),
            gte(workoutSessions.completedAt, start.toISOString()),
            lt(workoutSessions.completedAt, end.toISOString()),
        ));
        const workoutsCompleted = completed.length;
        const completionFraction = plannedWorkouts > 0
            ? Math.min(workoutsCompleted / plannedWorkouts, 1)
            : 0;

        return c.json({
            success: true,
            data: {
                weekStart: start.toISOString().slice(0, 10),
                weekEndExclusive: end.toISOString().slice(0, 10),
                workoutsCompleted,
                plannedWorkouts,
                completionFraction,
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/workout/generate ─────────────────────────────────────────────
router.post('/generate', async (c) => {
    try {
        const userId = c.var.userId;
        const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
        if (profiles.length === 0) return c.json({ success: false, error: 'Profile not found' }, 400);
        const profile = profiles[0];

        const equipment: string[] = JSON.parse(profile.equipment);
        const cycleType = profile.workoutCycle;
        const daysPerWeek = profile.weeklyWorkoutDays;

        const template = CYCLE_TEMPLATES[cycleType];
        // Limit days to daysPerWeek workout days
        const workDays = template.days.filter(d => !d.isRest).slice(0, daysPerWeek);
        const uniqueDayLabels = [...new Set(workDays.map(d => d.label))];

        const equipmentDisplay = equipment.map(e => e.replace('_', ' ')).join(', ');
        const preferSupersets = profile.preferSupersets === true;

        const supersetNote = preferSupersets
            ? `
- SUPERSETS: Pair compatible exercises as supersets (antagonist pairs like chest/back, or compound+isolation for same muscle). Paired exercises get a "supersetGroupId" (integer starting from 1) and "supersetOrder" (0 = first in pair, 1 = second). Standalone exercises get supersetGroupId: null. Example pair: Bench Press (supersetGroupId: 1, supersetOrder: 0) + DB Flyes (supersetGroupId: 1, supersetOrder: 1).`
            : '';


        const systemPrompt = `You are an elite personal trainer and strength coach. Generate a detailed, periodized workout plan.

STRICT RULES:
- ONLY use these available equipment: ${equipmentDisplay}
- Split type: ${cycleType.replace('_', ' ').toUpperCase()}
- Generate exercises for these distinct workout days: ${uniqueDayLabels.join(', ')}
- 5-7 exercises per workout day
- Include sets, reps (or time), rest periods, and the primary muscle group for EACH exercise
- Be specific: use proper exercise names (e.g., "Romanian Deadlift", "Incline Dumbbell Press", "Cable Lateral Raise")
- Vary rep ranges: include heavy compound (4-6 reps), moderate (8-12 reps), and higher rep (15-20 reps) work
- Rest times: heavy compounds = 120-180s, moderate = 60-90s, isolation = 45-60s
- For Cable Machine exercises, only include them if "cable" appears in the equipment list${supersetNote}`;

        const { object: planData } = await generateObject({
            model: google('gemini-3.1-flash-lite-preview'),
            schema: WorkoutPlanSchema,
            system: systemPrompt,
            prompt: `Generate the workout plan. Available equipment: ${equipmentDisplay}. Split: ${cycleType}. Workout days needed: ${uniqueDayLabels.join(', ')}.`,
            maxOutputTokens: 6000,
        });

        // Deactivate all existing workout plans
        await db.update(workoutPlans).set({ isActive: false }).where(eq(workoutPlans.userId, userId));

        // Insert plan
        const [insertedPlan] = await db.insert(workoutPlans).values({
            userId,
            title: planData.title ?? `${cycleType.toUpperCase()} Plan`,
            cycleType: cycleType as any,
            daysPerWeek,
            equipment: JSON.stringify(equipment),
            isActive: true,
        }).returning();

        // Build the full 7-day structure using the template
        const aiDayMap: Record<string, any[]> = {};
        for (const aiDay of planData.days ?? []) {
            aiDayMap[aiDay.dayLabel] = aiDay.exercises ?? [];
        }

        for (let i = 0; i < template.days.length; i++) {
            const templateDay = template.days[i];
            const [insertedDay] = await db.insert(workoutDays).values({
                planId: insertedPlan.id,
                dayNumber: i + 1,
                dayLabel: templateDay.label,
                isRestDay: templateDay.isRest,
            }).returning();

            if (!templateDay.isRest) {
                const exercises = aiDayMap[templateDay.label] ?? [];
                for (const ex of exercises) {
                    await db.insert(workoutExercises).values({
                        dayId: insertedDay.id,
                        orderIndex: ex.orderIndex ?? 1,
                        name: ex.name ?? 'Exercise',
                        sets: ex.sets ?? 3,
                        repsOrTime: String(ex.repsOrTime ?? ex.reps ?? '10-12'),
                        restSeconds: ex.restSeconds ?? ex.rest_seconds ?? 60,
                        muscleGroup: ex.muscleGroup ?? ex.muscle_group ?? '',
                        equipment: ex.equipment ?? '',
                        notes: ex.notes ?? '',
                        supersetGroupId: ex.supersetGroupId ?? null,
                        supersetOrder: ex.supersetOrder ?? null,
                    });
                }
            }
        }

        return c.json({ success: true, data: { planId: insertedPlan.id } });
    } catch (err) {
        console.error('[workout/generate]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/workout/plans/:id ──────────────────────────────────────────────
router.put('/plans/:id', zValidator('json', z.object({
    title: z.string().optional(),
    isActive: z.boolean().optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(workoutPlans).set(body).where(and(eq(workoutPlans.userId, userId), eq(workoutPlans.id, id))).returning();
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/workout/exercises/:id ─────────────────────────────────────────
router.put('/exercises/:id', zValidator('json', z.object({
    name: z.string().optional(),
    sets: z.number().int().optional(),
    repsOrTime: z.string().optional(),
    restSeconds: z.number().int().optional(),
    muscleGroup: z.string().optional(),
    notes: z.string().optional(),
})), async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(workoutExercises).set(body).where(eq(workoutExercises.id, id)).returning();
        if (updated.length === 0) return c.json({ success: false, error: 'Exercise not found' }, 404);
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

const replaceExerciseSchema = z.object({
    planId: z.number().int().positive(),
    dayId: z.number().int().positive(),
    dayLabel: z.string().min(1),
    muscleGroup: z.string().optional(),
    currentExerciseIds: z.array(z.number().int().positive()).min(1),
    currentExerciseNames: z.array(z.string().min(1)).min(1),
});

// ─── POST /api/workout/exercises/:id/replace ───────────────────────────────
router.post('/exercises/:id/replace', zValidator('json', replaceExerciseSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const exerciseId = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const [target] = await db.select().from(workoutExercises).where(eq(workoutExercises.id, exerciseId)).limit(1);
        if (!target) return c.json({ success: false, error: 'Exercise not found' }, 404);
        if (target.dayId !== body.dayId) {
            return c.json({ success: false, error: 'Exercise does not belong to selected day' }, 400);
        }

        const [profile] = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
        const equipmentList = profile ? safeParseArray(profile.equipment).map((item) => String(item)) : [];
        const equipmentDisplay = equipmentList.length > 0
            ? equipmentList.join(', ')
            : 'dumbbells, bodyweight';

        const existingNames = new Set(
            body.currentExerciseNames.map((name) => normalizeExerciseName(name)),
        );

        const prompt = `Generate exactly one replacement exercise.

Context:
- Day label: ${body.dayLabel}
- Target muscle group: ${body.muscleGroup || target.muscleGroup || 'same as current'}
- Equipment available: ${equipmentDisplay}
- Existing exercises to avoid: ${body.currentExerciseNames.join(', ')}

Rules:
- Keep it distinct from all existing exercises
- Keep training intent similar to the current exercise: ${target.name}`;

        let candidate: {
            name: string;
            sets: number;
            repsOrTime: string;
            restSeconds: number;
            muscleGroup: string;
            equipment: string;
            notes: string;
        } | null = null;

        try {
            const { object } = await generateObject({
                model: google('gemini-3.1-flash-lite-preview'),
                schema: ExerciseReplacementResultSchema,
                prompt,
                maxOutputTokens: 500,
            });
            if (object.name.trim().length > 1 && !existingNames.has(normalizeExerciseName(object.name))) {
                candidate = {
                    name: object.name.trim(),
                    sets: Math.max(1, object.sets || target.sets || 3),
                    repsOrTime: object.repsOrTime || String(target.repsOrTime ?? '10-12'),
                    restSeconds: Math.max(20, object.restSeconds || target.restSeconds || 60),
                    muscleGroup: object.muscleGroup || body.muscleGroup || target.muscleGroup || '',
                    equipment: object.equipment || target.equipment || '',
                    notes: object.notes || target.notes || '',
                };
            }
        } catch {
            candidate = null;
        }

        if (!candidate) {
            const normalizedMuscle = normalizeExerciseName(
                body.muscleGroup || target.muscleGroup || 'core',
            );
            const fallbackGroup = fallbackExercisePool[normalizedMuscle] ?? fallbackExercisePool.core;
            const fallback = fallbackGroup.find((item) => !existingNames.has(normalizeExerciseName(item.name)));
            if (!fallback) {
                return c.json({
                    success: false,
                    error: 'No unique replacement available. Try again with different constraints.',
                }, 409);
            }
            candidate = {
                name: fallback.name,
                sets: fallback.sets,
                repsOrTime: fallback.repsOrTime,
                restSeconds: fallback.restSeconds,
                muscleGroup: body.muscleGroup || target.muscleGroup || normalizedMuscle,
                equipment: fallback.equipment,
                notes: fallback.notes,
            };
        }

        const [updated] = await db.update(workoutExercises).set({
            name: candidate.name,
            sets: candidate.sets,
            repsOrTime: candidate.repsOrTime,
            restSeconds: candidate.restSeconds,
            muscleGroup: candidate.muscleGroup,
            equipment: candidate.equipment,
            notes: candidate.notes,
        }).where(eq(workoutExercises.id, exerciseId)).returning();

        return c.json({
            success: true,
            data: {
                ...updated,
                replacementContext: {
                    dayId: body.dayId,
                    dayLabel: body.dayLabel,
                    requestedMuscleGroup: body.muscleGroup ?? target.muscleGroup ?? '',
                },
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── DELETE /api/workout/exercises/:id ──────────────────────────────────────
router.delete('/exercises/:id', async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const deleted = await db.delete(workoutExercises).where(eq(workoutExercises.id, id)).returning();
        if (deleted.length === 0) return c.json({ success: false, error: 'Exercise not found' }, 404);
        return c.json({ success: true, data: deleted[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/sessions/history ──────────────────────────────────────
router.get('/sessions/history', async (c) => {
    try {
        const userId = c.var.userId;
        const range = (c.req.query('range') ?? '30d').toLowerCase();
        const now = new Date();
        const rangeDays = range === '90d' ? 90 : range === 'all' ? 3650 : 30;
        const start = new Date(now);
        start.setDate(now.getDate() - rangeDays + 1);
        start.setHours(0, 0, 0, 0);

        const sessions = await db.select().from(workoutSessions)
            .where(and(
                eq(workoutSessions.userId, userId),
                gte(workoutSessions.startedAt, start.toISOString()),
                sql`${workoutSessions.completedAt} IS NOT NULL`,
            ))
            .orderBy(desc(workoutSessions.startedAt))
            .limit(range === 'all' ? 500 : 200);

        const dayIds = [...new Set(sessions.map((session) => session.dayId))];
        const dayRows = dayIds.length > 0
            ? await db.select().from(workoutDays).where(inArray(workoutDays.id, dayIds))
            : [];
        const dayMap = new Map(dayRows.map((day) => [day.id, day]));

        const exercisesByDay = new Map<number, WorkoutExerciseRow[]>();
        if (dayIds.length > 0) {
            const exerciseRows = await db.select().from(workoutExercises)
                .where(inArray(workoutExercises.dayId, dayIds))
                .orderBy(workoutExercises.orderIndex);
            for (const row of exerciseRows) {
                const list = exercisesByDay.get(row.dayId) ?? [];
                list.push(row);
                exercisesByDay.set(row.dayId, list);
            }
        }

        const dailyBuckets = new Map<string, { volume: number; duration: number; sessions: number }>();
        const sessionItems = sessions.map((session) => {
            const day = dayMap.get(session.dayId);
            const date = (session.completedAt ?? session.startedAt ?? new Date().toISOString()).slice(0, 10);
            const duration = session.totalDurationSeconds ?? estimateDayDurationSeconds(exercisesByDay.get(session.dayId) ?? []);
            const volume = estimateSessionVolume(session, exercisesByDay.get(session.dayId) ?? []);
            const bucket = dailyBuckets.get(date) ?? { volume: 0, duration: 0, sessions: 0 };
            bucket.volume += volume;
            bucket.duration += duration;
            bucket.sessions += 1;
            dailyBuckets.set(date, bucket);
            return {
                id: session.id,
                date,
                startedAt: session.startedAt,
                completedAt: session.completedAt,
                dayLabel: day?.dayLabel ?? 'Workout',
                totalDurationSeconds: duration,
                totalVolume: volume,
                completedExercises: session.completedExercises,
                totalExercises: session.totalExercises,
                xpEarned: session.xpEarned,
            };
        });

        const sortedDates = [...dailyBuckets.keys()].sort();
        const volumeSeries = sortedDates.map((date) => ({
            date,
            value: dailyBuckets.get(date)?.volume ?? 0,
        }));
        const durationSeries = sortedDates.map((date) => ({
            date,
            value: dailyBuckets.get(date)?.duration ?? 0,
        }));
        const consistencySeries = sortedDates.map((date) => ({
            date,
            value: dailyBuckets.get(date)?.sessions ?? 0,
        }));

        const totalSessions = sessionItems.length;
        const totalDurationSeconds = sessionItems.reduce((sum, item) => sum + item.totalDurationSeconds, 0);
        const totalVolume = sessionItems.reduce((sum, item) => sum + item.totalVolume, 0);
        const avgDurationSeconds = totalSessions > 0 ? Math.round(totalDurationSeconds / totalSessions) : 0;
        const consistencyScore = rangeDays > 0 ? Math.min(totalSessions / rangeDays, 1) : 0;

        return c.json({
            success: true,
            data: {
                range,
                sessions: sessionItems,
                summary: {
                    totalSessions,
                    totalDurationSeconds,
                    avgDurationSeconds,
                    totalVolume,
                    consistencyScore,
                },
                series: {
                    volume: volumeSeries,
                    duration: durationSeries,
                    consistency: consistencySeries,
                },
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/workout/sessions ──────────────────────────────────────────────
router.post('/sessions', zValidator('json', z.object({
    planId: z.number().int(),
    dayId: z.number().int(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const { planId, dayId, date } = c.req.valid('json');
        const targetDate = date ?? new Date().toISOString().slice(0, 10);

        const [existing] = await db.select().from(workoutSessions)
            .where(and(
                eq(workoutSessions.userId, userId),
                eq(workoutSessions.planId, planId),
                eq(workoutSessions.dayId, dayId),
                sql`date(${workoutSessions.startedAt}) = ${targetDate}`,
            ))
            .orderBy(desc(workoutSessions.id))
            .limit(1);

        if (existing) {
            return c.json({
                success: true,
                data: {
                    ...sessionWithParsedPayload(existing),
                    status: existing.completedAt ? 'completed' : 'in_progress',
                },
            });
        }

        const [session] = await db.insert(workoutSessions).values({ userId, planId, dayId }).returning();
        return c.json({
            success: true,
            data: {
                ...sessionWithParsedPayload(session),
                status: 'new',
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/sessions/today ────────────────────────────────────────
router.get('/sessions/today', async (c) => {
    try {
        const userId = c.var.userId;
        const planId = Number(c.req.query('planId'));
        const dayId = Number(c.req.query('dayId'));
        const date = c.req.query('date') ?? new Date().toISOString().slice(0, 10);

        if (!Number.isInteger(planId) || !Number.isInteger(dayId)) {
            return c.json({ success: false, error: 'planId and dayId are required integers' }, 400);
        }
        if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) {
            return c.json({ success: false, error: 'date must be YYYY-MM-DD' }, 400);
        }

        const [session] = await db.select().from(workoutSessions)
            .where(and(
                eq(workoutSessions.userId, userId),
                eq(workoutSessions.planId, planId),
                eq(workoutSessions.dayId, dayId),
                sql`date(${workoutSessions.startedAt}) = ${date}`,
            ))
            .orderBy(desc(workoutSessions.id))
            .limit(1);

        if (!session) {
            return c.json({
                success: true,
                data: {
                    status: 'none',
                    session: null,
                },
            });
        }

        return c.json({
            success: true,
            data: {
                status: session.completedAt ? 'completed' : 'in_progress',
                session: sessionWithParsedPayload(session),
            },
        });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/sessions/:id ───────────────────────────────────────────
router.get('/sessions/:id', async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const [session] = await db.select().from(workoutSessions).where(and(eq(workoutSessions.userId, userId), eq(workoutSessions.id, id))).limit(1);
        if (!session) return c.json({ success: false, error: 'Session not found' }, 404);

        return c.json({ success: true, data: sessionWithParsedPayload(session) });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/workout/sessions/:id ──────────────────────────────────────────
router.put('/sessions/:id', zValidator('json', z.object({
    completedAt: z.string().optional(),
    totalDurationSeconds: z.number().int().optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(workoutSessions).set(body).where(and(eq(workoutSessions.userId, userId), eq(workoutSessions.id, id))).returning();
        return c.json({ success: true, data: updated[0] });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/workout/sessions/:id/log ───────────────────────────────────────
router.put('/sessions/:id/log', zValidator('json', z.object({
    pausedDurationSeconds: z.number().int().min(0).optional(),
    warmupData: z.record(z.string(), z.any()).optional(),
    cooldownData: z.record(z.string(), z.any()).optional(),
    setLogs: z.array(z.record(z.string(), z.any())).optional(),
    sessionNotes: z.array(z.record(z.string(), z.any())).optional(),
    hrSnapshots: z.array(z.record(z.string(), z.any())).optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const [existing] = await db.select().from(workoutSessions).where(and(
            eq(workoutSessions.userId, userId),
            eq(workoutSessions.id, id),
            isNull(workoutSessions.completedAt),
        )).limit(1);
        if (!existing) return c.json({ success: false, error: 'Session not found' }, 404);

        const updatePayload: Record<string, unknown> = {};
        if (body.pausedDurationSeconds !== undefined) updatePayload.pausedDurationSeconds = body.pausedDurationSeconds;
        if (body.warmupData !== undefined) updatePayload.warmupData = JSON.stringify(body.warmupData);
        if (body.cooldownData !== undefined) updatePayload.cooldownData = JSON.stringify(body.cooldownData);
        if (body.setLogs !== undefined) updatePayload.setLogs = JSON.stringify(body.setLogs);
        if (body.sessionNotes !== undefined) updatePayload.sessionNotes = JSON.stringify(body.sessionNotes);
        if (body.hrSnapshots !== undefined) updatePayload.hrSnapshots = JSON.stringify(body.hrSnapshots);

        const [updated] = await db.update(workoutSessions).set(updatePayload).where(eq(workoutSessions.id, id)).returning();

        return c.json({ success: true, data: sessionWithParsedPayload(updated) });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── PUT /api/workout/sessions/:id/complete ──────────────────────────────────
router.put('/sessions/:id/complete', zValidator('json', z.object({
    totalDurationSeconds: z.number().int(),
    totalExercises: z.number().int(),
    completedExercises: z.number().int(),
    totalRests: z.number().int(),
    skippedRests: z.number().int(),
    completedSets: z.number().int(),
    pausedDurationSeconds: z.number().int().min(0).optional(),
    warmupData: z.record(z.string(), z.any()).optional(),
    cooldownData: z.record(z.string(), z.any()).optional(),
    setLogs: z.array(z.record(z.string(), z.any())).optional(),
    sessionNotes: z.array(z.record(z.string(), z.any())).optional(),
    hrSnapshots: z.array(z.record(z.string(), z.any())).optional(),
    dayLabel: z.string().optional(),
})), async (c) => {
    try {
        const userId = c.var.userId;
        const sessionId = parseInt(c.req.param('id'));
        const body = c.req.valid('json');

        // Ensure user_progress row exists
        await ensureUserProgress(userId);
        const [prog] = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);

        const today = new Date().toISOString().slice(0, 10);

        // Calculate streak
        let newStreak = prog.currentStreak;
        const streakResult = calculateNewStreak(prog.lastWorkoutDate, today);
        if (streakResult === 999) {
            newStreak = prog.currentStreak + 1;
        } else if (streakResult === 0) {
            newStreak = prog.currentStreak; // same day, no change
        } else {
            newStreak = 1; // broken or first
        }

        // Calculate XP
        const breakdown = calculateXp({
            completedSets: body.completedSets,
            totalRests: body.totalRests,
            skippedRests: body.skippedRests,
            totalExercises: body.totalExercises,
            completedExercises: body.completedExercises,
            durationSeconds: body.totalDurationSeconds,
            currentStreak: prog.currentStreak,
        });

        const newTotalXp = prog.totalXp + breakdown.total;
        const newWorkoutsCompleted = prog.totalWorkoutsCompleted + 1;
        const previousLevel = getLevel(prog.totalXp);


        // Collect this week's day labels for full_ppl achievement check
        const weekLabels: string[] = [];
        if (body.dayLabel) weekLabels.push(body.dayLabel);

        // Check existing achievements
        const existingUnlocks = await db.select({ achievementId: userAchievements.achievementId }).from(userAchievements).where(eq(userAchievements.userId, userId));
        const allAchievements = await db.select().from(achievements);
        const unlockedSlugs = new Set(
            existingUnlocks.map(u => allAchievements.find(a => a.id === u.achievementId)?.slug).filter(Boolean) as string[]
        );

        const session = await db.select().from(workoutSessions).where(eq(workoutSessions.id, sessionId)).limit(1);
        const startedAt = session[0]?.startedAt ?? new Date().toISOString();

        const earnedSlugs = checkAchievements({
            totalWorkoutsCompleted: newWorkoutsCompleted,
            currentStreak: newStreak,
            completedExercises: body.completedExercises,
            totalExercises: body.totalExercises,
            skippedRests: body.skippedRests,
            totalRests: body.totalRests,
            durationSeconds: body.totalDurationSeconds,
            startedAt,
            dayLabels: weekLabels,
            unlockedSlugs,
        });

        // Get achievement objects and their XP
        const earnedAchievementRows = earnedSlugs.length > 0
            ? allAchievements.filter(a => earnedSlugs.includes(a.slug))
            : [];
        const achievementXp = earnedAchievementRows.reduce((sum, a) => sum + a.xpReward, 0);
        const finalTotalXp = newTotalXp + achievementXp;
        const finalLevel = getLevel(finalTotalXp);

        // Persist session completion
        await db.update(workoutSessions).set({
            completedAt: new Date().toISOString(),
            totalDurationSeconds: body.totalDurationSeconds,
            totalExercises: body.totalExercises,
            completedExercises: body.completedExercises,
            totalRests: body.totalRests,
            skippedRests: body.skippedRests,
            pausedDurationSeconds: body.pausedDurationSeconds ?? 0,
            warmupData: JSON.stringify(body.warmupData ?? {}),
            cooldownData: JSON.stringify(body.cooldownData ?? {}),
            setLogs: JSON.stringify(body.setLogs ?? []),
            sessionNotes: JSON.stringify(body.sessionNotes ?? []),
            hrSnapshots: JSON.stringify(body.hrSnapshots ?? []),
            xpEarned: breakdown.total,
        }).where(eq(workoutSessions.id, sessionId));

        // Persist achievements
        for (const a of earnedAchievementRows) {
            await db.insert(userAchievements).values({
                userId,
                achievementId: a.id,
                sessionId,
            });
        }

        // Persist user progress
        await db.update(userProgress).set({
            totalXp: finalTotalXp,
            currentLevel: finalLevel,
            currentStreak: newStreak,
            longestStreak: Math.max(prog.longestStreak, newStreak),
            lastWorkoutDate: today,
            totalWorkoutsCompleted: newWorkoutsCompleted,
            updatedAt: new Date().toISOString(),
        }).where(eq(userProgress.userId, userId));

        // ── PR tracking ───────────────────────────────────────────────────────
        const newPrs: typeof personalRecords.$inferSelect[] = [];
        try {
            const completedSession = session[0];
            if (completedSession) {
                const dayExercises = await db.select().from(workoutExercises)
                    .where(eq(workoutExercises.dayId, completedSession.dayId))
                    .orderBy(workoutExercises.orderIndex);

                const setLogs = body.setLogs ?? [];
                const achievedAt = new Date().toISOString();

                for (const log of setLogs) {
                    if (!log || typeof log !== 'object') continue;
                    const status = String(log.status ?? '');
                    if (status !== 'completed') continue;
                    const weightKg = Number(log.weightKg);
                    if (!Number.isFinite(weightKg) || weightKg <= 0) continue;

                    const exerciseName = String(log.exerciseName ?? '');
                    if (!exerciseName) continue;
                    const normalized = normalizeExerciseName(exerciseName);

                    const exerciseIndex = Number(log.exerciseIndex ?? -1);
                    const dayEx = dayExercises[exerciseIndex];
                    const repsOrTime = dayEx?.repsOrTime ?? '10-12';
                    const reps = parseRepsLowerBound(repsOrTime);
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
                            sessionId,
                        }).onConflictDoUpdate({
                            target: [personalRecords.userId, personalRecords.exerciseNameNormalized],
                            set: { weightKg, reps, achievedAt, sessionId, exerciseNameDisplay: exerciseName },
                        }).returning();
                        if (upserted && (!existing || weightKg > existing.weightKg)) {
                            newPrs.push(upserted);
                        }
                    }
                }
            }
        } catch (prErr) {
            console.error('[sessions/complete] PR tracking error:', prErr);
        }

        return c.json({
            success: true,
            data: {
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
            },
        });
    } catch (err) {
        console.error('[sessions/complete]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/workout/days/:dayId/exercises ─────────────────────────────────
router.post('/days/:dayId/exercises', async (c) => {
    try {
        const dayId = parseInt(c.req.param('dayId'));
        const body = await c.req.json();
        const name = String(body.name ?? '').trim();
        if (!name) return c.json({ success: false, error: 'name is required' }, 400);

        const existing = await db.select().from(workoutExercises)
            .where(eq(workoutExercises.dayId, dayId))
            .orderBy(desc(workoutExercises.orderIndex))
            .limit(1);
        const nextOrder = existing.length > 0 ? (existing[0].orderIndex + 1) : 1;

        const [inserted] = await db.insert(workoutExercises).values({
            dayId,
            orderIndex: nextOrder,
            name,
            sets: Number(body.sets) || 3,
            repsOrTime: String(body.repsOrTime ?? '10-12'),
            restSeconds: Number(body.restSeconds) || 60,
            muscleGroup: String(body.muscleGroup ?? ''),
            equipment: String(body.equipment ?? ''),
            notes: String(body.notes ?? ''),
        }).returning();

        return c.json({ success: true, data: inserted });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── POST /api/workout/regenerate ────────────────────────────────────────────
router.post('/regenerate', async (c) => {
    try {
        const userId = c.var.userId;
        const body = await c.req.json();
        const planId = Number(body.planId);
        const constraints = String(body.constraints ?? '').trim();

        if (!planId) return c.json({ success: false, error: 'planId is required' }, 400);

        const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
        if (profiles.length === 0) return c.json({ success: false, error: 'Profile not found' }, 400);
        const profile = profiles[0];

        const equipment: string[] = JSON.parse(profile.equipment);
        const cycleType = profile.workoutCycle;
        const daysPerWeek = profile.weeklyWorkoutDays;

        const template = CYCLE_TEMPLATES[cycleType];
        const workDays = template.days.filter(d => !d.isRest).slice(0, daysPerWeek);
        const uniqueDayLabels = [...new Set(workDays.map(d => d.label))];
        const equipmentDisplay = equipment.map(e => e.replace('_', ' ')).join(', ');

        const constraintNote = constraints
            ? `\n\nUSER CONSTRAINTS: ${constraints}\nAvoid or modify exercises that conflict with these constraints.`
            : '';

        const systemPrompt = `You are an elite personal trainer. Generate a detailed workout plan.

STRICT RULES:
- ONLY use these available equipment: ${equipmentDisplay}
- Split type: ${cycleType.replace('_', ' ').toUpperCase()}
- Generate exercises for these distinct workout days: ${uniqueDayLabels.join(', ')}
- 5-7 exercises per workout day
- Include sets, reps (or time), rest periods, and the primary muscle group for EACH exercise
- Vary rep ranges: include heavy compound (4-6 reps), moderate (8-12 reps), and higher rep (15-20 reps) work
- Rest times: heavy compounds = 120-180s, moderate = 60-90s, isolation = 45-60s${constraintNote}`;

        const { object: planData } = await generateObject({
            model: google('gemini-3.1-flash-lite-preview'),
            schema: WorkoutPlanSchema,
            system: systemPrompt,
            prompt: `Regenerate the workout plan. Equipment: ${equipmentDisplay}. Split: ${cycleType}. Days: ${uniqueDayLabels.join(', ')}.${constraints ? ` User constraints: ${constraints}` : ''}`,
            maxOutputTokens: 6000,
        });

        // Deactivate existing plans
        await db.update(workoutPlans).set({ isActive: false }).where(eq(workoutPlans.userId, userId));

        const [insertedPlan] = await db.insert(workoutPlans).values({
            userId,
            title: planData.title ?? `${cycleType.toUpperCase()} Plan (Updated)`,
            cycleType: cycleType as any,
            daysPerWeek,
            equipment: JSON.stringify(equipment),
            isActive: true,
        }).returning();

        const aiDayMap: Record<string, any[]> = {};
        for (const aiDay of planData.days ?? []) {
            aiDayMap[aiDay.dayLabel] = aiDay.exercises ?? [];
        }

        for (let i = 0; i < template.days.length; i++) {
            const templateDay = template.days[i];
            const [insertedDay] = await db.insert(workoutDays).values({
                planId: insertedPlan.id,
                dayNumber: i + 1,
                dayLabel: templateDay.label,
                isRestDay: templateDay.isRest,
            }).returning();

            if (!templateDay.isRest) {
                const exercises = aiDayMap[templateDay.label] ?? [];
                for (const ex of exercises) {
                    await db.insert(workoutExercises).values({
                        dayId: insertedDay.id,
                        orderIndex: ex.orderIndex ?? 1,
                        name: ex.name ?? 'Exercise',
                        sets: ex.sets ?? 3,
                        repsOrTime: String(ex.repsOrTime ?? '10-12'),
                        restSeconds: ex.restSeconds ?? 60,
                        muscleGroup: ex.muscleGroup ?? '',
                        equipment: ex.equipment ?? '',
                        notes: ex.notes ?? '',
                    });
                }
            }
        }

        return c.json({ success: true, data: { planId: insertedPlan.id } });
    } catch (err) {
        console.error('[workout/regenerate]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

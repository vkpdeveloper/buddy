import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { and, desc, eq, gte, isNull, lt, sql } from 'drizzle-orm';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateText } from 'ai';
import { env } from '../lib/env';
import { db } from '../db';
import { userProfile, workoutPlans, workoutDays, workoutExercises, workoutSessions, userProgress, achievements, userAchievements } from '../db/schema';
import { calculateXp, calculateNewStreak, checkAchievements, getLevel, getLevelLabel } from '../lib/xp';
import { ensureUserProgress } from './progress';

const router = new Hono();
const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

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
        const plans = await db.select().from(workoutPlans).orderBy(workoutPlans.createdAt);
        return c.json({ success: true, data: plans });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/plans/:id ──────────────────────────────────────────────
router.get('/plans/:id', async (c) => {
    try {
        const id = parseInt(c.req.param('id'));
        const [plan] = await db.select().from(workoutPlans).where(eq(workoutPlans.id, id));
        if (!plan) return c.json({ success: false, error: 'Plan not found' }, 404);

        const days = await db.select().from(workoutDays)
            .where(eq(workoutDays.planId, id))
            .orderBy(workoutDays.dayNumber);

        const daysWithExercises = await Promise.all(days.map(async (day) => {
            if (day.isRestDay) return { ...day, exercises: [] };
            const exercises = await db.select().from(workoutExercises)
                .where(eq(workoutExercises.dayId, day.id))
                .orderBy(workoutExercises.orderIndex);
            return { ...day, exercises };
        }));

        return c.json({ success: true, data: { ...plan, days: daysWithExercises } });
    } catch (err) {
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// ─── GET /api/workout/summary/weekly ────────────────────────────────────────
router.get('/summary/weekly', async (c) => {
    try {
        const now = new Date();
        const day = now.getDay(); // 0..6 (Sun..Sat)
        const diffToMonday = day === 0 ? -6 : 1 - day;
        const start = new Date(now);
        start.setDate(now.getDate() + diffToMonday);
        start.setHours(0, 0, 0, 0);
        const end = new Date(start);
        end.setDate(start.getDate() + 7);

        const [activePlan] = await db.select().from(workoutPlans).where(eq(workoutPlans.isActive, true)).limit(1);
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
        const profiles = await db.select().from(userProfile).limit(1);
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
- For Cable Machine exercises, only include them if "cable" appears in the equipment list

Return ONLY valid JSON in this EXACT format (no markdown):
{
  "title": "PPL Hypertrophy Program",
  "days": [
    {
      "dayLabel": "Push",
      "exercises": [
        {
          "orderIndex": 1,
          "name": "Barbell Bench Press",
          "sets": 4,
          "repsOrTime": "6-8",
          "restSeconds": 150,
          "muscleGroup": "Chest",
          "equipment": "Barbell",
          "notes": "Control the descent for 2-3 seconds"
        }
      ]
    }
  ]
}`;

        const { text } = await generateText({
            model: google('gemini-3.1-flash-lite-preview'),
            system: systemPrompt,
            prompt: `Generate the workout plan. Available equipment: ${equipmentDisplay}. Split: ${cycleType}. Workout days needed: ${uniqueDayLabels.join(', ')}.`,
            maxOutputTokens: 6000,
        });

        let planData: any;
        try {
            const jsonMatch = text.match(/\{[\s\S]*\}/);
            if (!jsonMatch) throw new Error('No JSON found');
            planData = JSON.parse(jsonMatch[0]);
        } catch (parseErr) {
            console.error('Failed to parse workout AI response:', text.substring(0, 500));
            return c.json({ success: false, error: 'AI returned invalid JSON. Please try again.' }, 500);
        }

        // Deactivate all existing workout plans
        await db.update(workoutPlans).set({ isActive: false });

        // Insert plan
        const [insertedPlan] = await db.insert(workoutPlans).values({
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
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(workoutPlans).set(body).where(eq(workoutPlans.id, id)).returning();
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

// ─── POST /api/workout/sessions ──────────────────────────────────────────────
router.post('/sessions', zValidator('json', z.object({
    planId: z.number().int(),
    dayId: z.number().int(),
    date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
})), async (c) => {
    try {
        const { planId, dayId, date } = c.req.valid('json');
        const targetDate = date ?? new Date().toISOString().slice(0, 10);

        const [existing] = await db.select().from(workoutSessions)
            .where(and(
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

        const [session] = await db.insert(workoutSessions).values({ planId, dayId }).returning();
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
        const id = parseInt(c.req.param('id'));
        const [session] = await db.select().from(workoutSessions).where(eq(workoutSessions.id, id)).limit(1);
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
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const updated = await db.update(workoutSessions).set(body).where(eq(workoutSessions.id, id)).returning();
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
        const id = parseInt(c.req.param('id'));
        const body = c.req.valid('json');
        const [existing] = await db.select().from(workoutSessions).where(and(
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
        const sessionId = parseInt(c.req.param('id'));
        const body = c.req.valid('json');

        // Ensure user_progress row exists
        await ensureUserProgress();
        const [prog] = await db.select().from(userProgress).limit(1);

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
        const existingUnlocks = await db.select({ achievementId: userAchievements.achievementId }).from(userAchievements);
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
        });

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
            },
        });
    } catch (err) {
        console.error('[sessions/complete]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

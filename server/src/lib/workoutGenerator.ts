import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateObject } from 'ai';
import { eq } from 'drizzle-orm';
import { env } from './env';
import { z } from 'zod';
import { db } from '../db';
import { userProfile, workoutPlans, workoutDays, workoutExercises } from '../db/schema';
import { deriveBodyFatRange, type BodyShape, type ExperienceLevel } from './macros';
import { trackAiUsage, AI_FEATURE } from './aiUsageTracker';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const WorkoutPlanSchema = z.object({
    title: z.string().describe('Name of the workout program (e.g. "PPL Hypertrophy Program")'),
    days: z.array(z.object({
        dayLabel: z.string().describe('Workout day label matching one of the requested day types (e.g. Push, Pull, Legs, Upper, Lower, Full Body)'),
        exercises: z.array(z.object({
            orderIndex: z.number().int().describe('Exercise order within the day, starting from 1'),
            name: z.string().describe('Full proper exercise name (e.g. "Romanian Deadlift", "Incline Dumbbell Press")'),
            sets: z.number().int().describe('Number of sets to perform'),
            repsOrTime: z.string().describe('Rep range or time duration (e.g. "6-8", "8-12", "30s", "2min")'),
            restSeconds: z.number().int().describe('Rest time in seconds between sets (e.g. 60, 90, 120, 150, 180)'),
            muscleGroup: z.string().describe('Primary muscle group targeted (e.g. Chest, Back, Quads, Shoulders, Biceps)'),
            equipment: z.string().describe('Equipment required for this exercise (e.g. Barbell, Dumbbell, Cable, Bodyweight)'),
            notes: z.string().describe('Coaching cues or form tips for the exercise'),
        })).describe('5 to 7 exercises for this workout day'),
    })).describe('Array of workout days. Generate one entry for each distinct day label requested in the prompt.'),
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

export async function runWorkoutGeneration(
    userId: number,
    options?: { onProgress?: (stageKey: string) => Promise<void> | void },
): Promise<{ planId: number }> {
    await options?.onProgress?.('reading_profile');
    const profiles = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
    if (profiles.length === 0) throw new Error('Profile not found');
    const profile = profiles[0];

    const equipment: string[] = profile.equipment;
    const cycleType = profile.workoutCycle;
    const daysPerWeek = profile.weeklyWorkoutDays;
    const experienceLevel = (profile.experienceLevel ?? 'beginner') as ExperienceLevel;
    const currentBodyShape = profile.currentBodyShape as BodyShape | null | undefined;
    const goalBodyShape = profile.goalBodyShape as BodyShape | null | undefined;
    const sex = profile.sex as 'male' | 'female';

    const template = CYCLE_TEMPLATES[cycleType];
    const workDays = template.days.filter(d => !d.isRest).slice(0, daysPerWeek);
    const uniqueDayLabels = [...new Set(workDays.map(d => d.label))];
    const equipmentDisplay = equipment.map(e => e.replace('_', ' ')).join(', ');
    await options?.onProgress?.('matching_equipment');

    const EXPERIENCE_CONTEXT: Record<ExperienceLevel, string> = {
        beginner: 'BEGINNER (0–1 year of training): Prioritise form and neural adaptation. Use foundational compound movements. Keep all rep ranges moderate (8–12). 3 sets per exercise maximum. Avoid complex or highly technical exercises — build the habit and movement patterns first.',
        intermediate: 'INTERMEDIATE (1–3 years of training): Progressive overload is the main driver. Mix heavy compound lifts (6–8 reps) with moderate isolation work (10–12 reps). 3–4 sets per exercise. Introduce more exercise variety and periodisation.',
        advanced: 'ADVANCED (3+ years of training): High volume and intensity. Include full periodisation — heavy sets (4–6 reps), moderate hypertrophy sets (8–12 reps), and high-rep pump sets (15–20 reps). 4–5 sets on key lifts. Complex movement patterns, supersets (if preferred), and near-failure intensity expected.',
    };

    let physiqueSection = '';
    if (currentBodyShape && goalBodyShape) {
        const currentBf = deriveBodyFatRange(currentBodyShape, sex);
        const goalBf = deriveBodyFatRange(goalBodyShape, sex);
        const emphasisMap: Record<BodyShape, string> = {
            skinny: 'Muscle building from scratch — foundational compound movements, progressive overload, sustainable volume to build mass',
            lean: 'Maintain and improve body composition — balance resistance training with metabolic conditioning',
            fat: 'General fitness and habit building — compound movements, moderate intensity, sustainable volume',
        };
        physiqueSection = `
PHYSIQUE TRANSFORMATION CONTEXT:
- Current physique: ${currentBodyShape} (~${currentBf.min}–${currentBf.max}% body fat for ${sex})
- Target physique: ${goalBodyShape} (~${goalBf.min}–${goalBf.max}% body fat for ${sex})
- Weekly fat loss target: 0.5 kg/week (500 kcal/day deficit applied via diet plan)
- Training emphasis: ${emphasisMap[goalBodyShape]}
`;
    }

    const systemPrompt = `You are an elite personal trainer and strength coach. Generate a detailed, periodized workout plan.

TRAINEE EXPERIENCE LEVEL:
${EXPERIENCE_CONTEXT[experienceLevel]}
${physiqueSection}
STRICT RULES:
- ONLY use these available equipment: ${equipmentDisplay}
- Split type: ${cycleType.replace('_', ' ').toUpperCase()}
- Generate exercises for these distinct workout days: ${uniqueDayLabels.join(', ')}
- 5-7 exercises per workout day
- Include sets, reps (or time), rest periods, and the primary muscle group for EACH exercise
- Be specific: use proper exercise names (e.g., "Romanian Deadlift", "Incline Dumbbell Press", "Cable Lateral Raise")
- Vary rep ranges appropriately for the experience level above
- Rest times: heavy compounds = 120-180s, moderate = 60-90s, isolation = 45-60s
- For Cable Machine exercises, only include them if "cable" appears in the equipment list`;

    const model = 'gemini-3.1-flash-lite-preview';
    await options?.onProgress?.('generating_split');
    const { object: planData, usage } = await generateObject({
        model: google(model),
        schema: WorkoutPlanSchema,
        system: systemPrompt,
        prompt: `Generate the workout plan. Available equipment: ${equipmentDisplay}. Split: ${cycleType}. Workout days needed: ${uniqueDayLabels.join(', ')}.`,
        maxOutputTokens: 6000,
    });

    await trackAiUsage({ model, feature: AI_FEATURE.WORKOUT_GENERATION, userId, usage });

    await options?.onProgress?.('generating_exercises');
    await db.update(workoutPlans).set({ isActive: false });
    await options?.onProgress?.('saving_plan');

    const [insertedPlan] = await db.insert(workoutPlans).values({
        userId,
        title: planData.title ?? `${cycleType.toUpperCase()} Plan`,
        cycleType: cycleType as any,
        daysPerWeek,
        equipment,
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
                    repsOrTime: String(ex.repsOrTime ?? ex.reps ?? '10-12'),
                    restSeconds: ex.restSeconds ?? ex.rest_seconds ?? 60,
                    muscleGroup: ex.muscleGroup ?? ex.muscle_group ?? '',
                    equipment: ex.equipment ?? '',
                    notes: ex.notes ?? '',
                });
            }
        }
    }

    return { planId: insertedPlan.id };
}

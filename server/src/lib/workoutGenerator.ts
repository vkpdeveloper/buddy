import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateText } from 'ai';
import { env } from './env';
import { db } from '../db';
import { userProfile, workoutPlans, workoutDays, workoutExercises } from '../db/schema';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

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

export async function runWorkoutGeneration(): Promise<{ planId: number }> {
    const profiles = await db.select().from(userProfile).limit(1);
    if (profiles.length === 0) throw new Error('Profile not found');
    const profile = profiles[0];

    const equipment: string[] = JSON.parse(profile.equipment);
    const cycleType = profile.workoutCycle;
    const daysPerWeek = profile.weeklyWorkoutDays;

    const template = CYCLE_TEMPLATES[cycleType];
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
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) throw new Error('No JSON found in AI response');
    planData = JSON.parse(jsonMatch[0]);

    await db.update(workoutPlans).set({ isActive: false });

    const [insertedPlan] = await db.insert(workoutPlans).values({
        title: planData.title ?? `${cycleType.toUpperCase()} Plan`,
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

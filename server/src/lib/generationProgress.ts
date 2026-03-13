import { eq } from 'drizzle-orm';
import { db } from '../db';
import { generationJobs } from '../db/schema';

export type GenerationJobType = 'diet' | 'workout';
export type GenerationJobStatus = 'idle' | 'pending' | 'generating' | 'done' | 'failed';

export interface GenerationStageDefinition {
    key: string;
    message: string;
    progressPercent: number;
    status: Exclude<GenerationJobStatus, 'idle'>;
}

const DIET_STAGES: Record<string, GenerationStageDefinition> = {
    queued: {
        key: 'queued',
        message: 'Queued to build your nutrition plan.',
        progressPercent: 4,
        status: 'pending',
    },
    reading_profile: {
        key: 'reading_profile',
        message: 'Reviewing your body stats and food setup.',
        progressPercent: 12,
        status: 'generating',
    },
    calculating_macros: {
        key: 'calculating_macros',
        message: 'Calculating the calorie target your body can actually sustain.',
        progressPercent: 28,
        status: 'generating',
    },
    generating_meals: {
        key: 'generating_meals',
        message: 'Building meals around the foods you already like.',
        progressPercent: 62,
        status: 'generating',
    },
    saving_plan: {
        key: 'saving_plan',
        message: 'Locking in your first week of meals.',
        progressPercent: 88,
        status: 'generating',
    },
    done: {
        key: 'done',
        message: 'Your nutrition plan is ready.',
        progressPercent: 100,
        status: 'done',
    },
};

const WORKOUT_STAGES: Record<string, GenerationStageDefinition> = {
    queued: {
        key: 'queued',
        message: 'Queued to build your workout plan.',
        progressPercent: 4,
        status: 'pending',
    },
    reading_profile: {
        key: 'reading_profile',
        message: 'Reviewing your goal, experience, and weekly routine.',
        progressPercent: 12,
        status: 'generating',
    },
    matching_equipment: {
        key: 'matching_equipment',
        message: 'Matching your workouts to the equipment you actually have.',
        progressPercent: 26,
        status: 'generating',
    },
    generating_split: {
        key: 'generating_split',
        message: 'Building a split you can recover from each week.',
        progressPercent: 44,
        status: 'generating',
    },
    generating_exercises: {
        key: 'generating_exercises',
        message: 'Matching your workouts to your goal and equipment.',
        progressPercent: 68,
        status: 'generating',
    },
    saving_plan: {
        key: 'saving_plan',
        message: 'Locking in your first week of training.',
        progressPercent: 90,
        status: 'generating',
    },
    done: {
        key: 'done',
        message: 'Your workout plan is ready.',
        progressPercent: 100,
        status: 'done',
    },
};

const STAGES: Record<GenerationJobType, Record<string, GenerationStageDefinition>> = {
    diet: DIET_STAGES,
    workout: WORKOUT_STAGES,
};

export function getGenerationStage(
    type: GenerationJobType,
    key: string,
): GenerationStageDefinition {
    return STAGES[type][key] ?? STAGES[type].queued;
}

export function getIdleGenerationJobState(type: GenerationJobType) {
    return {
        type,
        status: 'idle' as const,
        stageKey: 'idle',
        stageMessage: type === 'diet'
            ? 'Your nutrition plan has not started yet.'
            : 'Your workout plan has not started yet.',
        progressPercent: 0,
        error: null as string | null,
    };
}

export async function setGenerationJobStage(
    jobRowId: number,
    type: GenerationJobType,
    key: string,
) {
    const stage = getGenerationStage(type, key);
    await db.update(generationJobs)
        .set({
            status: stage.status,
            stageKey: stage.key,
            stageMessage: stage.message,
            progressPercent: stage.progressPercent,
            error: null,
            updatedAt: new Date().toISOString(),
        })
        .where(eq(generationJobs.id, jobRowId));
}

export async function markGenerationJobFailed(jobRowId: number, message: string) {
    await db.update(generationJobs)
        .set({
            status: 'failed',
            stageKey: 'failed',
            stageMessage: 'Something interrupted your plan setup.',
            error: message,
            updatedAt: new Date().toISOString(),
        })
        .where(eq(generationJobs.id, jobRowId));
}

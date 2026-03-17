export type MealAnalysisJobPhase =
    | 'queued'
    | 'fetching_image'
    | 'running_analysis'
    | 'saving_analysis';

export type MealAnalysisPipelinePhase =
    | MealAnalysisJobPhase
    | 'analysis_complete'
    | 'logging_meal'
    | 'completed'
    | 'failed';

export type MealAnalysisJobProgress = {
    phase: MealAnalysisJobPhase;
    label: string;
};

export type MealAnalysisPipelineEvent = {
    pipeline: 'meal_photo';
    phase: MealAnalysisPipelinePhase;
    label?: string;
    message?: string;
};

export function getMealAnalysisPhaseLabel(phase: MealAnalysisJobPhase): string {
    switch (phase) {
        case 'queued':
            return 'Queued for meal analysis...';
        case 'fetching_image':
            return 'Preparing the uploaded image...';
        case 'running_analysis':
            return 'Analyzing the uploaded meal...';
        case 'saving_analysis':
            return 'Saving the meal analysis...';
    }
}

export function createMealAnalysisJobProgress(
    phase: MealAnalysisJobPhase,
): MealAnalysisJobProgress {
    return {
        phase,
        label: getMealAnalysisPhaseLabel(phase),
    };
}

export function isMealAnalysisJobProgress(
    value: unknown,
): value is MealAnalysisJobProgress {
    return Boolean(
        value &&
            typeof value === 'object' &&
            'phase' in value &&
            'label' in value &&
            typeof (value as { phase?: unknown }).phase === 'string' &&
            typeof (value as { label?: unknown }).label === 'string',
    );
}

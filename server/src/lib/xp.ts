// ─── XP / Level / Achievement pure functions ─────────────────────────────────

export interface XpInput {
    completedSets: number;        // total sets actually performed
    totalRests: number;           // rest periods that occurred
    skippedRests: number;         // rests the user tapped SKIP on
    totalExercises: number;       // exercises in the plan
    completedExercises: number;   // exercises not skipped
    durationSeconds: number;
    currentStreak: number;        // streak BEFORE this session
}

export interface XpBreakdown {
    fromExercises: number;
    disciplineBonus: number;
    completionBonus: number;
    durationBonus: number;
    subtotal: number;
    multiplier: number;
    total: number;
}

const LEVEL_THRESHOLDS = [
    { level: 1, label: 'Beginner', minXp: 0 },
    { level: 2, label: 'Consistent', minXp: 300 },
    { level: 3, label: 'Disciplined', minXp: 700 },
    { level: 4, label: 'Dedicated', minXp: 1300 },
    { level: 5, label: 'Athlete', minXp: 2200 },
    { level: 6, label: 'Competitor', minXp: 3500 },
    { level: 7, label: 'Elite', minXp: 5200 },
    { level: 8, label: 'Champion', minXp: 7500 },
    { level: 9, label: 'Master', minXp: 10500 },
    { level: 10, label: 'Legend', minXp: 14500 },
];

export function getLevel(totalXp: number): number {
    for (let i = LEVEL_THRESHOLDS.length - 1; i >= 0; i--) {
        if (totalXp >= LEVEL_THRESHOLDS[i].minXp) return LEVEL_THRESHOLDS[i].level;
    }
    return 1;
}

export function getLevelLabel(level: number): string {
    return LEVEL_THRESHOLDS.find(t => t.level === level)?.label ?? 'Beginner';
}

export function getLevelProgressFraction(totalXp: number): number {
    const level = getLevel(totalXp);
    const current = LEVEL_THRESHOLDS.find(t => t.level === level);
    const next = LEVEL_THRESHOLDS.find(t => t.level === level + 1);
    if (!next || !current) return 1.0;
    return (totalXp - current.minXp) / (next.minXp - current.minXp);
}

export function getStreakMultiplier(streak: number): number {
    if (streak >= 30) return 1.5;
    if (streak >= 14) return 1.3;
    if (streak >= 7) return 1.2;
    if (streak >= 3) return 1.1;
    return 1.0;
}

export function calculateXp(input: XpInput): XpBreakdown {
    const fromExercises = input.completedSets * 30;

    // Discipline bonus: proportional to rests honored
    const restsHonored = input.totalRests - input.skippedRests;
    const disciplineRatio = input.totalRests > 0 ? restsHonored / input.totalRests : 1;
    const disciplineBonus = Math.round(50 * disciplineRatio);

    // Completion bonus: all exercises completed
    const completionBonus = input.completedExercises >= input.totalExercises && input.totalExercises > 0 ? 40 : 0;

    // Duration bonus: 20–75 min
    const durationMin = input.durationSeconds / 60;
    const durationBonus = durationMin >= 20 && durationMin <= 75 ? 20 : 0;

    const subtotal = fromExercises + disciplineBonus + completionBonus + durationBonus;
    const multiplier = getStreakMultiplier(input.currentStreak);
    const total = Math.round(subtotal * multiplier);

    return { fromExercises, disciplineBonus, completionBonus, durationBonus, subtotal, multiplier, total };
}

export function calculateNewStreak(lastWorkoutDate: string | null, today: string): number {
    if (!lastWorkoutDate) return 1;
    const last = new Date(lastWorkoutDate);
    const cur = new Date(today);
    const diffDays = Math.round((cur.getTime() - last.getTime()) / (1000 * 60 * 60 * 24));
    if (diffDays === 1) return 999; // sentinel: increment by 1 (caller adds to existing streak)
    if (diffDays === 0) return 0;   // sentinel: same day, no streak change
    return -1;                      // sentinel: streak broken
}

export interface AchievementCheckInput {
    totalWorkoutsCompleted: number;
    currentStreak: number;
    completedExercises: number;
    totalExercises: number;
    skippedRests: number;
    totalRests: number;
    durationSeconds: number;
    startedAt: string;            // ISO datetime
    dayLabels: string[];          // labels of workouts done this week (e.g. ['Push','Pull','Legs'])
    unlockedSlugs: Set<string>;
}

export function checkAchievements(input: AchievementCheckInput): string[] {
    const earned: string[] = [];

    const check = (slug: string, condition: boolean) => {
        if (condition && !input.unlockedSlugs.has(slug)) earned.push(slug);
    };

    check('first_session', input.totalWorkoutsCompleted === 1);
    check('no_skips', input.completedExercises >= input.totalExercises && input.totalExercises > 0);
    check('rest_honored', input.skippedRests === 0 && input.totalRests > 0);
    check('week_streak', input.currentStreak >= 7);
    check('month_streak', input.currentStreak >= 30);
    check('ten_sessions', input.totalWorkoutsCompleted >= 10);
    check('fifty_sessions', input.totalWorkoutsCompleted >= 50);
    check('double_day', input.currentStreak >= 2);
    check('long_haul', input.durationSeconds >= 60 * 60);

    // Early riser: session started before 7 AM local (use UTC since server stores UTC)
    try {
        const hour = new Date(input.startedAt).getHours();
        check('early_riser', hour < 7);
    } catch (_) { }

    // Full cycle: Push + Pull + Legs in the week's labels
    const lowerLabels = input.dayLabels.map(l => l.toLowerCase());
    const hasPush = lowerLabels.some(l => l.includes('push'));
    const hasPull = lowerLabels.some(l => l.includes('pull'));
    const hasLegs = lowerLabels.some(l => l.includes('legs') || l.includes('leg'));
    check('full_ppl', hasPush && hasPull && hasLegs);

    return earned;
}

export const ACHIEVEMENT_SEED = [
    { slug: 'first_session', name: 'First Session', description: 'Complete your first workout', xpReward: 50, iconName: 'fitness_center' },
    { slug: 'no_skips', name: 'Full Commitment', description: 'Zero skipped exercises in a session', xpReward: 75, iconName: 'check_circle' },
    { slug: 'rest_honored', name: 'Disciplined Recovery', description: 'Zero skipped rests in a session', xpReward: 60, iconName: 'self_improvement' },
    { slug: 'week_streak', name: 'Seven Days Straight', description: 'Maintain a 7-day workout streak', xpReward: 150, iconName: 'local_fire_department' },
    { slug: 'month_streak', name: 'Thirty Days', description: 'Maintain a 30-day workout streak', xpReward: 500, iconName: 'military_tech' },
    { slug: 'ten_sessions', name: 'Ten Under the Bar', description: 'Complete 10 total sessions', xpReward: 100, iconName: 'bar_chart' },
    { slug: 'fifty_sessions', name: 'Fifty Sessions', description: 'Complete 50 total sessions', xpReward: 300, iconName: 'emoji_events' },
    { slug: 'early_riser', name: 'Early Riser', description: 'Start a session before 7 AM', xpReward: 40, iconName: 'wb_sunny' },
    { slug: 'double_day', name: 'Back to Back', description: 'Maintain a 2-day streak', xpReward: 80, iconName: 'repeat' },
    { slug: 'full_ppl', name: 'Full Cycle', description: 'Complete Push, Pull, and Legs in one week', xpReward: 120, iconName: 'sync' },
    { slug: 'long_haul', name: 'The Long Haul', description: 'Complete a 60+ minute session', xpReward: 60, iconName: 'timer' },
    { slug: 'perfect_week', name: 'Perfect Week', description: 'Hit all non-rest days in a week', xpReward: 200, iconName: 'calendar_today' },
    { slug: 'first_body_log', name: 'First Check-In', description: 'Log your first body measurement', xpReward: 100, iconName: 'monitor_weight' },
];

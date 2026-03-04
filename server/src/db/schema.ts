import {
    sqliteTable,
    text,
    integer,
    real,
} from 'drizzle-orm/sqlite-core';
import { sql } from 'drizzle-orm';

// ─── User Profile (single row, id always = 1) ───────────────────────────────

export const userProfile = sqliteTable('user_profile', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    height: real('height').notNull().default(175),          // cm
    weight: real('weight').notNull().default(70),           // kg
    age: integer('age').notNull().default(25),
    sex: text('sex', { enum: ['male', 'female'] }).notNull().default('male'),
    goal: text('goal', {
        enum: ['muscle_gain', 'fat_loss', 'recomp', 'maintain', 'endurance'],
    }).notNull().default('muscle_gain'),
    activityLevel: text('activity_level', {
        enum: ['sedentary', 'lightly_active', 'moderately_active', 'very_active', 'athlete'],
    }).notNull().default('moderately_active'),
    weeklyWorkoutDays: integer('weekly_workout_days').notNull().default(4),
    equipment: text('equipment').notNull().default('["dumbbells","bodyweight"]'), // JSON array
    workoutCycle: text('workout_cycle', {
        enum: ['ppl', 'upper_lower', 'ppl_upper', 'full_body'],
    }).notNull().default('ppl'),
    useProteinPowder: integer('use_protein_powder', { mode: 'boolean' }).notNull().default(true),
    proteinLevel: text('protein_level', {
        enum: ['high', 'moderate'],
    }).notNull().default('high'),
    name: text('name').notNull().default('Athlete'),
    waterTargetMl: integer('water_target_ml').notNull().default(2500),
    weightGoalKg: real('weight_goal_kg'),
    preferredMeals: text('preferred_meals').notNull().default('["breakfast","morning_snack","lunch","pre_workout","post_workout","dinner","evening_snack"]'), // JSON array
    profileCompleted: integer('profile_completed', { mode: 'boolean' }).notNull().default(false),
    updatedAt: text('updated_at').default(sql`(datetime('now'))`),
});

// ─── Diet Plans ─────────────────────────────────────────────────────────────

export const dietPlans = sqliteTable('diet_plans', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    title: text('title').notNull(),
    totalCalories: integer('total_calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
    createdAt: text('created_at').default(sql`(datetime('now'))`),
});

export const dietDays = sqliteTable('diet_days', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    planId: integer('plan_id').notNull().references(() => dietPlans.id, { onDelete: 'cascade' }),
    dayNumber: integer('day_number').notNull(),            // 1–7
    dayName: text('day_name').notNull(),                   // Monday, Tuesday, etc.
    totalCalories: integer('total_calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isCompleted: integer('is_completed', { mode: 'boolean' }).notNull().default(false),
});

export const dietMeals = sqliteTable('diet_meals', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    dayId: integer('day_id').notNull().references(() => dietDays.id, { onDelete: 'cascade' }),
    mealType: text('meal_type', {
        enum: ['breakfast', 'morning_snack', 'lunch', 'pre_workout', 'post_workout', 'dinner', 'evening_snack'],
    }).notNull(),
    mealName: text('meal_name').notNull(),
    description: text('description').notNull().default(''),
    calories: integer('calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isCompleted: integer('is_completed', { mode: 'boolean' }).notNull().default(false),
    notes: text('notes').notNull().default(''),
});

// ─── Workout Plans ───────────────────────────────────────────────────────────

export const workoutPlans = sqliteTable('workout_plans', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    title: text('title').notNull(),
    cycleType: text('cycle_type', {
        enum: ['ppl', 'upper_lower', 'ppl_upper', 'full_body'],
    }).notNull(),
    daysPerWeek: integer('days_per_week').notNull(),
    equipment: text('equipment').notNull().default('["dumbbells"]'), // JSON array
    isActive: integer('is_active', { mode: 'boolean' }).notNull().default(true),
    createdAt: text('created_at').default(sql`(datetime('now'))`),
});

export const workoutDays = sqliteTable('workout_days', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    planId: integer('plan_id').notNull().references(() => workoutPlans.id, { onDelete: 'cascade' }),
    dayNumber: integer('day_number').notNull(),
    dayLabel: text('day_label').notNull(),   // Push, Pull, Legs, Upper, Lower, Full Body, Rest
    isRestDay: integer('is_rest_day', { mode: 'boolean' }).notNull().default(false),
    notes: text('notes').notNull().default(''),
});

export const workoutExercises = sqliteTable('workout_exercises', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    dayId: integer('day_id').notNull().references(() => workoutDays.id, { onDelete: 'cascade' }),
    orderIndex: integer('order_index').notNull(),
    name: text('name').notNull(),
    sets: integer('sets').notNull(),
    repsOrTime: text('reps_or_time').notNull(), // "8-12" or "30s" or "12"
    restSeconds: integer('rest_seconds').notNull().default(60),
    muscleGroup: text('muscle_group').notNull().default(''),
    equipment: text('equipment').notNull().default(''),
    notes: text('notes').notNull().default(''),
});

// ─── Diet Meal Logs (per-date completion tracking) ───────────────────────────

export const dietMealLogs = sqliteTable('diet_meal_logs', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    mealId: integer('meal_id').notNull().references(() => dietMeals.id, { onDelete: 'cascade' }),
    date: text('date').notNull(),                   // 'YYYY-MM-DD'
    isCompleted: integer('is_completed', { mode: 'boolean' }).notNull().default(false),
    loggedAt: text('logged_at').default(sql`(datetime('now'))`),
});

// ─── Daily Logs (one row per day) ────────────────────────────────────────────

export const dailyLogs = sqliteTable('daily_logs', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    date: text('date').notNull().unique(),          // 'YYYY-MM-DD'
    waterMl: integer('water_ml').notNull().default(0),
    sleepMinutes: integer('sleep_minutes').notNull().default(0),
    stepsCount: integer('steps_count').notNull().default(0),
    caloriesBurned: integer('calories_burned').notNull().default(0),
    updatedAt: text('updated_at').default(sql`(datetime('now'))`),
});

export const workoutSessions = sqliteTable('workout_sessions', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    planId: integer('plan_id').notNull().references(() => workoutPlans.id, { onDelete: 'cascade' }),
    dayId: integer('day_id').notNull().references(() => workoutDays.id, { onDelete: 'cascade' }),
    startedAt: text('started_at').default(sql`(datetime('now'))`),
    completedAt: text('completed_at'),
    totalDurationSeconds: integer('total_duration_seconds'),
    totalExercises: integer('total_exercises').notNull().default(0),
    completedExercises: integer('completed_exercises').notNull().default(0),
    totalRests: integer('total_rests').notNull().default(0),
    skippedRests: integer('skipped_rests').notNull().default(0),
    xpEarned: integer('xp_earned').notNull().default(0),
});

// ─── Gamification ─────────────────────────────────────────────────────────────

export const userProgress = sqliteTable('user_progress', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    totalXp: integer('total_xp').notNull().default(0),
    currentLevel: integer('current_level').notNull().default(1),
    currentStreak: integer('current_streak').notNull().default(0),
    longestStreak: integer('longest_streak').notNull().default(0),
    lastWorkoutDate: text('last_workout_date'),          // 'YYYY-MM-DD'
    totalWorkoutsCompleted: integer('total_workouts_completed').notNull().default(0),
    updatedAt: text('updated_at').default(sql`(datetime('now'))`),
});

export const achievements = sqliteTable('achievements', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    slug: text('slug').notNull().unique(),
    name: text('name').notNull(),
    description: text('description').notNull(),
    xpReward: integer('xp_reward').notNull().default(0),
    iconName: text('icon_name').notNull().default('emoji_events'),
});

export const userAchievements = sqliteTable('user_achievements', {
    id: integer('id').primaryKey({ autoIncrement: true }),
    achievementId: integer('achievement_id').notNull().references(() => achievements.id),
    unlockedAt: text('unlocked_at').default(sql`(datetime('now'))`),
    sessionId: integer('session_id').references(() => workoutSessions.id),
});

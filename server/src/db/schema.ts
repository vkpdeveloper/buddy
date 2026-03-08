import {
    pgTable,
    text,
    integer,
    real,
    boolean,
    serial,
    index,
    uniqueIndex,
    jsonb,
    timestamp,
} from 'drizzle-orm/pg-core';
import { sql } from 'drizzle-orm';

// ─── Users (synced from Firebase Auth) ───────────────────────────────────────

export const users = pgTable('users', {
    id: serial('id').primaryKey(),
    firebaseUid: text('firebase_uid').notNull().unique(),   // Firebase UID
    email: text('email').notNull(),
    name: text('name').notNull().default(''),
    photoUrl: text('photo_url').notNull().default(''),
    onboarded: boolean('onboarded').notNull().default(false), // true only after full onboarding complete
    registeredAt: timestamp('registered_at').notNull().defaultNow(),
    updatedAt: timestamp('updated_at').notNull().defaultNow(),
});

// ─── User Profile (one row per Firebase user) ────────────────────────────────

export const userProfile = pgTable('user_profile', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),                      // Firebase UID
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
    equipment: jsonb('equipment').$type<string[]>().notNull().default(['dumbbells', 'bodyweight']),
    workoutCycle: text('workout_cycle', {
        enum: ['ppl', 'upper_lower', 'ppl_upper', 'full_body'],
    }).notNull().default('ppl'),
    useProteinPowder: boolean('use_protein_powder').notNull().default(true),
    proteinLevel: text('protein_level', {
        enum: ['high', 'moderate'],
    }).notNull().default('high'),
    name: text('name').notNull().default('Athlete'),
    waterTargetMl: integer('water_target_ml').notNull().default(2500),
    weightGoalKg: real('weight_goal_kg'),
    bodyFatGoalPercent: real('body_fat_goal_percent'),
    preferredMeals: jsonb('preferred_meals').$type<string[]>().notNull().default(['breakfast', 'morning_snack', 'lunch', 'pre_workout', 'post_workout', 'dinner', 'evening_snack']),
    dietType: text('diet_type', {
        enum: ['vegetarian', 'non_vegetarian', 'vegan'],
    }).notNull().default('vegetarian'),
    mealPrepTime: text('meal_prep_time', {
        enum: ['15min', '30min', '1hour'],
    }).notNull().default('30min'),
    cookingBy: text('cooking_by', {
        enum: ['myself', 'maid'],
    }).notNull().default('myself'),
    preferredFoods: jsonb('preferred_foods').$type<string[]>().notNull().default([]),
    profileCompleted: boolean('profile_completed').notNull().default(false),
    preferSupersets: boolean('prefer_supersets').default(false),
    updatedAt: text('updated_at').default(sql`now()`),
}, (t) => [
    index('user_profile_user_id_idx').on(t.userId),
]);

// ─── Diet Plans ─────────────────────────────────────────────────────────────

export const dietPlans = pgTable('diet_plans', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    title: text('title').notNull(),
    totalCalories: integer('total_calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isActive: boolean('is_active').notNull().default(true),
    createdAt: text('created_at').default(sql`now()`),
}, (t) => [
    index('diet_plans_user_id_idx').on(t.userId),
]);

export const dietDays = pgTable('diet_days', {
    id: serial('id').primaryKey(),
    planId: integer('plan_id').notNull().references(() => dietPlans.id, { onDelete: 'cascade' }),
    dayNumber: integer('day_number').notNull(),            // 1–7
    dayName: text('day_name').notNull(),                   // Monday, Tuesday, etc.
    totalCalories: integer('total_calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isCompleted: boolean('is_completed').notNull().default(false),
});

export const dietMeals = pgTable('diet_meals', {
    id: serial('id').primaryKey(),
    dayId: integer('day_id').notNull().references(() => dietDays.id, { onDelete: 'cascade' }),
    orderIndex: integer('order_index').notNull().default(0),
    mealType: text('meal_type', {
        enum: ['breakfast', 'morning_snack', 'lunch', 'pre_workout', 'post_workout', 'dinner', 'evening_snack'],
    }).notNull(),
    mealTime: text('meal_time').notNull().default('08:00'), // HH:mm
    mealName: text('meal_name').notNull(),
    description: text('description').notNull().default(''),
    ingredients: text('ingredients').notNull().default('[]'),  // JSON: [{ name, quantity }]
    recipe: text('recipe').notNull().default(''),
    calories: integer('calories').notNull(),
    proteinG: real('protein_g').notNull(),
    carbsG: real('carbs_g').notNull(),
    fatG: real('fat_g').notNull(),
    isCompleted: boolean('is_completed').notNull().default(false),
    notes: text('notes').notNull().default(''),
});

// ─── Workout Plans ───────────────────────────────────────────────────────────

export const workoutPlans = pgTable('workout_plans', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    title: text('title').notNull(),
    cycleType: text('cycle_type', {
        enum: ['ppl', 'upper_lower', 'ppl_upper', 'full_body'],
    }).notNull(),
    daysPerWeek: integer('days_per_week').notNull(),
    equipment: jsonb('equipment').$type<string[]>().notNull().default(['dumbbells']),
    isActive: boolean('is_active').notNull().default(true),
    createdAt: text('created_at').default(sql`now()`),
}, (t) => [
    index('workout_plans_user_id_idx').on(t.userId),
]);

export const workoutDays = pgTable('workout_days', {
    id: serial('id').primaryKey(),
    planId: integer('plan_id').notNull().references(() => workoutPlans.id, { onDelete: 'cascade' }),
    dayNumber: integer('day_number').notNull(),
    dayLabel: text('day_label').notNull(),   // Push, Pull, Legs, Upper, Lower, Full Body, Rest
    isRestDay: boolean('is_rest_day').notNull().default(false),
    notes: text('notes').notNull().default(''),
});

export const workoutExercises = pgTable('workout_exercises', {
    id: serial('id').primaryKey(),
    dayId: integer('day_id').notNull().references(() => workoutDays.id, { onDelete: 'cascade' }),
    orderIndex: integer('order_index').notNull(),
    name: text('name').notNull(),
    sets: integer('sets').notNull(),
    repsOrTime: text('reps_or_time').notNull(), // "8-12" or "30s" or "12"
    restSeconds: integer('rest_seconds').notNull().default(60),
    muscleGroup: text('muscle_group').notNull().default(''),
    equipment: text('equipment').notNull().default(''),
    notes: text('notes').notNull().default(''),
    supersetGroupId: integer('superset_group_id'),   // null = standalone; same int = paired on that day
    supersetOrder: integer('superset_order'),         // 0 = first in pair, 1 = second
});

// ─── Diet Meal Logs (per-date completion tracking) ───────────────────────────

export const dietMealLogs = pgTable('diet_meal_logs', {
    id: serial('id').primaryKey(),
    mealId: integer('meal_id').notNull().references(() => dietMeals.id, { onDelete: 'cascade' }),
    date: text('date').notNull(),                   // 'YYYY-MM-DD'
    isCompleted: boolean('is_completed').notNull().default(false),
    actualMealName: text('actual_meal_name').notNull().default(''),
    actualCalories: integer('actual_calories'),
    actualProteinG: real('actual_protein_g'),
    actualCarbsG: real('actual_carbs_g'),
    actualFatG: real('actual_fat_g'),
    actualNotes: text('actual_notes').notNull().default(''),
    rawPayload: text('raw_payload').notNull().default('{}'),
    loggedAt: text('logged_at').default(sql`now()`),
});

// ─── Daily Logs (one row per user per day) ───────────────────────────────────

export const dailyLogs = pgTable('daily_logs', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),                      // Clerk user ID
    date: text('date').notNull(),                           // 'YYYY-MM-DD'
    waterMl: integer('water_ml').notNull().default(0),
    sleepMinutes: integer('sleep_minutes').notNull().default(0),
    stepsCount: integer('steps_count').notNull().default(0),
    caloriesBurned: integer('calories_burned').notNull().default(0),
    updatedAt: text('updated_at').default(sql`now()`),
}, (t) => [
    uniqueIndex('daily_logs_user_date_unique').on(t.userId, t.date),
    index('daily_logs_user_id_idx').on(t.userId),
]);

export const workoutSessions = pgTable('workout_sessions', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),                      // Clerk user ID
    planId: integer('plan_id').notNull().references(() => workoutPlans.id, { onDelete: 'cascade' }),
    dayId: integer('day_id').notNull().references(() => workoutDays.id, { onDelete: 'cascade' }),
    startedAt: text('started_at').default(sql`now()`),
    completedAt: text('completed_at'),
    totalDurationSeconds: integer('total_duration_seconds'),
    totalExercises: integer('total_exercises').notNull().default(0),
    completedExercises: integer('completed_exercises').notNull().default(0),
    totalRests: integer('total_rests').notNull().default(0),
    skippedRests: integer('skipped_rests').notNull().default(0),
    pausedDurationSeconds: integer('paused_duration_seconds').notNull().default(0),
    warmupData: text('warmup_data').notNull().default('{}'),
    cooldownData: text('cooldown_data').notNull().default('{}'),
    setLogs: text('set_logs').notNull().default('[]'),
    sessionNotes: text('session_notes').notNull().default('[]'),
    hrSnapshots: text('hr_snapshots').notNull().default('[]'),
    xpEarned: integer('xp_earned').notNull().default(0),
}, (t) => [
    index('workout_sessions_user_id_idx').on(t.userId),
]);

// ─── Gamification ─────────────────────────────────────────────────────────────

export const userProgress = pgTable('user_progress', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    totalXp: integer('total_xp').notNull().default(0),
    currentLevel: integer('current_level').notNull().default(1),
    currentStreak: integer('current_streak').notNull().default(0),
    longestStreak: integer('longest_streak').notNull().default(0),
    lastWorkoutDate: text('last_workout_date'),          // 'YYYY-MM-DD'
    totalWorkoutsCompleted: integer('total_workouts_completed').notNull().default(0),
    updatedAt: text('updated_at').default(sql`now()`),
}, (t) => [
    uniqueIndex('user_progress_user_id_unique').on(t.userId),
]);

export const achievements = pgTable('achievements', {
    id: serial('id').primaryKey(),
    slug: text('slug').notNull().unique(),
    name: text('name').notNull(),
    description: text('description').notNull(),
    xpReward: integer('xp_reward').notNull().default(0),
    iconName: text('icon_name').notNull().default('emoji_events'),
});

export const userAchievements = pgTable('user_achievements', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    achievementId: integer('achievement_id').notNull().references(() => achievements.id),
    unlockedAt: text('unlocked_at').default(sql`now()`),
    sessionId: integer('session_id').references(() => workoutSessions.id),
}, (t) => [
    index('user_achievements_user_id_idx').on(t.userId),
]);

// ─── Generation Jobs (async plan generation tracking) ────────────────────────

export const generationJobs = pgTable('generation_jobs', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    type: text('type', { enum: ['diet', 'workout'] }).notNull(),
    status: text('status', { enum: ['pending', 'generating', 'done', 'failed'] }).notNull().default('pending'),
    error: text('error'),
    createdAt: text('created_at').default(sql`now()`),
    updatedAt: text('updated_at').default(sql`now()`),
}, (t) => [
    index('generation_jobs_user_id_idx').on(t.userId),
]);

// ─── Exercise Catalog (shared, no userId) ─────────────────────────────────────

export const exerciseCatalog = pgTable('exercise_catalog', {
    id: serial('id').primaryKey(),
    name: text('name').notNull().unique(),
    image: text('image'),
    description: text('description').notNull(),
    muscleGroup: text('muscle_group').notNull(), // Chest, Back, Legs, Shoulders, Arms, Core
    equipment: text('equipment').notNull(),       // Barbell, Dumbbell, Cable, Bodyweight, etc.
    category: text('category').notNull(),         // compound | isolation
    notes: text('notes'),
    videoLink: text('video_link'),               // YouTube URL
});

// ─── Personal Records ─────────────────────────────────────────────────────────

export const personalRecords = pgTable('personal_records', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),                      // Clerk user ID
    exerciseNameNormalized: text('exercise_name_normalized').notNull(),
    exerciseNameDisplay: text('exercise_name_display').notNull(),
    weightKg: real('weight_kg').notNull(),
    reps: integer('reps').notNull(),
    achievedAt: text('achieved_at').notNull(),   // ISO timestamp
    sessionId: integer('session_id').references(() => workoutSessions.id, { onDelete: 'set null' }),
}, (t) => [
    uniqueIndex('personal_records_user_exercise_unique').on(t.userId, t.exerciseNameNormalized),
    index('personal_records_user_id_idx').on(t.userId),
]);

// ─── Body Measurements (Growth tracking) ─────────────────────────────────────

export const bodyMeasurements = pgTable('body_measurements', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    date: text('date').notNull(),                       // 'YYYY-MM-DD'
    weightKg: real('weight_kg'),                        // body weight in kg
    bodyFatPercent: real('body_fat_percent'),           // body fat percentage
    chestCm: real('chest_cm'),                          // chest circumference
    waistCm: real('waist_cm'),                          // waist circumference
    hipsCm: real('hips_cm'),                            // hips circumference
    armsCm: real('arms_cm'),                            // avg upper arm
    thighsCm: real('thighs_cm'),                        // avg thigh
    notes: text('notes').notNull().default(''),
    xpEarned: integer('xp_earned').notNull().default(0),
    createdAt: text('created_at').default(sql`now()`),
}, (t) => [
    index('body_measurements_user_id_idx').on(t.userId),
]);

export const progressPhotos = pgTable('progress_photos', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    date: text('date').notNull(),                       // 'YYYY-MM-DD'
    measurementId: integer('measurement_id').references(() => bodyMeasurements.id, { onDelete: 'set null' }),
    objectKey: text('object_key').notNull().unique(),
    mimeType: text('mime_type').notNull(),
    sizeBytes: integer('size_bytes').notNull().default(0),
    note: text('note').notNull().default(''),
    createdAt: text('created_at').default(sql`now()`),
}, (t) => [
    index('progress_photos_user_id_idx').on(t.userId),
]);

// ─── Diet Quick Logs (standalone photo-captured meals, no meal plan FK) ───────

export const dietQuickLogs = pgTable('diet_quick_logs', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    date: text('date').notNull(),                   // 'YYYY-MM-DD'
    mealName: text('meal_name').notNull(),
    calories: integer('calories').notNull().default(0),
    proteinG: real('protein_g').notNull().default(0),
    carbsG: real('carbs_g').notNull().default(0),
    fatG: real('fat_g').notNull().default(0),
    notes: text('notes').notNull().default(''),
    attachmentId: integer('attachment_id').references(() => mealMediaAttachments.id, { onDelete: 'set null' }),
    loggedAt: text('logged_at').default(sql`now()`),
}, (t) => [
    index('diet_quick_logs_user_id_idx').on(t.userId),
]);

// ─── Meal Media Attachments (photo → AI nutrition analysis) ──────────────────

export const mealMediaAttachments = pgTable('meal_media_attachments', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),
    objectKey: text('object_key').notNull(),
    mimeType: text('mime_type').notNull(),
    sizeBytes: integer('size_bytes').notNull(),
    aiAnalysisStatus: text('ai_analysis_status').notNull().default('pending'), // pending | analyzing | completed | failed
    aiAnalysisResult: jsonb('ai_analysis_result'),  // { ingredients, macros, confidence }
    createdAt: timestamp('created_at').defaultNow().notNull(),
}, (t) => [
    index('meal_media_attachments_user_id_idx').on(t.userId),
]);

export const bodyMilestones = pgTable('body_milestones', {
    id: serial('id').primaryKey(),
    userId: text('user_id').notNull(),                      // Clerk user ID
    milestoneKey: text('milestone_key').notNull(),
    measurementId: integer('measurement_id').notNull().references(() => bodyMeasurements.id, { onDelete: 'cascade' }),
    xpReward: integer('xp_reward').notNull().default(0),
    createdAt: text('created_at').default(sql`now()`),
}, (t) => [
    uniqueIndex('body_milestones_user_milestone_unique').on(t.userId, t.milestoneKey),
    index('body_milestones_user_id_idx').on(t.userId),
]);

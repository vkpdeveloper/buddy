CREATE TABLE "achievements" (
	"id" serial PRIMARY KEY NOT NULL,
	"slug" text NOT NULL,
	"name" text NOT NULL,
	"description" text NOT NULL,
	"xp_reward" integer DEFAULT 0 NOT NULL,
	"icon_name" text DEFAULT 'emoji_events' NOT NULL,
	CONSTRAINT "achievements_slug_unique" UNIQUE("slug")
);
--> statement-breakpoint
CREATE TABLE "body_measurements" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"date" text NOT NULL,
	"weight_kg" real,
	"body_fat_percent" real,
	"chest_cm" real,
	"waist_cm" real,
	"hips_cm" real,
	"arms_cm" real,
	"thighs_cm" real,
	"notes" text DEFAULT '' NOT NULL,
	"xp_earned" integer DEFAULT 0 NOT NULL,
	"created_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "body_milestones" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"milestone_key" text NOT NULL,
	"measurement_id" integer NOT NULL,
	"xp_reward" integer DEFAULT 0 NOT NULL,
	"created_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "daily_logs" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"date" text NOT NULL,
	"water_ml" integer DEFAULT 0 NOT NULL,
	"sleep_minutes" integer DEFAULT 0 NOT NULL,
	"steps_count" integer DEFAULT 0 NOT NULL,
	"calories_burned" integer DEFAULT 0 NOT NULL,
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "diet_days" (
	"id" serial PRIMARY KEY NOT NULL,
	"plan_id" integer NOT NULL,
	"day_number" integer NOT NULL,
	"day_name" text NOT NULL,
	"total_calories" integer NOT NULL,
	"protein_g" real NOT NULL,
	"carbs_g" real NOT NULL,
	"fat_g" real NOT NULL,
	"is_completed" boolean DEFAULT false NOT NULL
);
--> statement-breakpoint
CREATE TABLE "diet_meal_logs" (
	"id" serial PRIMARY KEY NOT NULL,
	"meal_id" integer NOT NULL,
	"date" text NOT NULL,
	"is_completed" boolean DEFAULT false NOT NULL,
	"actual_meal_name" text DEFAULT '' NOT NULL,
	"actual_calories" integer,
	"actual_protein_g" real,
	"actual_carbs_g" real,
	"actual_fat_g" real,
	"actual_notes" text DEFAULT '' NOT NULL,
	"raw_payload" text DEFAULT '{}' NOT NULL,
	"logged_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "diet_meals" (
	"id" serial PRIMARY KEY NOT NULL,
	"day_id" integer NOT NULL,
	"order_index" integer DEFAULT 0 NOT NULL,
	"meal_type" text NOT NULL,
	"meal_time" text DEFAULT '08:00' NOT NULL,
	"meal_name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"ingredients" text DEFAULT '[]' NOT NULL,
	"recipe" text DEFAULT '' NOT NULL,
	"calories" integer NOT NULL,
	"protein_g" real NOT NULL,
	"carbs_g" real NOT NULL,
	"fat_g" real NOT NULL,
	"is_completed" boolean DEFAULT false NOT NULL,
	"notes" text DEFAULT '' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "diet_plans" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"total_calories" integer NOT NULL,
	"protein_g" real NOT NULL,
	"carbs_g" real NOT NULL,
	"fat_g" real NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "exercise_catalog" (
	"id" serial PRIMARY KEY NOT NULL,
	"name" text NOT NULL,
	"image" text,
	"description" text NOT NULL,
	"muscle_group" text NOT NULL,
	"equipment" text NOT NULL,
	"category" text NOT NULL,
	"notes" text,
	"video_link" text,
	CONSTRAINT "exercise_catalog_name_unique" UNIQUE("name")
);
--> statement-breakpoint
CREATE TABLE "generation_jobs" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"type" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"error" text,
	"created_at" text DEFAULT now(),
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "personal_records" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"exercise_name_normalized" text NOT NULL,
	"exercise_name_display" text NOT NULL,
	"weight_kg" real NOT NULL,
	"reps" integer NOT NULL,
	"achieved_at" text NOT NULL,
	"session_id" integer
);
--> statement-breakpoint
CREATE TABLE "progress_photos" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"date" text NOT NULL,
	"measurement_id" integer,
	"object_key" text NOT NULL,
	"mime_type" text NOT NULL,
	"size_bytes" integer DEFAULT 0 NOT NULL,
	"note" text DEFAULT '' NOT NULL,
	"created_at" text DEFAULT now(),
	CONSTRAINT "progress_photos_object_key_unique" UNIQUE("object_key")
);
--> statement-breakpoint
CREATE TABLE "user_achievements" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"achievement_id" integer NOT NULL,
	"unlocked_at" text DEFAULT now(),
	"session_id" integer
);
--> statement-breakpoint
CREATE TABLE "user_profile" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"height" real DEFAULT 175 NOT NULL,
	"weight" real DEFAULT 70 NOT NULL,
	"age" integer DEFAULT 25 NOT NULL,
	"sex" text DEFAULT 'male' NOT NULL,
	"goal" text DEFAULT 'muscle_gain' NOT NULL,
	"activity_level" text DEFAULT 'moderately_active' NOT NULL,
	"weekly_workout_days" integer DEFAULT 4 NOT NULL,
	"equipment" text DEFAULT '["dumbbells","bodyweight"]' NOT NULL,
	"workout_cycle" text DEFAULT 'ppl' NOT NULL,
	"use_protein_powder" boolean DEFAULT true NOT NULL,
	"protein_level" text DEFAULT 'high' NOT NULL,
	"name" text DEFAULT 'Athlete' NOT NULL,
	"water_target_ml" integer DEFAULT 2500 NOT NULL,
	"weight_goal_kg" real,
	"body_fat_goal_percent" real,
	"preferred_meals" text DEFAULT '["breakfast","morning_snack","lunch","pre_workout","post_workout","dinner","evening_snack"]' NOT NULL,
	"diet_type" text DEFAULT 'vegetarian' NOT NULL,
	"meal_prep_time" text DEFAULT '30min' NOT NULL,
	"cooking_by" text DEFAULT 'myself' NOT NULL,
	"preferred_foods" text DEFAULT '[]' NOT NULL,
	"profile_completed" boolean DEFAULT false NOT NULL,
	"prefer_supersets" boolean DEFAULT false,
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "user_progress" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"total_xp" integer DEFAULT 0 NOT NULL,
	"current_level" integer DEFAULT 1 NOT NULL,
	"current_streak" integer DEFAULT 0 NOT NULL,
	"longest_streak" integer DEFAULT 0 NOT NULL,
	"last_workout_date" text,
	"total_workouts_completed" integer DEFAULT 0 NOT NULL,
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "workout_days" (
	"id" serial PRIMARY KEY NOT NULL,
	"plan_id" integer NOT NULL,
	"day_number" integer NOT NULL,
	"day_label" text NOT NULL,
	"is_rest_day" boolean DEFAULT false NOT NULL,
	"notes" text DEFAULT '' NOT NULL
);
--> statement-breakpoint
CREATE TABLE "workout_exercises" (
	"id" serial PRIMARY KEY NOT NULL,
	"day_id" integer NOT NULL,
	"order_index" integer NOT NULL,
	"name" text NOT NULL,
	"sets" integer NOT NULL,
	"reps_or_time" text NOT NULL,
	"rest_seconds" integer DEFAULT 60 NOT NULL,
	"muscle_group" text DEFAULT '' NOT NULL,
	"equipment" text DEFAULT '' NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"superset_group_id" integer,
	"superset_order" integer
);
--> statement-breakpoint
CREATE TABLE "workout_plans" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"title" text NOT NULL,
	"cycle_type" text NOT NULL,
	"days_per_week" integer NOT NULL,
	"equipment" text DEFAULT '["dumbbells"]' NOT NULL,
	"is_active" boolean DEFAULT true NOT NULL,
	"created_at" text DEFAULT now()
);
--> statement-breakpoint
CREATE TABLE "workout_sessions" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"plan_id" integer NOT NULL,
	"day_id" integer NOT NULL,
	"started_at" text DEFAULT now(),
	"completed_at" text,
	"total_duration_seconds" integer,
	"total_exercises" integer DEFAULT 0 NOT NULL,
	"completed_exercises" integer DEFAULT 0 NOT NULL,
	"total_rests" integer DEFAULT 0 NOT NULL,
	"skipped_rests" integer DEFAULT 0 NOT NULL,
	"paused_duration_seconds" integer DEFAULT 0 NOT NULL,
	"warmup_data" text DEFAULT '{}' NOT NULL,
	"cooldown_data" text DEFAULT '{}' NOT NULL,
	"set_logs" text DEFAULT '[]' NOT NULL,
	"session_notes" text DEFAULT '[]' NOT NULL,
	"hr_snapshots" text DEFAULT '[]' NOT NULL,
	"xp_earned" integer DEFAULT 0 NOT NULL
);
--> statement-breakpoint
ALTER TABLE "body_milestones" ADD CONSTRAINT "body_milestones_measurement_id_body_measurements_id_fk" FOREIGN KEY ("measurement_id") REFERENCES "public"."body_measurements"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_days" ADD CONSTRAINT "diet_days_plan_id_diet_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."diet_plans"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_meal_logs" ADD CONSTRAINT "diet_meal_logs_meal_id_diet_meals_id_fk" FOREIGN KEY ("meal_id") REFERENCES "public"."diet_meals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_meals" ADD CONSTRAINT "diet_meals_day_id_diet_days_id_fk" FOREIGN KEY ("day_id") REFERENCES "public"."diet_days"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "personal_records" ADD CONSTRAINT "personal_records_session_id_workout_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_sessions"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress_photos" ADD CONSTRAINT "progress_photos_measurement_id_body_measurements_id_fk" FOREIGN KEY ("measurement_id") REFERENCES "public"."body_measurements"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_achievements" ADD CONSTRAINT "user_achievements_achievement_id_achievements_id_fk" FOREIGN KEY ("achievement_id") REFERENCES "public"."achievements"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_achievements" ADD CONSTRAINT "user_achievements_session_id_workout_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."workout_sessions"("id") ON DELETE no action ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_days" ADD CONSTRAINT "workout_days_plan_id_workout_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."workout_plans"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_exercises" ADD CONSTRAINT "workout_exercises_day_id_workout_days_id_fk" FOREIGN KEY ("day_id") REFERENCES "public"."workout_days"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_plan_id_workout_plans_id_fk" FOREIGN KEY ("plan_id") REFERENCES "public"."workout_plans"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_day_id_workout_days_id_fk" FOREIGN KEY ("day_id") REFERENCES "public"."workout_days"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "body_milestones_user_milestone_unique" ON "body_milestones" USING btree ("user_id","milestone_key");--> statement-breakpoint
CREATE UNIQUE INDEX "daily_logs_user_date_unique" ON "daily_logs" USING btree ("user_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "personal_records_user_exercise_unique" ON "personal_records" USING btree ("user_id","exercise_name_normalized");
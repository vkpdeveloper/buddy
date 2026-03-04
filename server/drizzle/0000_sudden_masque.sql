CREATE TABLE `diet_days` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`plan_id` integer NOT NULL,
	`day_number` integer NOT NULL,
	`day_name` text NOT NULL,
	`total_calories` integer NOT NULL,
	`protein_g` real NOT NULL,
	`carbs_g` real NOT NULL,
	`fat_g` real NOT NULL,
	`is_completed` integer DEFAULT false NOT NULL,
	FOREIGN KEY (`plan_id`) REFERENCES `diet_plans`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `diet_meals` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`day_id` integer NOT NULL,
	`meal_type` text NOT NULL,
	`meal_name` text NOT NULL,
	`description` text DEFAULT '' NOT NULL,
	`calories` integer NOT NULL,
	`protein_g` real NOT NULL,
	`carbs_g` real NOT NULL,
	`fat_g` real NOT NULL,
	`is_completed` integer DEFAULT false NOT NULL,
	`notes` text DEFAULT '' NOT NULL,
	FOREIGN KEY (`day_id`) REFERENCES `diet_days`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `diet_plans` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`title` text NOT NULL,
	`total_calories` integer NOT NULL,
	`protein_g` real NOT NULL,
	`carbs_g` real NOT NULL,
	`fat_g` real NOT NULL,
	`is_active` integer DEFAULT true NOT NULL,
	`created_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
CREATE TABLE `user_profile` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`height` real DEFAULT 175 NOT NULL,
	`weight` real DEFAULT 70 NOT NULL,
	`age` integer DEFAULT 25 NOT NULL,
	`sex` text DEFAULT 'male' NOT NULL,
	`goal` text DEFAULT 'muscle_gain' NOT NULL,
	`activity_level` text DEFAULT 'moderately_active' NOT NULL,
	`weekly_workout_days` integer DEFAULT 4 NOT NULL,
	`equipment` text DEFAULT '["dumbbells","bodyweight"]' NOT NULL,
	`workout_cycle` text DEFAULT 'ppl' NOT NULL,
	`use_protein_powder` integer DEFAULT true NOT NULL,
	`protein_level` text DEFAULT 'high' NOT NULL,
	`name` text DEFAULT 'Athlete' NOT NULL,
	`updated_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
CREATE TABLE `workout_days` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`plan_id` integer NOT NULL,
	`day_number` integer NOT NULL,
	`day_label` text NOT NULL,
	`is_rest_day` integer DEFAULT false NOT NULL,
	`notes` text DEFAULT '' NOT NULL,
	FOREIGN KEY (`plan_id`) REFERENCES `workout_plans`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `workout_exercises` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`day_id` integer NOT NULL,
	`order_index` integer NOT NULL,
	`name` text NOT NULL,
	`sets` integer NOT NULL,
	`reps_or_time` text NOT NULL,
	`rest_seconds` integer DEFAULT 60 NOT NULL,
	`muscle_group` text DEFAULT '' NOT NULL,
	`equipment` text DEFAULT '' NOT NULL,
	`notes` text DEFAULT '' NOT NULL,
	FOREIGN KEY (`day_id`) REFERENCES `workout_days`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `workout_plans` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`title` text NOT NULL,
	`cycle_type` text NOT NULL,
	`days_per_week` integer NOT NULL,
	`equipment` text DEFAULT '["dumbbells"]' NOT NULL,
	`is_active` integer DEFAULT true NOT NULL,
	`created_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
CREATE TABLE `workout_sessions` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`plan_id` integer NOT NULL,
	`day_id` integer NOT NULL,
	`started_at` text DEFAULT (datetime('now')),
	`completed_at` text,
	`total_duration_seconds` integer,
	FOREIGN KEY (`plan_id`) REFERENCES `workout_plans`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`day_id`) REFERENCES `workout_days`(`id`) ON UPDATE no action ON DELETE cascade
);

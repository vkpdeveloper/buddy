CREATE TABLE `exercise_catalog` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`image` text,
	`description` text NOT NULL,
	`muscle_group` text NOT NULL,
	`equipment` text NOT NULL,
	`category` text NOT NULL,
	`notes` text
);
--> statement-breakpoint
CREATE UNIQUE INDEX `exercise_catalog_name_unique` ON `exercise_catalog` (`name`);--> statement-breakpoint
CREATE TABLE `personal_records` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`exercise_name_normalized` text NOT NULL,
	`exercise_name_display` text NOT NULL,
	`weight_kg` real NOT NULL,
	`reps` integer NOT NULL,
	`achieved_at` text NOT NULL,
	`session_id` integer,
	FOREIGN KEY (`session_id`) REFERENCES `workout_sessions`(`id`) ON UPDATE no action ON DELETE set null
);
--> statement-breakpoint
CREATE UNIQUE INDEX `personal_records_exercise_name_normalized_unique` ON `personal_records` (`exercise_name_normalized`);--> statement-breakpoint
ALTER TABLE `user_profile` ADD `prefer_supersets` integer DEFAULT false;--> statement-breakpoint
ALTER TABLE `workout_exercises` ADD `superset_group_id` integer;--> statement-breakpoint
ALTER TABLE `workout_exercises` ADD `superset_order` integer;
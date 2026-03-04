CREATE TABLE `achievements` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`slug` text NOT NULL,
	`name` text NOT NULL,
	`description` text NOT NULL,
	`xp_reward` integer DEFAULT 0 NOT NULL,
	`icon_name` text DEFAULT 'emoji_events' NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `achievements_slug_unique` ON `achievements` (`slug`);--> statement-breakpoint
CREATE TABLE `user_achievements` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`achievement_id` integer NOT NULL,
	`unlocked_at` text DEFAULT (datetime('now')),
	`session_id` integer,
	FOREIGN KEY (`achievement_id`) REFERENCES `achievements`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`session_id`) REFERENCES `workout_sessions`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE TABLE `user_progress` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`total_xp` integer DEFAULT 0 NOT NULL,
	`current_level` integer DEFAULT 1 NOT NULL,
	`current_streak` integer DEFAULT 0 NOT NULL,
	`longest_streak` integer DEFAULT 0 NOT NULL,
	`last_workout_date` text,
	`total_workouts_completed` integer DEFAULT 0 NOT NULL,
	`updated_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `total_exercises` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `completed_exercises` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `total_rests` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `skipped_rests` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `xp_earned` integer DEFAULT 0 NOT NULL;
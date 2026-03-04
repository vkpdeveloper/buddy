CREATE TABLE `daily_logs` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`date` text NOT NULL,
	`water_ml` integer DEFAULT 0 NOT NULL,
	`sleep_minutes` integer DEFAULT 0 NOT NULL,
	`steps_count` integer DEFAULT 0 NOT NULL,
	`calories_burned` integer DEFAULT 0 NOT NULL,
	`updated_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `daily_logs_date_unique` ON `daily_logs` (`date`);--> statement-breakpoint
CREATE TABLE `diet_meal_logs` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`meal_id` integer NOT NULL,
	`date` text NOT NULL,
	`is_completed` integer DEFAULT false NOT NULL,
	`logged_at` text DEFAULT (datetime('now')),
	FOREIGN KEY (`meal_id`) REFERENCES `diet_meals`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
ALTER TABLE `user_profile` ADD `water_target_ml` integer DEFAULT 2500 NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `weight_goal_kg` real;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `preferred_meals` text DEFAULT '["breakfast","morning_snack","lunch","pre_workout","post_workout","dinner","evening_snack"]' NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `profile_completed` integer DEFAULT false NOT NULL;
DROP INDEX `body_milestones_milestone_key_unique`;--> statement-breakpoint
ALTER TABLE `body_milestones` ADD `user_id` text NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX `body_milestones_user_milestone_unique` ON `body_milestones` (`user_id`,`milestone_key`);--> statement-breakpoint
DROP INDEX `daily_logs_date_unique`;--> statement-breakpoint
ALTER TABLE `daily_logs` ADD `user_id` text NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX `daily_logs_user_date_unique` ON `daily_logs` (`user_id`,`date`);--> statement-breakpoint
DROP INDEX `personal_records_exercise_name_normalized_unique`;--> statement-breakpoint
ALTER TABLE `personal_records` ADD `user_id` text NOT NULL;--> statement-breakpoint
CREATE UNIQUE INDEX `personal_records_user_exercise_unique` ON `personal_records` (`user_id`,`exercise_name_normalized`);--> statement-breakpoint
ALTER TABLE `body_measurements` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `diet_plans` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `generation_jobs` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `progress_photos` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `user_achievements` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `user_progress` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_plans` ADD `user_id` text NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `user_id` text NOT NULL;
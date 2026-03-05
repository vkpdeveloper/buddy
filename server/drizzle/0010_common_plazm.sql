CREATE TABLE `body_milestones` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`milestone_key` text NOT NULL,
	`measurement_id` integer NOT NULL,
	`xp_reward` integer DEFAULT 0 NOT NULL,
	`created_at` text DEFAULT (datetime('now')),
	FOREIGN KEY (`measurement_id`) REFERENCES `body_measurements`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `body_milestones_milestone_key_unique` ON `body_milestones` (`milestone_key`);--> statement-breakpoint
CREATE TABLE `progress_photos` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`date` text NOT NULL,
	`object_key` text NOT NULL,
	`mime_type` text NOT NULL,
	`size_bytes` integer DEFAULT 0 NOT NULL,
	`note` text DEFAULT '' NOT NULL,
	`created_at` text DEFAULT (datetime('now'))
);
--> statement-breakpoint
CREATE UNIQUE INDEX `progress_photos_object_key_unique` ON `progress_photos` (`object_key`);--> statement-breakpoint
ALTER TABLE `body_measurements` ADD `body_fat_percent` real;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `body_fat_goal_percent` real;
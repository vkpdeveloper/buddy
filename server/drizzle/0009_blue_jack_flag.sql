ALTER TABLE `workout_sessions` ADD `paused_duration_seconds` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `warmup_data` text DEFAULT '{}' NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `cooldown_data` text DEFAULT '{}' NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `set_logs` text DEFAULT '[]' NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `session_notes` text DEFAULT '[]' NOT NULL;--> statement-breakpoint
ALTER TABLE `workout_sessions` ADD `hr_snapshots` text DEFAULT '[]' NOT NULL;
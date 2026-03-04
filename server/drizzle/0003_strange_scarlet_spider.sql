CREATE TABLE `body_measurements` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`date` text NOT NULL,
	`weight_kg` real,
	`chest_cm` real,
	`waist_cm` real,
	`hips_cm` real,
	`arms_cm` real,
	`thighs_cm` real,
	`notes` text DEFAULT '' NOT NULL,
	`xp_earned` integer DEFAULT 0 NOT NULL,
	`created_at` text DEFAULT (datetime('now'))
);

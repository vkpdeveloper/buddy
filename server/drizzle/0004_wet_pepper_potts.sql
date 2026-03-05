ALTER TABLE `user_profile` ADD `diet_type` text DEFAULT 'vegetarian' NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `meal_prep_time` text DEFAULT '30min' NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `cooking_by` text DEFAULT 'myself' NOT NULL;--> statement-breakpoint
ALTER TABLE `user_profile` ADD `preferred_foods` text DEFAULT '[]' NOT NULL;
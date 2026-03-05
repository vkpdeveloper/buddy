ALTER TABLE `diet_meal_logs` ADD `actual_meal_name` text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `actual_calories` integer;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `actual_protein_g` real;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `actual_carbs_g` real;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `actual_fat_g` real;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `actual_notes` text DEFAULT '' NOT NULL;--> statement-breakpoint
ALTER TABLE `diet_meal_logs` ADD `raw_payload` text DEFAULT '{}' NOT NULL;--> statement-breakpoint
ALTER TABLE `diet_meals` ADD `order_index` integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE `diet_meals` ADD `meal_time` text DEFAULT '08:00' NOT NULL;
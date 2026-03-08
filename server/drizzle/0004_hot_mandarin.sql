ALTER TABLE "user_profile" ALTER COLUMN "equipment" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "equipment" SET DATA TYPE jsonb USING equipment::jsonb;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "equipment" SET DEFAULT '["dumbbells","bodyweight"]'::jsonb;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_meals" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_meals" SET DATA TYPE jsonb USING preferred_meals::jsonb;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_meals" SET DEFAULT '["breakfast","morning_snack","lunch","pre_workout","post_workout","dinner","evening_snack"]'::jsonb;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_foods" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_foods" SET DATA TYPE jsonb USING preferred_foods::jsonb;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "preferred_foods" SET DEFAULT '[]'::jsonb;--> statement-breakpoint
ALTER TABLE "workout_plans" ALTER COLUMN "equipment" DROP DEFAULT;--> statement-breakpoint
ALTER TABLE "workout_plans" ALTER COLUMN "equipment" SET DATA TYPE jsonb USING equipment::jsonb;--> statement-breakpoint
ALTER TABLE "workout_plans" ALTER COLUMN "equipment" SET DEFAULT '["dumbbells"]'::jsonb;
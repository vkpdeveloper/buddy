ALTER TABLE "generation_jobs" ADD COLUMN "stage_key" text DEFAULT 'queued' NOT NULL;--> statement-breakpoint
ALTER TABLE "generation_jobs" ADD COLUMN "stage_message" text DEFAULT 'Queued to build your plan.' NOT NULL;--> statement-breakpoint
ALTER TABLE "generation_jobs" ADD COLUMN "progress_percent" integer DEFAULT 0 NOT NULL;--> statement-breakpoint
ALTER TABLE "user_profile" ADD COLUMN "why_now" text;--> statement-breakpoint
ALTER TABLE "user_profile" ADD COLUMN "goal_pace" text;--> statement-breakpoint
ALTER TABLE "user_profile" ADD COLUMN "primary_blocker" text;
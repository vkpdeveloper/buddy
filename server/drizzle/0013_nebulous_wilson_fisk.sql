CREATE TABLE "buddy_pending_actions" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"action_type" text NOT NULL,
	"status" text DEFAULT 'pending' NOT NULL,
	"title" text DEFAULT '' NOT NULL,
	"summary" text DEFAULT '' NOT NULL,
	"confirm_label" text DEFAULT 'Approve' NOT NULL,
	"cancel_label" text DEFAULT 'Cancel' NOT NULL,
	"refresh_domains" jsonb DEFAULT '[]'::jsonb NOT NULL,
	"payload" jsonb DEFAULT '{}'::jsonb NOT NULL,
	"result" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	"confirmed_at" timestamp,
	"cancelled_at" timestamp
);
--> statement-breakpoint
CREATE TABLE "diet_meal_overrides" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"meal_id" integer NOT NULL,
	"date" text NOT NULL,
	"meal_type" text NOT NULL,
	"meal_time" text DEFAULT '08:00' NOT NULL,
	"meal_name" text NOT NULL,
	"description" text DEFAULT '' NOT NULL,
	"ingredients" text DEFAULT '[]' NOT NULL,
	"recipe" text DEFAULT '' NOT NULL,
	"calories" integer NOT NULL,
	"protein_g" real NOT NULL,
	"carbs_g" real NOT NULL,
	"fat_g" real NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"created_at" text DEFAULT now(),
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
ALTER TABLE "user_profile" ADD COLUMN "timezone_iana" text DEFAULT 'UTC' NOT NULL;--> statement-breakpoint
ALTER TABLE "buddy_pending_actions" ADD CONSTRAINT "buddy_pending_actions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_meal_overrides" ADD CONSTRAINT "diet_meal_overrides_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_meal_overrides" ADD CONSTRAINT "diet_meal_overrides_meal_id_diet_meals_id_fk" FOREIGN KEY ("meal_id") REFERENCES "public"."diet_meals"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "buddy_pending_actions_user_id_idx" ON "buddy_pending_actions" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "buddy_pending_actions_user_id_status_idx" ON "buddy_pending_actions" USING btree ("user_id","status");--> statement-breakpoint
CREATE UNIQUE INDEX "diet_meal_overrides_user_meal_date_unique" ON "diet_meal_overrides" USING btree ("user_id","meal_id","date");--> statement-breakpoint
CREATE INDEX "diet_meal_overrides_user_id_date_idx" ON "diet_meal_overrides" USING btree ("user_id","date");--> statement-breakpoint
CREATE UNIQUE INDEX "body_measurements_user_date_unique" ON "body_measurements" USING btree ("user_id","date");
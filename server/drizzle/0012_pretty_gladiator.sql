CREATE TABLE "user_targets" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" integer NOT NULL,
	"daily_steps" integer DEFAULT 10000 NOT NULL,
	"daily_sleep_target" real DEFAULT 7 NOT NULL,
	"daily_water_ml" integer DEFAULT 2500 NOT NULL,
	"target_weight" real,
	"daily_calorie_burn" integer DEFAULT 500 NOT NULL,
	"updated_at" text DEFAULT now()
);
--> statement-breakpoint
ALTER TABLE "user_targets" ADD CONSTRAINT "user_targets_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE UNIQUE INDEX "user_targets_user_id_unique" ON "user_targets" USING btree ("user_id");
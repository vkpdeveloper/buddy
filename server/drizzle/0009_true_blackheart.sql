-- Migrate user_id from text (Firebase UID) to integer (users.id FK) for all data tables.
-- Each table: add integer column → populate via UPDATE JOIN → NOT NULL → drop old → rename.

-- body_measurements
ALTER TABLE "body_measurements" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "body_measurements" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "body_measurements" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "body_measurements" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "body_measurements" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- body_milestones
ALTER TABLE "body_milestones" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "body_milestones" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "body_milestones" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "body_milestones" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "body_milestones" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- daily_logs
ALTER TABLE "daily_logs" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "daily_logs" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "daily_logs" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "daily_logs" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "daily_logs" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- diet_plans (must come before diet_meal_logs population)
ALTER TABLE "diet_plans" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "diet_plans" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "diet_plans" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "diet_plans" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "diet_plans" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- diet_quick_logs
ALTER TABLE "diet_quick_logs" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "diet_quick_logs" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "diet_quick_logs" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "diet_quick_logs" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "diet_quick_logs" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- generation_jobs
ALTER TABLE "generation_jobs" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "generation_jobs" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "generation_jobs" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "generation_jobs" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "generation_jobs" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- meal_media_attachments
ALTER TABLE "meal_media_attachments" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "meal_media_attachments" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "meal_media_attachments" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "meal_media_attachments" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "meal_media_attachments" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- personal_records
ALTER TABLE "personal_records" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "personal_records" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "personal_records" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "personal_records" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "personal_records" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- progress_photos
ALTER TABLE "progress_photos" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "progress_photos" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "progress_photos" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "progress_photos" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "progress_photos" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- user_achievements
ALTER TABLE "user_achievements" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "user_achievements" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "user_achievements" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "user_achievements" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "user_achievements" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- user_profile
ALTER TABLE "user_profile" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "user_profile" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "user_profile" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "user_profile" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "user_profile" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- user_progress
ALTER TABLE "user_progress" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "user_progress" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "user_progress" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "user_progress" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "user_progress" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- workout_plans
ALTER TABLE "workout_plans" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "workout_plans" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "workout_plans" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "workout_plans" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "workout_plans" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- workout_sessions
ALTER TABLE "workout_sessions" ADD COLUMN "user_id_int" integer;--> statement-breakpoint
UPDATE "workout_sessions" t SET "user_id_int" = u.id FROM "users" u WHERE u.firebase_uid = t.user_id;--> statement-breakpoint
ALTER TABLE "workout_sessions" ALTER COLUMN "user_id_int" SET NOT NULL;--> statement-breakpoint
ALTER TABLE "workout_sessions" DROP COLUMN "user_id";--> statement-breakpoint
ALTER TABLE "workout_sessions" RENAME COLUMN "user_id_int" TO "user_id";--> statement-breakpoint

-- diet_meal_logs: new user_id column (populated via meal → day → plan chain)
ALTER TABLE "diet_meal_logs" ADD COLUMN "user_id" integer;--> statement-breakpoint
UPDATE "diet_meal_logs" dml
SET user_id = dp.user_id
FROM "diet_meals" dm
JOIN "diet_days" dd ON dd.id = dm.day_id
JOIN "diet_plans" dp ON dp.id = dd.plan_id
WHERE dm.id = dml.meal_id;--> statement-breakpoint
ALTER TABLE "diet_meal_logs" ALTER COLUMN "user_id" SET NOT NULL;--> statement-breakpoint

-- Foreign key constraints
ALTER TABLE "body_measurements" ADD CONSTRAINT "body_measurements_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "body_milestones" ADD CONSTRAINT "body_milestones_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "daily_logs" ADD CONSTRAINT "daily_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_meal_logs" ADD CONSTRAINT "diet_meal_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_plans" ADD CONSTRAINT "diet_plans_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "diet_quick_logs" ADD CONSTRAINT "diet_quick_logs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "generation_jobs" ADD CONSTRAINT "generation_jobs_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "meal_media_attachments" ADD CONSTRAINT "meal_media_attachments_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "personal_records" ADD CONSTRAINT "personal_records_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "progress_photos" ADD CONSTRAINT "progress_photos_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_achievements" ADD CONSTRAINT "user_achievements_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_profile" ADD CONSTRAINT "user_profile_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "user_progress" ADD CONSTRAINT "user_progress_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_plans" ADD CONSTRAINT "workout_plans_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "workout_sessions" ADD CONSTRAINT "workout_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint

-- Composite indexes
CREATE INDEX "body_measurements_user_id_date_idx" ON "body_measurements" USING btree ("user_id","date");--> statement-breakpoint
CREATE INDEX "diet_meal_logs_meal_id_date_idx" ON "diet_meal_logs" USING btree ("meal_id","date");--> statement-breakpoint
CREATE INDEX "diet_meal_logs_user_id_date_idx" ON "diet_meal_logs" USING btree ("user_id","date");--> statement-breakpoint
CREATE INDEX "diet_plans_user_id_is_active_idx" ON "diet_plans" USING btree ("user_id","is_active");--> statement-breakpoint
CREATE INDEX "generation_jobs_user_id_type_idx" ON "generation_jobs" USING btree ("user_id","type");--> statement-breakpoint
CREATE INDEX "workout_plans_user_id_is_active_idx" ON "workout_plans" USING btree ("user_id","is_active");--> statement-breakpoint
CREATE INDEX "workout_sessions_user_id_completed_at_idx" ON "workout_sessions" USING btree ("user_id","completed_at");

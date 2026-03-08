CREATE INDEX "body_measurements_user_id_idx" ON "body_measurements" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "body_milestones_user_id_idx" ON "body_milestones" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "daily_logs_user_id_idx" ON "daily_logs" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "diet_plans_user_id_idx" ON "diet_plans" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "diet_quick_logs_user_id_idx" ON "diet_quick_logs" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "generation_jobs_user_id_idx" ON "generation_jobs" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "meal_media_attachments_user_id_idx" ON "meal_media_attachments" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "personal_records_user_id_idx" ON "personal_records" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "progress_photos_user_id_idx" ON "progress_photos" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "user_achievements_user_id_idx" ON "user_achievements" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "user_profile_user_id_idx" ON "user_profile" USING btree ("user_id");--> statement-breakpoint
CREATE UNIQUE INDEX "user_progress_user_id_unique" ON "user_progress" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "workout_plans_user_id_idx" ON "workout_plans" USING btree ("user_id");--> statement-breakpoint
CREATE INDEX "workout_sessions_user_id_idx" ON "workout_sessions" USING btree ("user_id");
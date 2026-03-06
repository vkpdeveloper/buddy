CREATE TABLE "diet_quick_logs" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"date" text NOT NULL,
	"meal_name" text NOT NULL,
	"calories" integer DEFAULT 0 NOT NULL,
	"protein_g" real DEFAULT 0 NOT NULL,
	"carbs_g" real DEFAULT 0 NOT NULL,
	"fat_g" real DEFAULT 0 NOT NULL,
	"notes" text DEFAULT '' NOT NULL,
	"attachment_id" integer,
	"logged_at" text DEFAULT now()
);
--> statement-breakpoint
ALTER TABLE "diet_quick_logs" ADD CONSTRAINT "diet_quick_logs_attachment_id_meal_media_attachments_id_fk" FOREIGN KEY ("attachment_id") REFERENCES "public"."meal_media_attachments"("id") ON DELETE set null ON UPDATE no action;
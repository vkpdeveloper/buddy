CREATE TABLE "meal_media_attachments" (
	"id" serial PRIMARY KEY NOT NULL,
	"user_id" text NOT NULL,
	"object_key" text NOT NULL,
	"mime_type" text NOT NULL,
	"size_bytes" integer NOT NULL,
	"ai_analysis_status" text DEFAULT 'pending' NOT NULL,
	"ai_analysis_result" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL
);

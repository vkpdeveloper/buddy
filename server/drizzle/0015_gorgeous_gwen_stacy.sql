CREATE TABLE "buddy_chat_message_attachments" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"message_id" uuid NOT NULL,
	"kind" text NOT NULL,
	"meal_media_attachment_id" integer,
	"sort_order" integer DEFAULT 0 NOT NULL,
	"metadata" jsonb,
	"created_at" timestamp DEFAULT now() NOT NULL
);
--> statement-breakpoint
CREATE TABLE "buddy_chat_messages" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"session_id" uuid NOT NULL,
	"display_role" text,
	"sdk_role" text NOT NULL,
	"message" text,
	"parts" jsonb NOT NULL,
	"model" text,
	"tokens" integer,
	"token_count_status" text DEFAULT 'unknown' NOT NULL,
	"sent_at" timestamp DEFAULT now() NOT NULL,
	"is_visible" boolean DEFAULT true NOT NULL
);
--> statement-breakpoint
CREATE TABLE "buddy_chat_sessions" (
	"id" uuid PRIMARY KEY DEFAULT gen_random_uuid() NOT NULL,
	"user_id" integer NOT NULL,
	"title" text DEFAULT 'New Session' NOT NULL,
	"is_pinned" boolean DEFAULT false NOT NULL,
	"created_at" timestamp DEFAULT now() NOT NULL,
	"updated_at" timestamp DEFAULT now() NOT NULL,
	"activity_at" timestamp DEFAULT now() NOT NULL,
	"last_message_preview" text,
	"last_message_role" text,
	"pending_approval" jsonb
);
--> statement-breakpoint
ALTER TABLE "buddy_chat_message_attachments" ADD CONSTRAINT "buddy_chat_message_attachments_message_id_buddy_chat_messages_id_fk" FOREIGN KEY ("message_id") REFERENCES "public"."buddy_chat_messages"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "buddy_chat_message_attachments" ADD CONSTRAINT "buddy_chat_message_attachments_meal_media_attachment_id_meal_media_attachments_id_fk" FOREIGN KEY ("meal_media_attachment_id") REFERENCES "public"."meal_media_attachments"("id") ON DELETE set null ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "buddy_chat_messages" ADD CONSTRAINT "buddy_chat_messages_session_id_buddy_chat_sessions_id_fk" FOREIGN KEY ("session_id") REFERENCES "public"."buddy_chat_sessions"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
ALTER TABLE "buddy_chat_sessions" ADD CONSTRAINT "buddy_chat_sessions_user_id_users_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("id") ON DELETE cascade ON UPDATE no action;--> statement-breakpoint
CREATE INDEX "buddy_chat_message_attachments_message_sort_idx" ON "buddy_chat_message_attachments" USING btree ("message_id","sort_order");--> statement-breakpoint
CREATE INDEX "buddy_chat_message_attachments_meal_media_idx" ON "buddy_chat_message_attachments" USING btree ("meal_media_attachment_id");--> statement-breakpoint
CREATE INDEX "buddy_chat_messages_session_sent_idx" ON "buddy_chat_messages" USING btree ("session_id","sent_at","id");--> statement-breakpoint
CREATE INDEX "buddy_chat_messages_visible_session_sent_idx" ON "buddy_chat_messages" USING btree ("session_id","is_visible","sent_at","id");--> statement-breakpoint
CREATE INDEX "buddy_chat_sessions_user_sort_idx" ON "buddy_chat_sessions" USING btree ("user_id","is_pinned" DESC NULLS LAST,"activity_at" DESC NULLS LAST,"created_at" DESC NULLS LAST);--> statement-breakpoint
CREATE INDEX "buddy_chat_sessions_user_activity_idx" ON "buddy_chat_sessions" USING btree ("user_id","activity_at" DESC NULLS LAST);
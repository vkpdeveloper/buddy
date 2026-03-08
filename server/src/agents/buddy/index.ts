import { Hono } from 'hono';
import { streamSSE } from 'hono/streaming';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { stepCountIs, streamText } from 'ai';
import { eq } from 'drizzle-orm';
import { db } from '../../db';
import { userProfile, users } from '../../db/schema';
import { env } from '../../lib/env';
import { buildBuddySystemPrompt } from './system_prompt';
import { createBuddyTools } from './tools/index';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const router = new Hono();

const chatSchema = z.object({
    messages: z.array(
        z.object({
            role: z.enum(['user', 'assistant']),
            content: z.string().min(1),
        })
    ).min(1),
});

// ─── POST /api/buddy/chat ─────────────────────────────────────────────────────

router.post('/chat', zValidator('json', chatSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const { messages } = c.req.valid('json');

        const [profile] = await db.select({ name: users.name }).from(users).where(eq(users.firebaseUid, userId)).limit(1);
        const firstName = profile.name;

        const systemPrompt = buildBuddySystemPrompt(firstName);
        const tools = createBuddyTools(userId);

        return streamSSE(c, async (stream) => {
            try {
                const toolLabels: Record<string, string> = {
                    getUserProfile: 'Pulling up your profile...',
                    getTodayWorkout: 'Checking today\'s training...',
                    getTodayDiet: 'Looking at what\'s on your plate today...',
                    getFullWorkoutPlan: 'Going through your workout program...',
                    getFullDietPlan: 'Looking through your nutrition plan...',
                    getRecentSessions: 'Checking your recent training sessions...',
                    getUserProgress: 'Looking at how you\'ve been tracking...',
                };

                const result = streamText({
                    model: google('gemini-3.1-flash-lite-preview'),
                    system: systemPrompt,
                    messages,
                    tools,
                    // Stop as soon as the model produces text (i.e. it has an answer),
                    // not just tool calls. stepCountIs(10) is a hard safety cap.
                    stopWhen: [
                        ({ steps }) => {
                            const last = steps[steps.length - 1];
                            return (last?.text?.trim().length ?? 0) > 0;
                        },
                        stepCountIs(10),
                    ],
                });

                for await (const event of result.fullStream) {
                    if (event.type === 'text-delta' && event.text) {
                        await stream.writeSSE({ event: 'text', data: JSON.stringify(event.text) });
                    } else if (event.type === 'tool-call') {
                        const label = toolLabels[event.toolName] ?? 'On it...';
                        await stream.writeSSE({ event: 'tool', data: JSON.stringify(label) });
                    }
                }

                await stream.writeSSE({ data: '[DONE]' });
            } catch (streamErr) {
                console.error('[buddy/chat] stream error:', streamErr);
                await stream.writeSSE({ data: '[ERROR]' });
            }
        });
    } catch (err) {
        console.error('[buddy/chat] error:', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

export default router;

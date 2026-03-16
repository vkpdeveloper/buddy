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
import { fail } from '../../lib/response';
import { buildBuddySystemPrompt } from './system_prompt';
import { createBuddyTools } from './tools/index';
import { trackAiUsage, AI_FEATURE } from '../../lib/aiUsageTracker';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });
const router = new Hono();

const chatSchema = z.object({
    messages: z.array(z.record(z.string(), z.unknown())).min(1),
});

type ApprovalPreview = {
    title: string;
    summary: string;
    confirmLabel: string;
    cancelLabel: string;
};

function isImmediateWriteOutput(value: unknown): value is {
    kind: 'immediate_write';
    message: string;
    refreshDomains: unknown;
} {
    return Boolean(
        value &&
        typeof value === 'object' &&
        'kind' in value &&
        (value as { kind?: unknown }).kind === 'immediate_write' &&
        'message' in value &&
        'refreshDomains' in value,
    );
}

function formatMacros(input: Record<string, unknown>) {
    const calories = Number(input.calories ?? 0);
    const proteinG = Number(input.proteinG ?? 0);
    const carbsG = Number(input.carbsG ?? 0);
    const fatG = Number(input.fatG ?? 0);
    return `${Math.round(calories)} kcal · ${Math.round(proteinG)}P / ${Math.round(carbsG)}C / ${Math.round(fatG)}F`;
}

function formatWeightTarget(input: unknown) {
    if (!input || typeof input !== 'object') return null;
    const value = Number((input as { value?: unknown }).value);
    const unit = (input as { unit?: unknown }).unit;
    if (!Number.isFinite(value) || (unit !== 'kg' && unit !== 'lb')) {
        return null;
    }
    return `Target weight ${value.toFixed(1)} ${unit}`;
}

function formatDailyWater(input: unknown) {
    if (!input || typeof input !== 'object') return null;
    const value = Number((input as { value?: unknown }).value);
    const unit = (input as { unit?: unknown }).unit;
    if (!Number.isFinite(value) || (unit !== 'ml' && unit !== 'liter')) {
        return null;
    }
    return `${value} ${unit}`;
}

function buildApprovalPreview(toolName: string, input: Record<string, unknown>): ApprovalPreview {
    switch (toolName) {
        case 'updateBodyGoals':
            return {
                title: 'Approve body goal update?',
                summary: [
                    formatWeightTarget(input.weightGoal),
                    input.bodyFatGoalPercent != null ? `Body fat ${Number(input.bodyFatGoalPercent)}%` : null,
                ].filter(Boolean).join(' · '),
                confirmLabel: 'Update goals',
                cancelLabel: 'Not now',
            };
        case 'updateDailyTargets':
            return {
                title: 'Approve daily target update?',
                summary: [
                    input.dailySteps != null ? `${input.dailySteps} steps` : null,
                    input.dailySleepHours != null ? `${input.dailySleepHours} hrs sleep` : null,
                    input.dailySleepTarget != null ? `${input.dailySleepTarget} hrs sleep` : null,
                    formatDailyWater(input.dailyWater),
                    input.dailyWaterMl != null ? `${input.dailyWaterMl} ml water` : null,
                    input.dailyCalorieBurn != null ? `${input.dailyCalorieBurn} kcal burn` : null,
                    formatWeightTarget(input.targetWeight),
                ].filter(Boolean).join(' · '),
                confirmLabel: 'Update targets',
                cancelLabel: 'Not now',
            };
        case 'replaceDietMeal':
            return {
                title: `Approve ${String(input.mealType ?? 'meal')} swap?`,
                summary: [String(input.mealName ?? 'Meal'), formatMacros(input)].join(' · '),
                confirmLabel: 'Replace meal',
                cancelLabel: 'Keep current',
            };
        case 'logMealPhoto':
            return {
                title: input.mode === 'actual'
                    ? `Approve logging this photo as ${String(input.mealType ?? 'planned meal')}?`
                    : 'Approve meal photo log?',
                summary: [String(input.mealName ?? 'Meal photo'), formatMacros(input)].join(' · '),
                confirmLabel: 'Log meal',
                cancelLabel: 'Not now',
            };
        case 'logWorkoutSummary':
            return {
                title: 'Approve workout log?',
                summary: [
                    input.durationMinutes != null
                        ? `${Math.round(Number(input.durationMinutes))} mins`
                        : input.durationSeconds != null
                            ? `${Math.round(Number(input.durationSeconds) / 60)} mins`
                            : null,
                    input.completedExerciseCount != null ? `${input.completedExerciseCount} exercises` : null,
                ].filter(Boolean).join(' · '),
                confirmLabel: 'Log workout',
                cancelLabel: 'Not now',
            };
        default:
            return {
                title: 'Approve this change?',
                summary: '',
                confirmLabel: 'Approve',
                cancelLabel: 'Cancel',
            };
    }
}

// ─── POST /api/buddy/chat ─────────────────────────────────────────────────────

router.post('/chat', zValidator('json', chatSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const { messages } = c.req.valid('json');

        const [profile] = await db
            .select({
                name: users.name,
                timezoneIana: userProfile.timezoneIana,
            })
            .from(users)
            .leftJoin(userProfile, eq(userProfile.userId, users.id))
            .where(eq(users.id, userId))
            .limit(1);

        const firstName = profile?.name ?? null;
        const timeZone = c.var.timeZone !== 'UTC'
            ? c.var.timeZone
            : (profile?.timezoneIana ?? 'UTC');

        const systemPrompt = buildBuddySystemPrompt(firstName, timeZone);
        const tools = createBuddyTools(userId, timeZone);

        return streamSSE(c, async (stream) => {
            try {
                const toolLabels: Record<string, string> = {
                    getUserProfile: 'Pulling up your profile...',
                    getTodayDiet: 'Checking today\'s meals...',
                    getDietMealSlot: 'Looking at that meal slot...',
                    getTodayWorkout: 'Checking today\'s training...',
                    getWorkoutLoggingContext: 'Checking your workout log...',
                    getFullWorkoutPlan: 'Going through your workout program...',
                    getFullDietPlan: 'Looking through your nutrition plan...',
                    getRecentSessions: 'Checking your recent training sessions...',
                    getUserProgress: 'Looking at your progress...',
                    getTodayDailyLog: 'Checking today\'s health log...',
                    getUserTargets: 'Checking your targets...',
                    getMealPhotoAttachment: 'Reviewing the meal photo...',
                    logBodyProgress: 'Saving your body progress...',
                    updateDailyHealthLog: 'Updating your daily log...',
                    logDetailedWorkout: 'Logging your workout...',
                    updateBodyGoals: 'Preparing your goal update...',
                    updateDailyTargets: 'Preparing your target update...',
                    replaceDietMeal: 'Preparing your meal swap...',
                    logMealPhoto: 'Preparing your meal photo log...',
                    logWorkoutSummary: 'Preparing your workout log...',
                };

                const buddyModel = 'gemini-3.1-flash-lite-preview';
                const result = streamText({
                    model: google(buddyModel),
                    system: systemPrompt,
                    messages: messages as any,
                    tools,
                    stopWhen: [
                        ({ steps }) => {
                            const last = steps[steps.length - 1];
                            return (last?.text?.trim().length ?? 0) > 0;
                        },
                        stepCountIs(10),
                    ],
                });

                let sawAssistantText = false;
                const fallbackMessages: string[] = [];

                for await (const event of result.fullStream) {
                    if (event.type === 'text-delta' && event.text) {
                        sawAssistantText = true;
                        await stream.writeSSE({ event: 'text', data: JSON.stringify(event.text) });
                        continue;
                    }

                    if (event.type === 'tool-call') {
                        const label = toolLabels[event.toolName] ?? 'On it...';
                        await stream.writeSSE({ event: 'tool', data: JSON.stringify(label) });
                        continue;
                    }

                    if (event.type === 'tool-approval-request') {
                        const preview = buildApprovalPreview(
                            event.toolCall.toolName,
                            event.toolCall.input as Record<string, unknown>,
                        );
                        await stream.writeSSE({
                            event: 'approval',
                            data: JSON.stringify({
                                approvalId: event.approvalId,
                                toolCall: event.toolCall,
                                ...preview,
                            }),
                        });
                        continue;
                    }

                    if (event.type === 'tool-result' && !event.preliminary) {
                        if (isImmediateWriteOutput(event.output)) {
                            fallbackMessages.push(event.output.message);
                            await stream.writeSSE({
                                event: 'refresh',
                                data: JSON.stringify(event.output.refreshDomains),
                            });
                        }
                    }
                }

                if (!sawAssistantText && fallbackMessages.length > 0) {
                    await stream.writeSSE({
                        event: 'text',
                        data: JSON.stringify(fallbackMessages.join('\n\n')),
                    });
                }

                const usage = await result.usage;
                await trackAiUsage({ model: buddyModel, feature: AI_FEATURE.BUDDY_CHAT, userId, usage });

                await stream.writeSSE({ data: '[DONE]' });
            } catch (streamErr) {
                console.error('[buddy/chat] stream error:', streamErr);
                await stream.writeSSE({ data: '[ERROR]' });
            }
        });
    } catch (err) {
        console.error('[buddy/chat] error:', err);
        return fail(c, String(err), 500);
    }
});

export default router;

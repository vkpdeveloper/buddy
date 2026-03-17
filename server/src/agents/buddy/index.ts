import { Hono } from 'hono';
import { streamSSE } from 'hono/streaming';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import { GoogleGenAI } from '@google/genai';
import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateText, stepCountIs, streamText, type ModelMessage } from 'ai';
import { eq } from 'drizzle-orm';
import { db } from '../../db';
import { userProfile, users } from '../../db/schema';
import { env } from '../../lib/env';
import { badRequest } from '../../lib/errors';
import { fail, ok } from '../../lib/response';
import { buildBuddySystemPrompt } from './system_prompt';
import { createBuddyTools } from './tools/index';
import { trackAiUsage, AI_FEATURE } from '../../lib/aiUsageTracker';
import {
    BUDDY_CHAT_MODEL,
    BUDDY_TITLE_MODEL,
    DEFAULT_BUDDY_SESSION_TITLE,
    MEAL_PHOTO_SESSION_TITLE,
    createBuddySession,
    deleteBuddySession,
    getBuddySessionDetail,
    getBuddySessionRow,
    getStoredBuddyMessages,
    insertBuddyMessage,
    insertBuddyMessageAttachments,
    listBuddySessions,
    mapBuddySessionSummary,
    type PendingApprovalPayload,
    updateBuddyMessageTokens,
    updateBuddySession,
    updateBuddySessionRuntime,
    updateBuddySessionTitleIfDefault,
    validateBuddyAttachmentIds,
} from '../../services/buddySessions';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });
const genAi = new GoogleGenAI({ apiKey: env.GEMINI_API_KEY });
const router = new Hono();

const legacyChatSchema = z.object({
    messages: z.array(z.record(z.string(), z.unknown())).min(1),
});

const sessionPatchSchema = z.object({
    title: z.string().trim().min(1).max(120).optional(),
    isPinned: z.boolean().optional(),
}).refine(
    (input) => input.title !== undefined || input.isPinned !== undefined,
    { message: 'At least one field must be provided.' },
);

const sessionChatSchema = z.object({
    input: z.discriminatedUnion('kind', [
        z.object({
            kind: z.literal('user'),
            text: z.string(),
            attachmentIds: z.array(z.number().int().positive()).max(4).optional(),
        }),
        z.object({
            kind: z.literal('approval'),
            approvalId: z.string().min(1),
            approved: z.boolean(),
        }),
    ]),
});

type ApprovalPreview = {
    title: string;
    summary: string;
    confirmLabel: string;
    cancelLabel: string;
};

type SessionMetaEvent = {
    sessionId: string;
    title: string;
};

type StreamOutcome = {
    assistantText: string;
    approvalRequest: PendingApprovalPayload | null;
    sawApprovalOrRefreshEvent: boolean;
    usage: Awaited<ReturnType<typeof Promise.resolve<Record<string, unknown>>>> & {
        promptTokens?: number;
        completionTokens?: number;
        inputTokens?: number;
        outputTokens?: number;
        totalTokens?: number;
    };
};

type ChatInput = z.infer<typeof sessionChatSchema>['input'];

function isRecord(value: unknown): value is Record<string, unknown> {
    return typeof value === 'object' && value !== null;
}

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

function hasLoggedQuickMeal(value: unknown): value is { loggedQuickMeal: unknown } {
    return Boolean(
        value &&
        typeof value === 'object' &&
        'loggedQuickMeal' in value &&
        (value as { loggedQuickMeal?: unknown }).loggedQuickMeal,
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

function normalizeGeneratedTitle(raw: string, fallback: string) {
    const cleaned = raw
        .replace(/[`"#*_]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    const candidate = cleaned.length > 0 ? cleaned : fallback;
    const limitedWords = candidate.split(' ').filter(Boolean).slice(0, 5);
    if (limitedWords.length === 0) {
        return fallback;
    }

    return limitedWords
        .map((word) => `${word.slice(0, 1).toUpperCase()}${word.slice(1).toLowerCase()}`)
        .join(' ');
}

function fallbackTitleFromText(text: string) {
    const words = text.trim().split(/\s+/).filter(Boolean).slice(0, 5);
    if (words.length === 0) {
        return DEFAULT_BUDDY_SESSION_TITLE;
    }
    return words
        .map((word) => `${word.slice(0, 1).toUpperCase()}${word.slice(1).toLowerCase()}`)
        .join(' ');
}

function buildUserModelContent(text: string, attachmentIds: number[]) {
    const trimmed = text.trim();
    if (attachmentIds.length === 0) {
        return trimmed;
    }

    const baseText = trimmed.length === 0
        ? 'Please inspect this meal photo.'
        : trimmed;
    const attachmentInstructions = attachmentIds.map(
        (attachmentId) =>
            `[User attached a meal photo. attachmentId=${attachmentId}. Call getMealPhotoAttachment with this attachmentId when you need to inspect the uploaded meal photo.]`,
    );

    return `${baseText}\n\n${attachmentInstructions.join('\n')}`;
}

function buildUserPreview(text: string, attachmentIds: number[]) {
    const trimmed = text.trim();
    if (trimmed.length > 0) {
        return trimmed;
    }
    return attachmentIds.length > 0 ? 'Meal photo' : '';
}

function buildAssistantPreview(
    assistantText: string,
    approvalRequest: PendingApprovalPayload | null,
) {
    const trimmed = assistantText.trim();
    if (trimmed.length > 0) {
        return trimmed;
    }
    if (approvalRequest != null) {
        return 'Approval needed';
    }
    return null;
}

function extractCountableContent(parts: unknown): string | null {
    if (typeof parts === 'string') {
        return parts;
    }

    if (!Array.isArray(parts)) {
        return null;
    }

    const textSegments = parts.flatMap((part) => {
        if (!part || typeof part !== 'object') {
            return [];
        }

        if ('text' in part && typeof part.text === 'string') {
            return [part.text];
        }

        return [];
    });

    return textSegments.length > 0 ? textSegments.join('\n\n') : null;
}

function normalizeStoredAssistantContent(parts: unknown) {
    if (!Array.isArray(parts)) {
        return parts;
    }

    const normalizedParts: unknown[] = [];
    const seenToolCallIds = new Set<string>();

    for (const part of parts) {
        if (
            isRecord(part) &&
            part.type === 'tool-call' &&
            typeof part.toolCallId === 'string'
        ) {
            seenToolCallIds.add(part.toolCallId);
            // Ensure providerOptions mirrors providerMetadata so Gemini thinking models
            // can find the thoughtSignature when replaying conversation history.
            const enrichedPart =
                part.providerMetadata != null && part.providerOptions == null
                    ? { ...part, providerOptions: part.providerMetadata }
                    : part;
            normalizedParts.push(enrichedPart);
            continue;
        }

        if (
            !isRecord(part) ||
            part.type !== 'tool-approval-request' ||
            typeof part.approvalId !== 'string'
        ) {
            normalizedParts.push(part);
            continue;
        }

        if (typeof part.toolCallId === 'string') {
            normalizedParts.push(part);
            continue;
        }

        const toolCall = isRecord(part.toolCall) ? part.toolCall : null;
        const toolCallId = typeof toolCall?.toolCallId === 'string'
            ? toolCall.toolCallId
            : null;
        const toolName = typeof toolCall?.toolName === 'string'
            ? toolCall.toolName
            : null;
        const toolInput = isRecord(toolCall?.input) ? toolCall.input : null;
        const toolProviderMetadata = toolCall?.providerMetadata;

        if (toolCallId == null) {
            normalizedParts.push(part);
            continue;
        }

        if (
            toolName != null &&
            toolInput != null &&
            !seenToolCallIds.has(toolCallId)
        ) {
            normalizedParts.push({
                type: 'tool-call',
                toolCallId,
                toolName,
                input: toolInput,
                ...(toolProviderMetadata != null
                    ? {
                        providerMetadata: toolProviderMetadata,
                        providerOptions: toolProviderMetadata,
                    }
                    : {}),
            });
            seenToolCallIds.add(toolCallId);
        }

        normalizedParts.push({
            type: 'tool-approval-request',
            approvalId: part.approvalId,
            toolCallId,
        });
    }

    return normalizedParts;
}

function buildStoredModelMessages(
    storedMessages: Array<{
        sdkRole: 'user' | 'assistant' | 'tool';
        parts: unknown;
    }>,
): ModelMessage[] {
    return storedMessages.map((message) => ({
        role: message.sdkRole,
        content: message.sdkRole === 'assistant'
            ? normalizeStoredAssistantContent(message.parts)
            : message.parts,
    })) as ModelMessage[];
}

async function countStoredMessageTokens(
    model: string,
    parts: unknown,
): Promise<{ tokens: number | null; tokenCountStatus: 'exact' | 'unknown' }> {
    const contents = extractCountableContent(parts);
    if (contents == null) {
        return { tokens: null, tokenCountStatus: 'unknown' };
    }

    try {
        const response = await genAi.models.countTokens({
            model,
            contents,
        });
        return {
            tokens: response.totalTokens ?? null,
            tokenCountStatus: response.totalTokens != null ? 'exact' : 'unknown',
        };
    } catch (err) {
        console.warn('[buddy/chat] token count failed:', err);
        return { tokens: null, tokenCountStatus: 'unknown' };
    }
}

async function generateSessionTitle(
    userId: number,
    input: Extract<ChatInput, { kind: 'user' }>,
): Promise<string> {
    const trimmed = input.text.trim();
    if (trimmed.length === 0 && (input.attachmentIds?.length ?? 0) > 0) {
        return MEAL_PHOTO_SESSION_TITLE;
    }

    const fallbackTitle = fallbackTitleFromText(trimmed);

    try {
        const { text, usage } = await generateText({
            model: google(BUDDY_TITLE_MODEL),
            system: [
                'You create short Buddy chat session titles.',
                'Return only the title.',
                'Use title case.',
                'Keep it under 5 words.',
                'Do not use quotes or punctuation.',
            ].join(' '),
            prompt: `User's first Buddy message:\n${trimmed}`,
        });

        await trackAiUsage({
            model: BUDDY_TITLE_MODEL,
            feature: AI_FEATURE.BUDDY_CHAT,
            userId,
            usage,
        });

        return normalizeGeneratedTitle(text, fallbackTitle);
    } catch (err) {
        console.warn('[buddy/chat] title generation failed:', err);
        return fallbackTitle;
    }
}

async function resolveBuddyPromptContext(userId: number, requestedTimeZone: string) {
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
    const timeZone = requestedTimeZone !== 'UTC'
        ? requestedTimeZone
        : (profile?.timezoneIana ?? 'UTC');

    return {
        timeZone,
        systemPrompt: buildBuddySystemPrompt(firstName, timeZone),
    };
}

async function streamBuddyResponse(params: {
    stream: Parameters<typeof streamSSE>[1] extends (stream: infer T) => Promise<void> ? T : never;
    userId: number;
    timeZone: string;
    systemPrompt: string;
    messages: ModelMessage[];
    flushSessionMeta?: () => Promise<void>;
}): Promise<StreamOutcome> {
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
        getMealPhotoAttachment: 'Starting the meal analysis...',
        logBodyProgress: 'Saving your body progress...',
        updateDailyHealthLog: 'Updating your daily log...',
        logDetailedWorkout: 'Logging your workout...',
        updateBodyGoals: 'Preparing your goal update...',
        updateDailyTargets: 'Preparing your target update...',
        replaceDietMeal: 'Preparing your meal swap...',
        logMealPhoto: 'Preparing your meal photo log...',
        logWorkoutSummary: 'Preparing your workout log...',
    };

    const tools = createBuddyTools(params.userId, params.timeZone, {
        onMealPhotoProgress: async (event) => {
            await params.stream.writeSSE({
                event: 'pipeline',
                data: JSON.stringify(event),
            });
            if (params.flushSessionMeta) {
                await params.flushSessionMeta();
            }
        },
    });

    const result = streamText({
        model: google(BUDDY_CHAT_MODEL),
        system: params.systemPrompt,
        messages: params.messages as any,
        tools,
        stopWhen: stepCountIs(10),
    });

    let assistantText = '';
    let sawAssistantText = false;
    let sawApprovalOrRefreshEvent = false;
    let approvalRequest: PendingApprovalPayload | null = null;
    const fallbackMessages: string[] = [];

    for await (const event of result.fullStream) {
        if (event.type === 'text-delta' && event.text) {
            sawAssistantText = true;
            assistantText += event.text;
            await params.stream.writeSSE({
                event: 'text',
                data: JSON.stringify(event.text),
            });
            if (params.flushSessionMeta) {
                await params.flushSessionMeta();
            }
            continue;
        }

        if (event.type === 'tool-call') {
            const label = toolLabels[event.toolName] ?? 'On it...';
            await params.stream.writeSSE({
                event: 'tool',
                data: JSON.stringify(label),
            });
            if (params.flushSessionMeta) {
                await params.flushSessionMeta();
            }
            continue;
        }

        if (event.type === 'tool-approval-request') {
            const preview = buildApprovalPreview(
                event.toolCall.toolName,
                event.toolCall.input as Record<string, unknown>,
            );
            approvalRequest = {
                approvalId: event.approvalId,
                toolCall: {
                    toolCallId: event.toolCall.toolCallId,
                    toolName: event.toolCall.toolName,
                    input: event.toolCall.input as Record<string, unknown>,
                    ...(event.toolCall.providerMetadata != null
                        ? { providerMetadata: event.toolCall.providerMetadata }
                        : {}),
                },
                ...preview,
            };
            sawApprovalOrRefreshEvent = true;
            await params.stream.writeSSE({
                event: 'approval',
                data: JSON.stringify(approvalRequest),
            });
            if (params.flushSessionMeta) {
                await params.flushSessionMeta();
            }
            continue;
        }

        if (event.type === 'tool-result' && !event.preliminary) {
            if (
                event.toolName === 'getMealPhotoAttachment' &&
                hasLoggedQuickMeal(event.output)
            ) {
                sawApprovalOrRefreshEvent = true;
                await params.stream.writeSSE({
                    event: 'refresh',
                    data: JSON.stringify(['diet', 'home']),
                });
                if (params.flushSessionMeta) {
                    await params.flushSessionMeta();
                }
                continue;
            }

            if (isImmediateWriteOutput(event.output)) {
                sawApprovalOrRefreshEvent = true;
                fallbackMessages.push(event.output.message);
                await params.stream.writeSSE({
                    event: 'refresh',
                    data: JSON.stringify(event.output.refreshDomains),
                });
                if (params.flushSessionMeta) {
                    await params.flushSessionMeta();
                }
            }
        }
    }

    if (!sawAssistantText && fallbackMessages.length > 0) {
        assistantText = fallbackMessages.join('\n\n');
        await params.stream.writeSSE({
            event: 'text',
            data: JSON.stringify(assistantText),
        });
        if (params.flushSessionMeta) {
            await params.flushSessionMeta();
        }
    }

    const usage = await result.usage;
    await trackAiUsage({
        model: BUDDY_CHAT_MODEL,
        feature: AI_FEATURE.BUDDY_CHAT,
        userId: params.userId,
        usage,
    });

    return {
        assistantText,
        approvalRequest,
        sawApprovalOrRefreshEvent,
        usage,
    };
}

// ─── Session CRUD ────────────────────────────────────────────────────────────

router.get('/sessions', async (c) => {
    try {
        const sessions = await listBuddySessions(c.var.userId);
        return ok(c, sessions);
    } catch (err) {
        console.error('[buddy/sessions:list] error:', err);
        return fail(c, String(err), 500);
    }
});

router.post('/sessions', async (c) => {
    try {
        const session = await createBuddySession(c.var.userId);
        return ok(c, session, 201);
    } catch (err) {
        console.error('[buddy/sessions:create] error:', err);
        return fail(c, String(err), 500);
    }
});

router.get('/sessions/:id', async (c) => {
    try {
        const sessionId = c.req.param('id');
        if (!z.string().uuid().safeParse(sessionId).success) {
            throw badRequest('Invalid session id');
        }

        const detail = await getBuddySessionDetail(c.var.userId, sessionId);
        return ok(c, detail);
    } catch (err) {
        console.error('[buddy/sessions:get] error:', err);
        if (err instanceof Error && 'statusCode' in err) {
            throw err;
        }
        return fail(c, String(err), 500);
    }
});

router.patch(
    '/sessions/:id',
    zValidator('json', sessionPatchSchema),
    async (c) => {
        try {
            const sessionId = c.req.param('id');
            if (!z.string().uuid().safeParse(sessionId).success) {
                throw badRequest('Invalid session id');
            }

            const body = c.req.valid('json');
            const session = await updateBuddySession(c.var.userId, sessionId, body);
            return ok(c, session);
        } catch (err) {
            console.error('[buddy/sessions:update] error:', err);
            if (err instanceof Error && 'statusCode' in err) {
                throw err;
            }
            return fail(c, String(err), 500);
        }
    },
);

router.delete('/sessions/:id', async (c) => {
    try {
        const sessionId = c.req.param('id');
        if (!z.string().uuid().safeParse(sessionId).success) {
            throw badRequest('Invalid session id');
        }

        await deleteBuddySession(c.var.userId, sessionId);
        return ok(c, { id: sessionId });
    } catch (err) {
        console.error('[buddy/sessions:delete] error:', err);
        if (err instanceof Error && 'statusCode' in err) {
            throw err;
        }
        return fail(c, String(err), 500);
    }
});

// ─── Session Chat ────────────────────────────────────────────────────────────

router.post(
    '/sessions/:id/chat',
    zValidator('json', sessionChatSchema),
    async (c) => {
        try {
            const userId = c.var.userId;
            const sessionId = c.req.param('id');
            if (!z.string().uuid().safeParse(sessionId).success) {
                throw badRequest('Invalid session id');
            }

            const input = c.req.valid('json').input;
            const session = await getBuddySessionRow(userId, sessionId);
            const { timeZone, systemPrompt } = await resolveBuddyPromptContext(
                userId,
                c.var.timeZone,
            );

            const now = new Date();
            let insertedMessageId: string | null = null;

            if (input.kind === 'user') {
                if (session.pendingApproval != null) {
                    throw badRequest('Resolve the pending approval before sending a new message.');
                }

                const attachmentIds = await validateBuddyAttachmentIds(
                    userId,
                    input.attachmentIds ?? [],
                );
                const modelContent = buildUserModelContent(input.text, attachmentIds);
                const preview = buildUserPreview(input.text, attachmentIds);
                if (modelContent.trim().length === 0) {
                    throw badRequest('Message text or attachment is required.');
                }

                const tokenInfo = await countStoredMessageTokens(
                    BUDDY_CHAT_MODEL,
                    modelContent,
                );
                const userMessage = await insertBuddyMessage({
                    sessionId,
                    displayRole: 'user',
                    sdkRole: 'user',
                    message: input.text.trim(),
                    parts: modelContent,
                    tokens: tokenInfo.tokens,
                    tokenCountStatus: tokenInfo.tokenCountStatus,
                });
                insertedMessageId = userMessage.id;

                if (attachmentIds.length > 0) {
                    await insertBuddyMessageAttachments({
                        messageId: userMessage.id,
                        attachmentIds,
                    });
                }

                await updateBuddySessionRuntime(userId, sessionId, {
                    updatedAt: now,
                    activityAt: now,
                    lastMessagePreview: preview,
                    lastMessageRole: 'user',
                });
            } else {
                const pendingApproval =
                    (session.pendingApproval as PendingApprovalPayload | null) ?? null;
                if (!pendingApproval || pendingApproval.approvalId !== input.approvalId) {
                    throw badRequest('Pending Buddy approval was not found.');
                }
                if (pendingApproval.toolCall.providerMetadata == null) {
                    throw badRequest(
                        'This approval request is out of date. Ask Buddy to prepare the change again.',
                    );
                }

                const approvalParts = [
                    {
                        type: 'tool-approval-response',
                        approvalId: input.approvalId,
                        approved: input.approved,
                    },
                ];
                const tokenInfo = await countStoredMessageTokens(
                    BUDDY_CHAT_MODEL,
                    approvalParts,
                );
                const toolMessage = await insertBuddyMessage({
                    sessionId,
                    displayRole: null,
                    sdkRole: 'tool',
                    message: null,
                    parts: approvalParts,
                    tokens: tokenInfo.tokens,
                    tokenCountStatus: tokenInfo.tokenCountStatus,
                    isVisible: false,
                });
                insertedMessageId = toolMessage.id;

                await updateBuddySessionRuntime(userId, sessionId, {
                    updatedAt: now,
                    activityAt: now,
                    pendingApproval: null,
                });
            }

            const storedMessages = await getStoredBuddyMessages(sessionId);
            const modelMessages = buildStoredModelMessages(storedMessages);

            const shouldGenerateTitle = input.kind === 'user'
                && session.title === DEFAULT_BUDDY_SESSION_TITLE
                && storedMessages.filter((message) => message.sdkRole === 'user').length === 1;

            return streamSSE(c, async (stream) => {
                let pendingSessionMeta: SessionMetaEvent | null = null;

                const flushSessionMeta = async () => {
                    if (!pendingSessionMeta) {
                        return;
                    }

                    const event = pendingSessionMeta;
                    pendingSessionMeta = null;
                    await stream.writeSSE({
                        event: 'session-meta',
                        data: JSON.stringify(event),
                    });
                };

                const titlePromise = shouldGenerateTitle
                    ? (async () => {
                        const generatedTitle = await generateSessionTitle(userId, input);
                        const updatedSession = await updateBuddySessionTitleIfDefault(
                            userId,
                            sessionId,
                            generatedTitle,
                        );

                        if (updatedSession) {
                            pendingSessionMeta = {
                                sessionId,
                                title: updatedSession.title,
                            };
                        }
                    })().catch((err) => {
                        console.error('[buddy/session-title] error:', err);
                    })
                    : Promise.resolve();

                try {
                    const outcome = await streamBuddyResponse({
                        stream,
                        userId,
                        timeZone,
                        systemPrompt,
                        messages: modelMessages,
                        flushSessionMeta,
                    });

                    const assistantPreview = buildAssistantPreview(
                        outcome.assistantText,
                        outcome.approvalRequest,
                    );

                    if (
                        outcome.assistantText.trim().length > 0 ||
                        outcome.approvalRequest != null
                    ) {
                        const assistantParts = outcome.approvalRequest
                            ? [
                                ...(outcome.assistantText.trim().length > 0
                                    ? [{ type: 'text', text: outcome.assistantText }]
                                    : []),
                                {
                                    type: 'tool-call',
                                    toolCallId: outcome.approvalRequest.toolCall.toolCallId,
                                    toolName: outcome.approvalRequest.toolCall.toolName,
                                    input: outcome.approvalRequest.toolCall.input,
                                    ...(outcome.approvalRequest.toolCall.providerMetadata != null
                                        ? {
                                            providerMetadata: outcome.approvalRequest.toolCall.providerMetadata,
                                        }
                                        : {}),
                                },
                                {
                                    type: 'tool-approval-request',
                                    approvalId: outcome.approvalRequest.approvalId,
                                    toolCallId: outcome.approvalRequest.toolCall.toolCallId,
                                },
                            ]
                            : outcome.assistantText;

                        const outputTokens =
                            outcome.usage.outputTokens ?? outcome.usage.completionTokens;
                        const assistantTokenInfo = outputTokens != null
                            ? {
                                tokens: outputTokens,
                                tokenCountStatus: 'exact' as const,
                            }
                            : await countStoredMessageTokens(BUDDY_CHAT_MODEL, assistantParts);

                        await insertBuddyMessage({
                            sessionId,
                            displayRole: outcome.assistantText.trim().length > 0 ? 'buddy' : null,
                            sdkRole: 'assistant',
                            message: outcome.assistantText.trim().length > 0
                                ? outcome.assistantText
                                : null,
                            parts: assistantParts,
                            model: BUDDY_CHAT_MODEL,
                            tokens: assistantTokenInfo.tokens,
                            tokenCountStatus: assistantTokenInfo.tokenCountStatus,
                            isVisible: outcome.assistantText.trim().length > 0,
                        });
                    }

                    await updateBuddySessionRuntime(userId, sessionId, {
                        updatedAt: new Date(),
                        activityAt: assistantPreview != null ? new Date() : undefined,
                        lastMessagePreview: assistantPreview ?? undefined,
                        lastMessageRole: assistantPreview != null ? 'buddy' : undefined,
                        pendingApproval: outcome.approvalRequest,
                    });

                    if (insertedMessageId && input.kind === 'approval') {
                        await updateBuddyMessageTokens(insertedMessageId, {
                            tokens: null,
                            tokenCountStatus: 'unknown',
                        });
                    }

                    await titlePromise;
                    await flushSessionMeta();
                    await stream.writeSSE({ data: '[DONE]' });
                } catch (streamErr) {
                    console.error('[buddy/sessions:chat] stream error:', streamErr);
                    await stream.writeSSE({ data: '[ERROR]' });
                }
            });
        } catch (err) {
            console.error('[buddy/sessions:chat] error:', err);
            if (err instanceof Error && 'statusCode' in err) {
                throw err;
            }
            return fail(c, String(err), 500);
        }
    },
);

// ─── Legacy POST /api/buddy/chat ─────────────────────────────────────────────

router.post('/chat', zValidator('json', legacyChatSchema), async (c) => {
    try {
        const userId = c.var.userId;
        const { messages } = c.req.valid('json');
        const { timeZone, systemPrompt } = await resolveBuddyPromptContext(
            userId,
            c.var.timeZone,
        );

        return streamSSE(c, async (stream) => {
            try {
                await streamBuddyResponse({
                    stream,
                    userId,
                    timeZone,
                    systemPrompt,
                    messages: messages as ModelMessage[],
                });
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

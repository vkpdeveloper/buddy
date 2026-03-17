import { and, asc, desc, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import {
    buddyChatMessageAttachments,
    buddyChatMessages,
    buddyChatSessions,
    mealMediaAttachments,
} from '../db/schema';
import { badRequest, notFound } from '../lib/errors';
import { signPrivateObjectUrl } from '../lib/r2';

export const DEFAULT_BUDDY_SESSION_TITLE = 'New Session';
export const MEAL_PHOTO_SESSION_TITLE = 'Meal Check-In';
export const BUDDY_CHAT_MODEL = 'gemini-3.1-flash-lite-preview';
export const BUDDY_TITLE_MODEL = BUDDY_CHAT_MODEL;

type SessionRow = typeof buddyChatSessions.$inferSelect;
type MessageRow = typeof buddyChatMessages.$inferSelect;

export type PendingApprovalPayload = {
    approvalId: string;
    toolCall: {
        toolCallId: string;
        toolName: string;
        input: Record<string, unknown>;
        providerMetadata?: unknown;
    };
    title: string;
    summary: string;
    confirmLabel: string;
    cancelLabel: string;
};

export type BuddySessionSummaryDto = {
    id: string;
    title: string;
    isPinned: boolean;
    createdAt: Date;
    updatedAt: Date;
    activityAt: Date;
    lastMessagePreview: string | null;
    lastMessageRole: 'user' | 'buddy' | null;
    hasPendingApproval: boolean;
};

export type BuddyMessageAttachmentDto = {
    id: string;
    kind: 'meal_photo';
    mealMediaAttachmentId: number | null;
    signedUrl: string | null;
    analysisStatus: string | null;
};

export type BuddyVisibleMessageDto = {
    id: string;
    role: 'user' | 'buddy';
    message: string;
    sentAt: Date;
    model: string | null;
    tokens: number | null;
    tokenCountStatus: 'exact' | 'unknown';
    attachments: BuddyMessageAttachmentDto[];
};

export type BuddySessionDetailDto = {
    session: BuddySessionSummaryDto;
    messages: BuddyVisibleMessageDto[];
    pendingApproval: PendingApprovalPayload | null;
};

export type StoredBuddyMessage = {
    id: string;
    sdkRole: 'user' | 'assistant' | 'tool';
    parts: unknown;
    message: string | null;
    model: string | null;
    isVisible: boolean;
    sentAt: Date;
};

export function mapBuddySessionSummary(
    row: SessionRow,
): BuddySessionSummaryDto {
    return {
        id: row.id,
        title: row.title,
        isPinned: row.isPinned,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        activityAt: row.activityAt,
        lastMessagePreview: row.lastMessagePreview,
        lastMessageRole: row.lastMessageRole ?? null,
        hasPendingApproval: row.pendingApproval != null,
    };
}

export async function listBuddySessions(
    userId: number,
): Promise<BuddySessionSummaryDto[]> {
    const sessions = await db
        .select()
        .from(buddyChatSessions)
        .where(eq(buddyChatSessions.userId, userId))
        .orderBy(
            desc(buddyChatSessions.isPinned),
            desc(buddyChatSessions.activityAt),
            desc(buddyChatSessions.createdAt),
        );

    return sessions.map(mapBuddySessionSummary);
}

export async function createBuddySession(
    userId: number,
): Promise<BuddySessionSummaryDto> {
    const [session] = await db
        .insert(buddyChatSessions)
        .values({ userId })
        .returning();

    return mapBuddySessionSummary(session);
}

export async function getBuddySessionRow(
    userId: number,
    sessionId: string,
): Promise<SessionRow> {
    const [session] = await db
        .select()
        .from(buddyChatSessions)
        .where(
            and(
                eq(buddyChatSessions.userId, userId),
                eq(buddyChatSessions.id, sessionId),
            ),
        )
        .limit(1);

    if (!session) {
        throw notFound('Buddy session not found');
    }

    return session;
}

export async function updateBuddySession(
    userId: number,
    sessionId: string,
    input: {
        title?: string;
        isPinned?: boolean;
    },
): Promise<BuddySessionSummaryDto> {
    const updates: Partial<typeof buddyChatSessions.$inferInsert> = {
        updatedAt: new Date(),
    };

    if (input.title !== undefined) {
        const title = input.title.trim();
        if (title.length === 0) {
            throw badRequest('Session title cannot be empty');
        }
        updates.title = title;
    }

    if (input.isPinned !== undefined) {
        updates.isPinned = input.isPinned;
    }

    const [session] = await db
        .update(buddyChatSessions)
        .set(updates)
        .where(
            and(
                eq(buddyChatSessions.userId, userId),
                eq(buddyChatSessions.id, sessionId),
            ),
        )
        .returning();

    if (!session) {
        throw notFound('Buddy session not found');
    }

    return mapBuddySessionSummary(session);
}

export async function deleteBuddySession(
    userId: number,
    sessionId: string,
): Promise<void> {
    const deleted = await db
        .delete(buddyChatSessions)
        .where(
            and(
                eq(buddyChatSessions.userId, userId),
                eq(buddyChatSessions.id, sessionId),
            ),
        )
        .returning({ id: buddyChatSessions.id });

    if (deleted.length === 0) {
        throw notFound('Buddy session not found');
    }
}

export async function getStoredBuddyMessages(
    sessionId: string,
): Promise<StoredBuddyMessage[]> {
    const rows = await db
        .select()
        .from(buddyChatMessages)
        .where(eq(buddyChatMessages.sessionId, sessionId))
        .orderBy(asc(buddyChatMessages.sentAt), asc(buddyChatMessages.id));

    return rows.map((row) => ({
        id: row.id,
        sdkRole: row.sdkRole,
        parts: row.parts,
        message: row.message,
        model: row.model,
        isVisible: row.isVisible,
        sentAt: row.sentAt,
    }));
}

export async function insertBuddyMessage(
    input: {
        sessionId: string;
        displayRole: 'user' | 'buddy' | null;
        sdkRole: 'user' | 'assistant' | 'tool';
        message: string | null;
        parts: unknown;
        model?: string | null;
        tokens?: number | null;
        tokenCountStatus?: 'exact' | 'unknown';
        isVisible?: boolean;
    },
): Promise<MessageRow> {
    const [message] = await db
        .insert(buddyChatMessages)
        .values({
            sessionId: input.sessionId,
            displayRole: input.displayRole,
            sdkRole: input.sdkRole,
            message: input.message,
            parts: input.parts,
            model: input.model ?? null,
            tokens: input.tokens ?? null,
            tokenCountStatus: input.tokenCountStatus ?? 'unknown',
            isVisible: input.isVisible ?? true,
        })
        .returning();

    return message;
}

export async function insertBuddyMessageAttachments(
    input: {
        messageId: string;
        attachmentIds: number[];
    },
): Promise<void> {
    if (input.attachmentIds.length === 0) {
        return;
    }

    await db.insert(buddyChatMessageAttachments).values(
        input.attachmentIds.map((attachmentId, index) => ({
            messageId: input.messageId,
            kind: 'meal_photo' as const,
            mealMediaAttachmentId: attachmentId,
            sortOrder: index,
        })),
    );
}

export async function updateBuddyMessageTokens(
    messageId: string,
    input: {
        tokens: number | null;
        tokenCountStatus: 'exact' | 'unknown';
    },
): Promise<void> {
    await db
        .update(buddyChatMessages)
        .set({
            tokens: input.tokens,
            tokenCountStatus: input.tokenCountStatus,
        })
        .where(eq(buddyChatMessages.id, messageId));
}

export async function updateBuddySessionRuntime(
    userId: number,
    sessionId: string,
    input: {
        updatedAt?: Date;
        activityAt?: Date;
        lastMessagePreview?: string | null;
        lastMessageRole?: 'user' | 'buddy' | null;
        pendingApproval?: PendingApprovalPayload | null;
        title?: string;
    },
): Promise<BuddySessionSummaryDto> {
    const [session] = await db
        .update(buddyChatSessions)
        .set({
            ...(input.updatedAt ? { updatedAt: input.updatedAt } : {}),
            ...(input.activityAt ? { activityAt: input.activityAt } : {}),
            ...(input.lastMessagePreview !== undefined
                ? { lastMessagePreview: input.lastMessagePreview }
                : {}),
            ...(input.lastMessageRole !== undefined
                ? { lastMessageRole: input.lastMessageRole }
                : {}),
            ...(input.pendingApproval !== undefined
                ? { pendingApproval: input.pendingApproval }
                : {}),
            ...(input.title !== undefined ? { title: input.title } : {}),
        })
        .where(
            and(
                eq(buddyChatSessions.userId, userId),
                eq(buddyChatSessions.id, sessionId),
            ),
        )
        .returning();

    if (!session) {
        throw notFound('Buddy session not found');
    }

    return mapBuddySessionSummary(session);
}

export async function updateBuddySessionTitleIfDefault(
    userId: number,
    sessionId: string,
    title: string,
): Promise<BuddySessionSummaryDto | null> {
    const trimmed = title.trim();
    if (trimmed.length === 0) {
        return null;
    }

    const [session] = await db
        .update(buddyChatSessions)
        .set({
            title: trimmed,
            updatedAt: new Date(),
        })
        .where(
            and(
                eq(buddyChatSessions.userId, userId),
                eq(buddyChatSessions.id, sessionId),
                eq(buddyChatSessions.title, DEFAULT_BUDDY_SESSION_TITLE),
            ),
        )
        .returning();

    return session ? mapBuddySessionSummary(session) : null;
}

export async function getBuddySessionDetail(
    userId: number,
    sessionId: string,
): Promise<BuddySessionDetailDto> {
    const session = await getBuddySessionRow(userId, sessionId);
    const visibleMessages = await db
        .select()
        .from(buddyChatMessages)
        .where(
            and(
                eq(buddyChatMessages.sessionId, sessionId),
                eq(buddyChatMessages.isVisible, true),
            ),
        )
        .orderBy(asc(buddyChatMessages.sentAt), asc(buddyChatMessages.id));

    const attachmentsByMessageId = await hydrateBuddyAttachments(
        userId,
        visibleMessages.map((message) => message.id),
    );

    return {
        session: mapBuddySessionSummary(session),
        messages: visibleMessages.map((message) => ({
            id: message.id,
            role: message.displayRole === 'user' ? 'user' : 'buddy',
            message: message.message ?? '',
            sentAt: message.sentAt,
            model: message.model,
            tokens: message.tokens ?? null,
            tokenCountStatus: message.tokenCountStatus,
            attachments: attachmentsByMessageId.get(message.id) ?? [],
        })),
        pendingApproval: (session.pendingApproval as PendingApprovalPayload | null) ?? null,
    };
}

export async function validateBuddyAttachmentIds(
    userId: number,
    attachmentIds: number[],
): Promise<number[]> {
    if (attachmentIds.length === 0) {
        return [];
    }

    const uniqueIds = [...new Set(attachmentIds)];
    const rows = await db
        .select({ id: mealMediaAttachments.id })
        .from(mealMediaAttachments)
        .where(
            and(
                eq(mealMediaAttachments.userId, userId),
                inArray(mealMediaAttachments.id, uniqueIds),
            ),
        );

    if (rows.length !== uniqueIds.length) {
        throw badRequest('One or more Buddy attachments are invalid');
    }

    return uniqueIds;
}

async function hydrateBuddyAttachments(
    userId: number,
    messageIds: string[],
): Promise<Map<string, BuddyMessageAttachmentDto[]>> {
    const attachmentsByMessageId = new Map<string, BuddyMessageAttachmentDto[]>();
    if (messageIds.length === 0) {
        return attachmentsByMessageId;
    }

    const attachmentRows = await db
        .select({
            id: buddyChatMessageAttachments.id,
            messageId: buddyChatMessageAttachments.messageId,
            kind: buddyChatMessageAttachments.kind,
            sortOrder: buddyChatMessageAttachments.sortOrder,
            mealMediaAttachmentId: buddyChatMessageAttachments.mealMediaAttachmentId,
            attachmentUserId: mealMediaAttachments.userId,
            analysisStatus: mealMediaAttachments.aiAnalysisStatus,
            objectKey: mealMediaAttachments.objectKey,
        })
        .from(buddyChatMessageAttachments)
        .leftJoin(
            mealMediaAttachments,
            eq(
                buddyChatMessageAttachments.mealMediaAttachmentId,
                mealMediaAttachments.id,
            ),
        )
        .where(inArray(buddyChatMessageAttachments.messageId, messageIds))
        .orderBy(
            asc(buddyChatMessageAttachments.messageId),
            asc(buddyChatMessageAttachments.sortOrder),
        );

    const hydrated = await Promise.all(
        attachmentRows.map(async (row) => ({
            messageId: row.messageId,
            attachment: {
                id: row.id,
                kind: row.kind,
                mealMediaAttachmentId: row.mealMediaAttachmentId ?? null,
                signedUrl: row.objectKey != null && row.attachmentUserId === userId
                    ? await signPrivateObjectUrl(row.objectKey)
                    : null,
                analysisStatus: row.analysisStatus ?? null,
            } satisfies BuddyMessageAttachmentDto,
        })),
    );

    for (const row of hydrated) {
        const existing = attachmentsByMessageId.get(row.messageId) ?? [];
        existing.push(row.attachment);
        attachmentsByMessageId.set(row.messageId, existing);
    }

    return attachmentsByMessageId;
}

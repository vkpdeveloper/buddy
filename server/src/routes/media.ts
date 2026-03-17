import { Hono } from 'hono';
import { eq, and, desc, inArray } from 'drizzle-orm';
import { db } from '../db';
import { dietQuickLogs, mealMediaAttachments } from '../db/schema';
import { createMealPhotoObjectKey, signPrivateObjectUrl, uploadPrivateObject } from '../lib/r2';
import { ok, fail } from '../lib/response';
import { notFound, badRequest } from '../lib/errors';
import {
  ensureMealAnalysisQueued,
  ensureMealAnalysisReady,
  ensureLoggedQuickMealForAttachment,
  getLoggedQuickMealForAttachment,
} from '../services/mealMedia';

const router = new Hono();

const MAX_PHOTO_BYTES = 5 * 1024 * 1024; // 5 MB
const BLOCKED_MIME_TYPES = new Set(['image/gif']);

// ─── POST /api/diet/media/upload ─────────────────────────────────────────────
router.post('/upload', async (c) => {
  const userId = c.var.userId;
  const form = await c.req.formData();
  const file = form.get('file');
  const mimeTypeField = String(form.get('mimeType') ?? '').trim().toLowerCase();

  if (!(file instanceof File)) {
    return fail(c, 'file is required', 400);
  }

  const normalizedFromFile = file.type.trim().toLowerCase();
  const effectiveMimeType = mimeTypeField.startsWith('image/')
    ? mimeTypeField
    : normalizedFromFile;

  if (!effectiveMimeType.startsWith('image/') || BLOCKED_MIME_TYPES.has(effectiveMimeType)) {
    return fail(c, `Only non-GIF images are allowed (received "${effectiveMimeType}")`, 400);
  }

  if (file.size > MAX_PHOTO_BYTES) {
    return fail(c, 'File size exceeds 5 MB limit', 400);
  }

  const objectKey = createMealPhotoObjectKey(effectiveMimeType);
  const bytes = new Uint8Array(await file.arrayBuffer());

  await uploadPrivateObject({ objectKey, body: bytes, contentType: effectiveMimeType });

  const inserted = await db
    .insert(mealMediaAttachments)
    .values({
      userId,
      objectKey,
      mimeType: effectiveMimeType,
      sizeBytes: file.size,
      aiAnalysisStatus: 'pending',
    })
    .returning();

  const row = inserted[0];
  const signedUrl = await signPrivateObjectUrl(row.objectKey);

  return ok(c, { id: row.id, signedUrl });
});

// ─── GET /api/diet/media/recent ──────────────────────────────────────────────
router.get('/recent', async (c) => {
  const userId = c.var.userId;

  const attachments = await db
    .select()
    .from(mealMediaAttachments)
    .where(eq(mealMediaAttachments.userId, userId))
    .orderBy(desc(mealMediaAttachments.createdAt))
    .limit(12);

  const attachmentIds = attachments.map((attachment) => attachment.id);
  const quickLogs = attachmentIds.length === 0
    ? []
    : await db
        .select()
        .from(dietQuickLogs)
        .where(
          and(
            eq(dietQuickLogs.userId, userId),
            inArray(dietQuickLogs.attachmentId, attachmentIds),
          ),
        );
  const quickLogByAttachmentId = new Map<number, (typeof quickLogs)[number]>();
  for (const quickLog of quickLogs) {
    if (quickLog.attachmentId != null) {
      quickLogByAttachmentId.set(quickLog.attachmentId, quickLog);
    }
  }

  const items = await Promise.all(
    attachments.map(async (attachment) => {
      const loggedQuickMeal =
        quickLogByAttachmentId.get(attachment.id) ??
        (await ensureLoggedQuickMealForAttachment(userId, attachment));

      return {
        id: attachment.id,
        mimeType: attachment.mimeType,
        sizeBytes: attachment.sizeBytes,
        aiAnalysisStatus: attachment.aiAnalysisStatus,
        analysisResult: attachment.aiAnalysisResult,
        createdAt: attachment.createdAt,
        signedUrl: await signPrivateObjectUrl(attachment.objectKey),
        loggedQuickMeal,
      };
    }),
  );

  return ok(c, items);
});

// ─── POST /api/diet/media/:id/analyze ────────────────────────────────────────
router.post('/:id/analyze', async (c) => {
  const userId = c.var.userId;
  const id = Number(c.req.param('id'));
  if (!Number.isInteger(id) || id <= 0) {
    throw badRequest('Invalid id');
  }

  const [attachment] = await db
    .select()
    .from(mealMediaAttachments)
    .where(and(eq(mealMediaAttachments.id, id), eq(mealMediaAttachments.userId, userId)))
    .limit(1);

  if (!attachment) {
    throw notFound('Attachment not found');
  }

  if (attachment.aiAnalysisStatus === 'completed' && attachment.aiAnalysisResult) {
    const resolved = await ensureMealAnalysisReady(userId, attachment.id);
    return ok(c, {
      status: 'completed',
      analysisResult: resolved.aiAnalysisResult,
      loggedQuickMeal: resolved.loggedQuickMeal,
    });
  }

  if (attachment.aiAnalysisStatus === 'analyzing') {
    return ok(c, {
      status: 'analyzing',
      analysisResult: attachment.aiAnalysisResult,
    });
  }

  try {
    await ensureMealAnalysisQueued(attachment);

    return ok(c, { status: 'analyzing' });
  } catch (queueErr) {
    throw queueErr;
  }
});

// ─── GET /api/diet/media/:id/url ─────────────────────────────────────────────
router.get('/:id/url', async (c) => {
  const userId = c.var.userId;
  const id = Number(c.req.param('id'));

  const [attachment] = await db
    .select()
    .from(mealMediaAttachments)
    .where(and(eq(mealMediaAttachments.id, id), eq(mealMediaAttachments.userId, userId)))
    .limit(1);

  if (!attachment) {
    throw notFound('Attachment not found');
  }

  const signedUrl = await signPrivateObjectUrl(attachment.objectKey);
  const loggedQuickMeal =
    (await getLoggedQuickMealForAttachment(userId, attachment.id)) ??
    (await ensureLoggedQuickMealForAttachment(userId, attachment));
  return ok(c, {
    signedUrl,
    aiAnalysisStatus: attachment.aiAnalysisStatus,
    analysisResult: attachment.aiAnalysisResult,
    loggedQuickMeal,
  });
});

// ─── GET /api/diet/media/:id ──────────────────────────────────────────────────
router.get('/:id', async (c) => {
  const userId = c.var.userId;
  const id = Number(c.req.param('id'));

  const [attachment] = await db
    .select()
    .from(mealMediaAttachments)
    .where(and(eq(mealMediaAttachments.id, id), eq(mealMediaAttachments.userId, userId)))
    .limit(1);

  if (!attachment) {
    throw notFound('Attachment not found');
  }

  const signedUrl = await signPrivateObjectUrl(attachment.objectKey);
  const loggedQuickMeal =
    (await getLoggedQuickMealForAttachment(userId, attachment.id)) ??
    (await ensureLoggedQuickMealForAttachment(userId, attachment));

  return ok(c, {
    id: attachment.id,
    mimeType: attachment.mimeType,
    sizeBytes: attachment.sizeBytes,
    aiAnalysisStatus: attachment.aiAnalysisStatus,
    analysisResult: attachment.aiAnalysisResult,
    signedUrl,
    createdAt: attachment.createdAt,
    loggedQuickMeal,
  });
});

export default router;

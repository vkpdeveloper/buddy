import { Hono } from 'hono';
import { eq, and, desc } from 'drizzle-orm';
import { db } from '../db';
import { mealMediaAttachments } from '../db/schema';
import { createMealPhotoObjectKey, signPrivateObjectUrl, uploadPrivateObject } from '../lib/r2';
import { ok, fail } from '../lib/response';
import { notFound, badRequest } from '../lib/errors';
import { ensureMealAnalysisQueued } from '../services/mealMedia';

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

  const items = await Promise.all(
    attachments.map(async (attachment) => ({
      id: attachment.id,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      aiAnalysisStatus: attachment.aiAnalysisStatus,
      analysisResult: attachment.aiAnalysisResult,
      createdAt: attachment.createdAt,
      signedUrl: await signPrivateObjectUrl(attachment.objectKey),
    })),
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
    return ok(c, {
      status: 'completed',
      analysisResult: attachment.aiAnalysisResult,
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
  return ok(c, {
    signedUrl,
    aiAnalysisStatus: attachment.aiAnalysisStatus,
    analysisResult: attachment.aiAnalysisResult,
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

  return ok(c, {
    id: attachment.id,
    mimeType: attachment.mimeType,
    sizeBytes: attachment.sizeBytes,
    aiAnalysisStatus: attachment.aiAnalysisStatus,
    analysisResult: attachment.aiAnalysisResult,
    signedUrl,
    createdAt: attachment.createdAt,
  });
});

export default router;

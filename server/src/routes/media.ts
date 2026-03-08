import { Hono } from 'hono';
import { eq, and } from 'drizzle-orm';
import { db } from '../db';
import { mealMediaAttachments } from '../db/schema';
import { createMealPhotoObjectKey, signPrivateObjectUrl, uploadPrivateObject } from '../lib/r2';
import { analyzeMealImage } from '../lib/mealAnalyzer';
import { ok, fail } from '../lib/response';
import { notFound, badRequest } from '../lib/errors';

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

  // Mark as analyzing
  await db
    .update(mealMediaAttachments)
    .set({ aiAnalysisStatus: 'analyzing' })
    .where(eq(mealMediaAttachments.id, id));

  try {
    const analysisResult = await analyzeMealImage(attachment.objectKey, attachment.mimeType);

    await db
      .update(mealMediaAttachments)
      .set({ aiAnalysisStatus: 'completed', aiAnalysisResult: analysisResult })
      .where(eq(mealMediaAttachments.id, id));

    return ok(c, { analysisResult });
  } catch (analysisErr) {
    await db
      .update(mealMediaAttachments)
      .set({ aiAnalysisStatus: 'failed' })
      .where(eq(mealMediaAttachments.id, id));
    throw analysisErr;
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
  return ok(c, { signedUrl });
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

  return ok(c, {
    id: attachment.id,
    mimeType: attachment.mimeType,
    sizeBytes: attachment.sizeBytes,
    aiAnalysisStatus: attachment.aiAnalysisStatus,
    aiAnalysisResult: attachment.aiAnalysisResult,
    createdAt: attachment.createdAt,
  });
});

export default router;

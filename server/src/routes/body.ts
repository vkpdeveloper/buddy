import { Hono } from 'hono';
import { asc, and, desc, eq, inArray } from 'drizzle-orm';
import { db } from '../db';
import {
  achievements,
  bodyMeasurements,
  bodyMilestones,
  progressPhotos,
  userAchievements,
  userProfile,
  userProgress,
} from '../db/schema';
import { getLevel, getLevelLabel, getLevelProgressFraction, getStreakMultiplier } from '../lib/xp';
import { createProgressPhotoObjectKey, signPrivateObjectUrl, uploadPrivateObject } from '../lib/r2';
import { ok, fail } from '../lib/response';
import { notFound } from '../lib/errors';
import { syncTargetsFromProfile } from '../lib/userTargets';
import { upsertBodyMeasurement } from '../services/bodyMeasurements';
import { updateBodyGoals } from '../services/targets';

const router = new Hono();

const BODY_LOG_XP_BASE = 75;
const MILESTONE_XP_REWARD = 60;
const MAX_PHOTO_BYTES = 5 * 1024 * 1024;
const BLOCKED_MIME_TYPES = new Set(['image/gif']);

type BodyMetricKey =
  | 'weightKg'
  | 'bodyFatPercent'
  | 'chestCm'
  | 'waistCm'
  | 'hipsCm'
  | 'armsCm'
  | 'thighsCm';

const METRIC_KEYS: BodyMetricKey[] = [
  'weightKg',
  'bodyFatPercent',
  'chestCm',
  'waistCm',
  'hipsCm',
  'armsCm',
  'thighsCm',
];

function metricLabel(key: BodyMetricKey) {
  switch (key) {
    case 'weightKg':
      return 'Weight';
    case 'bodyFatPercent':
      return 'Body Fat';
    case 'chestCm':
      return 'Chest';
    case 'waistCm':
      return 'Waist';
    case 'hipsCm':
      return 'Hips';
    case 'armsCm':
      return 'Arms';
    case 'thighsCm':
      return 'Thighs';
  }
}

function metricUnit(key: BodyMetricKey) {
  switch (key) {
    case 'bodyFatPercent':
      return '%';
    case 'weightKg':
      return 'kg';
    default:
      return 'cm';
  }
}

function metricDirection(key: BodyMetricKey, goal: string | null): 'higher' | 'lower' {
  if (key === 'weightKg') {
    return goal === 'muscle_gain' ? 'higher' : 'lower';
  }
  if (key === 'waistCm' || key === 'bodyFatPercent') {
    return 'lower';
  }
  return 'higher';
}

function toNum(value: unknown): number | null {
  if (typeof value !== 'number' || Number.isNaN(value)) return null;
  return value;
}

function dayFromIsoNow() {
  return new Date().toISOString().split('T')[0];
}

function calculateRemaining(current: number | null, goal: number | null, direction: 'higher' | 'lower') {
  if (current == null || goal == null) return null;
  if (direction === 'higher') {
    return Math.max(0, goal - current);
  }
  return Math.max(0, current - goal);
}

function formatPhotoDto(row: typeof progressPhotos.$inferSelect, imageUrl: string) {
  return {
    id: row.id,
    date: row.date,
    measurementId: row.measurementId,
    objectKey: row.objectKey,
    mimeType: row.mimeType,
    sizeBytes: row.sizeBytes,
    note: row.note,
    imageUrl,
    createdAt: row.createdAt,
  };
}

function milestoneEvaluations(params: {
  rows: (typeof bodyMeasurements.$inferSelect)[];
  goal: string | null;
}) {
  const { rows, goal } = params;
  const latest = rows[rows.length - 1];
  if (!latest) return [] as { key: string; value: number; label: string }[];

  const evals: { key: string; value: number; label: string }[] = [];

  if (latest.weightKg != null) {
    const weightVals = rows.map((r) => r.weightKg).filter((v): v is number => v != null);
    if (weightVals.length > 0) {
      if (metricDirection('weightKg', goal) === 'lower') {
        const min = Math.min(...weightVals);
        if (latest.weightKg <= min) evals.push({ key: 'weight_record', value: latest.weightKg, label: 'Weight record' });
      } else {
        const max = Math.max(...weightVals);
        if (latest.weightKg >= max) evals.push({ key: 'weight_record', value: latest.weightKg, label: 'Weight record' });
      }
    }
  }

  if (latest.bodyFatPercent != null) {
    const vals = rows.map((r) => r.bodyFatPercent).filter((v): v is number => v != null);
    if (vals.length > 0 && latest.bodyFatPercent <= Math.min(...vals)) {
      evals.push({ key: 'body_fat_record', value: latest.bodyFatPercent, label: 'Body fat record' });
    }
  }

  if (latest.waistCm != null) {
    const vals = rows.map((r) => r.waistCm).filter((v): v is number => v != null);
    if (vals.length > 0 && latest.waistCm <= Math.min(...vals)) {
      evals.push({ key: 'waist_record', value: latest.waistCm, label: 'Waist record' });
    }
  }

  if (latest.weightKg != null && latest.bodyFatPercent != null) {
    const currentLeanMass = latest.weightKg * (1 - latest.bodyFatPercent / 100);
    const leanMasses = rows
      .filter((r) => r.weightKg != null && r.bodyFatPercent != null)
      .map((r) => (r.weightKg as number) * (1 - (r.bodyFatPercent as number) / 100));
    if (leanMasses.length > 0 && currentLeanMass >= Math.max(...leanMasses)) {
      evals.push({ key: 'lean_mass_record', value: currentLeanMass, label: 'Lean mass record' });
    }
  }

  return evals;
}

async function ensureProgressRow(userId: number) {
  let rows = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
  if (rows.length === 0) {
    await db.insert(userProgress).values({ userId });
    rows = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
  }
  return rows[0];
}

async function ensureProfileRow(userId: number) {
  const rows = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
  if (rows.length === 0) return null;
  return rows[0];
}

router.post('/log', async (c) => {
  const userId = c.var.userId;
  const body = (await c.req.json()) as {
    date: string;
    weightKg?: number | null;
    bodyFatPercent?: number | null;
    chestCm?: number | null;
    waistCm?: number | null;
    hipsCm?: number | null;
    armsCm?: number | null;
    thighsCm?: number | null;
    notes?: string;
  };

  if (!body.date) {
    return fail(c, 'date is required', 400);
  }

  const result = await upsertBodyMeasurement(userId, body);
  return ok(c, result);
});

router.get('/history', async (c) => {
  const userId = c.var.userId;
  const rows = await db
    .select()
    .from(bodyMeasurements)
    .where(eq(bodyMeasurements.userId, userId))
    .orderBy(desc(bodyMeasurements.date), desc(bodyMeasurements.createdAt), desc(bodyMeasurements.id))
    .limit(120);
  return ok(c, rows);
});

router.get('/latest', async (c) => {
  const userId = c.var.userId;
  const rows = await db
    .select()
    .from(bodyMeasurements)
    .where(eq(bodyMeasurements.userId, userId))
    .orderBy(desc(bodyMeasurements.date), desc(bodyMeasurements.createdAt), desc(bodyMeasurements.id))
    .limit(1);
  return ok(c, rows[0] ?? null);
});

router.post('/photos', async (c) => {
  const userId = c.var.userId;
  const form = await c.req.formData();
  const file = form.get('file');
  const mimeTypeFromField = String(form.get('mimeType') ?? '');
  const date = String(form.get('date') ?? dayFromIsoNow());
  const note = String(form.get('note') ?? '');
  const measurementIdRaw = form.get('measurementId');

  if (!(file instanceof File)) {
    return fail(c, 'file is required', 400);
  }

  const normalizedFromField = mimeTypeFromField.trim().toLowerCase();
  const normalizedFromFile = file.type.trim().toLowerCase();

  const effectiveMimeType = normalizedFromField.startsWith('image/')
    ? normalizedFromField
    : normalizedFromFile;

  const isImage = effectiveMimeType.startsWith('image/');
  const isBlocked = BLOCKED_MIME_TYPES.has(effectiveMimeType);
  if (!isImage || isBlocked) {
    return fail(
      c,
      `Only non-GIF images are allowed (received file.type="${file.type}" mimeType="${mimeTypeFromField}")`,
      400,
    );
  }

  if (file.size > MAX_PHOTO_BYTES) {
    return fail(c, 'File size exceeds 5MB limit', 400);
  }

  let measurementId: number | null = null;
  if (measurementIdRaw != null && String(measurementIdRaw).length > 0) {
    const parsed = Number(measurementIdRaw);
    if (!Number.isInteger(parsed) || parsed <= 0) {
      return fail(c, 'measurementId must be a positive integer', 400);
    }
    const measurement = await db
      .select()
      .from(bodyMeasurements)
      .where(and(eq(bodyMeasurements.userId, userId), eq(bodyMeasurements.id, parsed)))
      .limit(1);
    if (measurement.length === 0) {
      throw notFound('measurementId not found');
    }
    measurementId = parsed;
  }

  const objectKey = createProgressPhotoObjectKey(effectiveMimeType);
  const bytes = new Uint8Array(await file.arrayBuffer());

  await uploadPrivateObject({
    objectKey,
    body: bytes,
    contentType: effectiveMimeType,
  });

  const inserted = await db
    .insert(progressPhotos)
    .values({
      userId,
      date,
      measurementId,
      objectKey,
      mimeType: effectiveMimeType,
      sizeBytes: file.size,
      note,
    })
    .returning();

  const row = inserted[0];
  const imageUrl = await signPrivateObjectUrl(row.objectKey);

  return ok(c, formatPhotoDto(row, imageUrl));
});

router.get('/photos', async (c) => {
  const userId = c.var.userId;
  const rows = await db.select().from(progressPhotos).where(eq(progressPhotos.userId, userId)).orderBy(desc(progressPhotos.date), desc(progressPhotos.id));
  const data = await Promise.all(
    rows.map(async (row) => {
      const imageUrl = await signPrivateObjectUrl(row.objectKey);
      return formatPhotoDto(row, imageUrl);
    }),
  );
  return ok(c, data);
});

router.get('/goals', async (c) => {
  const userId = c.var.userId;
  const profile = await ensureProfileRow(userId);
  if (!profile) throw notFound('Profile not found');
  const latest = (
    await db
      .select()
      .from(bodyMeasurements)
      .where(eq(bodyMeasurements.userId, userId))
      .orderBy(desc(bodyMeasurements.date), desc(bodyMeasurements.createdAt), desc(bodyMeasurements.id))
      .limit(1)
  )[0] ?? null;

  const weightCurrent = latest?.weightKg ?? null;
  const bodyFatCurrent = latest?.bodyFatPercent ?? null;

  const weightGoal = profile.weightGoalKg ?? null;
  const bodyFatGoal = profile.bodyFatGoalPercent ?? null;

  return ok(c, {
    weightGoalKg: weightGoal,
    bodyFatGoalPercent: bodyFatGoal,
    currentWeightKg: weightCurrent,
    currentBodyFatPercent: bodyFatCurrent,
    weightRemainingKg: calculateRemaining(weightCurrent, weightGoal, metricDirection('weightKg', profile.goal)),
    bodyFatRemainingPercent: calculateRemaining(bodyFatCurrent, bodyFatGoal, 'lower'),
  });
});

router.put('/goals', async (c) => {
  const userId = c.var.userId;
  const payload = (await c.req.json()) as {
    weightGoalKg?: number | null;
    bodyFatGoalPercent?: number | null;
  };

  const profile = await ensureProfileRow(userId);
  if (!profile) throw notFound('Profile not found');
  const updated = await updateBodyGoals(userId, {
    weightGoalKg: payload.weightGoalKg === undefined ? undefined : toNum(payload.weightGoalKg),
    bodyFatGoalPercent: payload.bodyFatGoalPercent === undefined ? undefined : toNum(payload.bodyFatGoalPercent),
  });

  return ok(c, updated);
});

router.get('/growth', async (c) => {
  const userId = c.var.userId;
  const profile = await ensureProfileRow(userId);
  if (!profile) throw notFound('Profile not found');
  const progress = await ensureProgressRow(userId);

  const history = await db
    .select()
    .from(bodyMeasurements)
    .where(eq(bodyMeasurements.userId, userId))
    .orderBy(asc(bodyMeasurements.date), asc(bodyMeasurements.createdAt), asc(bodyMeasurements.id))
    .limit(120);

  const totalLogs = history.length;
  const latest = history.length > 0 ? history[history.length - 1] : null;

  const metricCards = METRIC_KEYS.map((key) => {
    const values = history
      .map((row) => ({ date: row.date, value: row[key] as number | null }))
      .filter((item): item is { date: string; value: number } => item.value != null);

    const latestValue = values.length > 0 ? values[values.length - 1].value : null;
    const previousValue = values.length > 1 ? values[values.length - 2].value : null;
    const firstValue = values.length > 0 ? values[0].value : null;

    return {
      key,
      label: metricLabel(key),
      unit: metricUnit(key),
      direction: metricDirection(key, profile.goal),
      latestValue,
      deltaSinceLast: latestValue != null && previousValue != null ? latestValue - previousValue : null,
      deltaSinceStart: latestValue != null && firstValue != null ? latestValue - firstValue : null,
      sparkline: values.map((v) => ({ date: v.date, value: v.value })),
    };
  });

  const weightSeries = history
    .filter((row) => row.weightKg != null)
    .map((row) => ({ date: row.date, value: row.weightKg as number }));

  const compositionSeries = history
    .filter((row) => row.weightKg != null && row.bodyFatPercent != null)
    .map((row) => {
      const fatMass = (row.weightKg as number) * ((row.bodyFatPercent as number) / 100);
      const leanMass = (row.weightKg as number) - fatMass;
      return {
        date: row.date,
        fatMassKg: fatMass,
        leanMassKg: leanMass,
        bodyFatPercent: row.bodyFatPercent,
        weightKg: row.weightKg,
      };
    });

  const photoRows = await db.select().from(progressPhotos).where(eq(progressPhotos.userId, userId)).orderBy(asc(progressPhotos.date), asc(progressPhotos.id));
  const firstPhoto = photoRows.length > 0 ? photoRows[0] : null;
  const latestPhoto = photoRows.length > 0 ? photoRows[photoRows.length - 1] : null;

  const firstPhotoDto = firstPhoto
    ? formatPhotoDto(firstPhoto, await signPrivateObjectUrl(firstPhoto.objectKey))
    : null;
  const latestPhotoDto = latestPhoto
    ? formatPhotoDto(latestPhoto, await signPrivateObjectUrl(latestPhoto.objectKey))
    : null;

  const achievementsAll = await db.select().from(achievements);
  const userUnlocks = await db.select().from(userAchievements).where(eq(userAchievements.userId, userId));
  const unlockMap = new Map(userUnlocks.map((u) => [u.achievementId, u.unlockedAt]));

  const achievementGallery = achievementsAll.map((a) => ({
    ...a,
    isUnlocked: unlockMap.has(a.id),
    unlockedAt: unlockMap.get(a.id) ?? null,
  }));

  const milestones = await db.select().from(bodyMilestones).where(eq(bodyMilestones.userId, userId)).orderBy(desc(bodyMilestones.createdAt)).limit(10);

  return ok(c, {
    stats: {
      totalLogs,
      lastLogDate: latest?.date ?? null,
      currentWeightKg: latest?.weightKg ?? null,
      weightTrend: weightSeries,
    },
    level: {
      totalXp: progress.totalXp,
      currentLevel: getLevel(progress.totalXp),
      levelLabel: getLevelLabel(getLevel(progress.totalXp)),
      levelProgressFraction: getLevelProgressFraction(progress.totalXp),
      currentStreak: progress.currentStreak,
    },
    metricCards,
    photos: {
      total: photoRows.length,
      firstPhoto: firstPhotoDto,
      latestPhoto: latestPhotoDto,
    },
    achievements: achievementGallery,
    composition: {
      hasData: compositionSeries.length > 0,
      series: compositionSeries,
    },
    goals: {
      weightGoalKg: profile.weightGoalKg ?? null,
      bodyFatGoalPercent: profile.bodyFatGoalPercent ?? null,
      currentWeightKg: latest?.weightKg ?? null,
      currentBodyFatPercent: latest?.bodyFatPercent ?? null,
      weightRemainingKg: calculateRemaining(latest?.weightKg ?? null, profile.weightGoalKg ?? null, metricDirection('weightKg', profile.goal)),
      bodyFatRemainingPercent: calculateRemaining(latest?.bodyFatPercent ?? null, profile.bodyFatGoalPercent ?? null, 'lower'),
    },
    milestones: milestones.map((m) => ({
      key: m.milestoneKey,
      xpReward: m.xpReward,
      createdAt: m.createdAt,
    })),
    history: [...history].reverse(),
  });
});

export default router;

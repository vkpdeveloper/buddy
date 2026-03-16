import { and, asc, desc, eq, inArray } from 'drizzle-orm';
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
import { getLevel, getLevelLabel, getStreakMultiplier } from '../lib/xp';

const BODY_LOG_XP_BASE = 75;
const MILESTONE_XP_REWARD = 60;

export type BodyMetricKey =
    | 'weightKg'
    | 'bodyFatPercent'
    | 'chestCm'
    | 'waistCm'
    | 'hipsCm'
    | 'armsCm'
    | 'thighsCm';

export type BodyMeasurementInput = {
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

const METRIC_KEYS: BodyMetricKey[] = [
    'weightKg',
    'bodyFatPercent',
    'chestCm',
    'waistCm',
    'hipsCm',
    'armsCm',
    'thighsCm',
];

function metricDirection(key: BodyMetricKey, goal: string | null): 'higher' | 'lower' {
    if (key === 'weightKg') {
        return goal === 'muscle_gain' ? 'higher' : 'lower';
    }
    if (key === 'waistCm' || key === 'bodyFatPercent') {
        return 'lower';
    }
    return 'higher';
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
        const weightVals = rows.map((row) => row.weightKg).filter((value): value is number => value != null);
        if (weightVals.length > 0) {
            if (metricDirection('weightKg', goal) === 'lower') {
                const min = Math.min(...weightVals);
                if (latest.weightKg <= min) {
                    evals.push({ key: 'weight_record', value: latest.weightKg, label: 'Weight record' });
                }
            } else {
                const max = Math.max(...weightVals);
                if (latest.weightKg >= max) {
                    evals.push({ key: 'weight_record', value: latest.weightKg, label: 'Weight record' });
                }
            }
        }
    }

    if (latest.bodyFatPercent != null) {
        const values = rows.map((row) => row.bodyFatPercent).filter((value): value is number => value != null);
        if (values.length > 0 && latest.bodyFatPercent <= Math.min(...values)) {
            evals.push({ key: 'body_fat_record', value: latest.bodyFatPercent, label: 'Body fat record' });
        }
    }

    if (latest.waistCm != null) {
        const values = rows.map((row) => row.waistCm).filter((value): value is number => value != null);
        if (values.length > 0 && latest.waistCm <= Math.min(...values)) {
            evals.push({ key: 'waist_record', value: latest.waistCm, label: 'Waist record' });
        }
    }

    if (latest.weightKg != null && latest.bodyFatPercent != null) {
        const currentLeanMass = latest.weightKg * (1 - latest.bodyFatPercent / 100);
        const leanMasses = rows
            .filter((row) => row.weightKg != null && row.bodyFatPercent != null)
            .map((row) => (row.weightKg as number) * (1 - (row.bodyFatPercent as number) / 100));
        if (leanMasses.length > 0 && currentLeanMass >= Math.max(...leanMasses)) {
            evals.push({ key: 'lean_mass_record', value: currentLeanMass, label: 'Lean mass record' });
        }
    }

    return evals;
}

export async function ensureUserProgressRow(userId: number) {
    let rows = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
    if (rows.length === 0) {
        await db.insert(userProgress).values({ userId });
        rows = await db.select().from(userProgress).where(eq(userProgress.userId, userId)).limit(1);
    }
    return rows[0];
}

export async function getUserProfileRow(userId: number) {
    const rows = await db.select().from(userProfile).where(eq(userProfile.userId, userId)).limit(1);
    return rows[0] ?? null;
}

export async function upsertBodyMeasurement(userId: number, input: BodyMeasurementInput) {
    const progress = await ensureUserProgressRow(userId);
    const profile = await getUserProfileRow(userId);

    const [existing] = await db.select().from(bodyMeasurements)
        .where(and(eq(bodyMeasurements.userId, userId), eq(bodyMeasurements.date, input.date)))
        .limit(1);

    const multiplier = getStreakMultiplier(progress.currentStreak);
    const createXp = existing ? 0 : Math.round(BODY_LOG_XP_BASE * multiplier);

    const payload: Partial<typeof bodyMeasurements.$inferInsert> = {
        notes: input.notes ?? existing?.notes ?? '',
    };
    for (const key of METRIC_KEYS) {
        const value = input[key];
        if (value !== undefined) {
            payload[key] = value;
        } else if (!existing) {
            payload[key] = null;
        }
    }

    let measurement: typeof bodyMeasurements.$inferSelect;
    if (existing) {
        const [updated] = await db.update(bodyMeasurements)
            .set(payload)
            .where(eq(bodyMeasurements.id, existing.id))
            .returning();
        measurement = updated;
    } else {
        const [inserted] = await db.insert(bodyMeasurements).values({
            userId,
            date: input.date,
            weightKg: payload.weightKg ?? null,
            bodyFatPercent: payload.bodyFatPercent ?? null,
            chestCm: payload.chestCm ?? null,
            waistCm: payload.waistCm ?? null,
            hipsCm: payload.hipsCm ?? null,
            armsCm: payload.armsCm ?? null,
            thighsCm: payload.thighsCm ?? null,
            notes: payload.notes ?? '',
            xpEarned: createXp,
        }).returning();
        measurement = inserted;
    }

    const previousLevel = getLevel(progress.totalXp);
    let addedAchievementXp = 0;
    let addedMilestoneXp = 0;

    const totalLogs = await db.select().from(bodyMeasurements).where(eq(bodyMeasurements.userId, userId));

    const existingUnlocks = await db.select().from(userAchievements).where(eq(userAchievements.userId, userId));
    const achievementIds = existingUnlocks.map((row) => row.achievementId);
    const unlockedAchievements = achievementIds.length > 0
        ? await db.select().from(achievements).where(inArray(achievements.id, achievementIds))
        : [];
    const unlockedSlugs = new Set(unlockedAchievements.map((achievement) => achievement.slug));
    const newAchievements: (typeof achievements.$inferSelect)[] = [];

    if (!existing && totalLogs.length === 1 && !unlockedSlugs.has('first_body_log')) {
        const [firstLogAchievement] = await db.select().from(achievements)
            .where(eq(achievements.slug, 'first_body_log'))
            .limit(1);
        if (firstLogAchievement) {
            await db.insert(userAchievements).values({ userId, achievementId: firstLogAchievement.id });
            addedAchievementXp += firstLogAchievement.xpReward;
            newAchievements.push(firstLogAchievement);
        }
    }

    const milestones = await db.select().from(bodyMilestones).where(eq(bodyMilestones.userId, userId));
    const milestoneKeys = new Set(milestones.map((milestone) => milestone.milestoneKey));

    const chrono = [...totalLogs].sort((left, right) => {
        const dateCompare = left.date.localeCompare(right.date);
        if (dateCompare !== 0) return dateCompare;
        return (left.createdAt ?? '').localeCompare(right.createdAt ?? '');
    });

    const milestoneCandidates = milestoneEvaluations({
        rows: chrono,
        goal: profile?.goal ?? null,
    });

    const newMilestones: { key: string; label: string; value: number; xpReward: number }[] = [];
    for (const milestone of milestoneCandidates) {
        if (milestoneKeys.has(milestone.key)) continue;
        await db.insert(bodyMilestones).values({
            userId,
            milestoneKey: milestone.key,
            measurementId: measurement.id,
            xpReward: MILESTONE_XP_REWARD,
        });
        addedMilestoneXp += MILESTONE_XP_REWARD;
        newMilestones.push({
            key: milestone.key,
            label: milestone.label,
            value: milestone.value,
            xpReward: MILESTONE_XP_REWARD,
        });
    }

    const newTotalXp = progress.totalXp + createXp + addedAchievementXp + addedMilestoneXp;
    const newLevel = getLevel(newTotalXp);

    await db.update(userProgress)
        .set({
            totalXp: newTotalXp,
            currentLevel: newLevel,
            updatedAt: new Date().toISOString(),
        })
        .where(eq(userProgress.userId, userId));

    return {
        measurementId: measurement.id,
        xpEarned: createXp,
        achievementXp: addedAchievementXp,
        milestoneXp: addedMilestoneXp,
        multiplier,
        previousLevel,
        newLevel,
        newTotalXp,
        levelLabel: getLevelLabel(newLevel),
        didLevelUp: newLevel > previousLevel,
        newAchievements: newAchievements.map((achievement) => ({
            slug: achievement.slug,
            name: achievement.name,
            description: achievement.description,
            xpReward: achievement.xpReward,
            iconName: achievement.iconName,
        })),
        newMilestones,
    };
}

export async function backfillBodyMeasurementsForUniqueDate() {
    const rows = await db.select().from(bodyMeasurements)
        .orderBy(asc(bodyMeasurements.userId), asc(bodyMeasurements.date), asc(bodyMeasurements.createdAt), asc(bodyMeasurements.id));

    const seen = new Map<string, typeof bodyMeasurements.$inferSelect>();
    for (const row of rows) {
        const key = `${row.userId}:${row.date}`;
        const canonical = seen.get(key);
        if (!canonical) {
            seen.set(key, row);
            continue;
        }

        const merged: Partial<typeof bodyMeasurements.$inferInsert> = {
            notes: row.notes || canonical.notes,
            xpEarned: (canonical.xpEarned ?? 0) + (row.xpEarned ?? 0),
        };
        for (const metric of METRIC_KEYS) {
            merged[metric] = row[metric] ?? canonical[metric] ?? null;
        }

        const [updatedCanonical] = await db.update(bodyMeasurements)
            .set(merged)
            .where(eq(bodyMeasurements.id, canonical.id))
            .returning();

        await db.update(progressPhotos)
            .set({ measurementId: updatedCanonical.id })
            .where(eq(progressPhotos.measurementId, row.id));

        await db.delete(bodyMeasurements).where(eq(bodyMeasurements.id, row.id));
        seen.set(key, updatedCanonical);
    }
}

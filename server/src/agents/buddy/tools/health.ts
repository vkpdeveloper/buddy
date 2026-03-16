import { Tool } from 'ai';
import { z } from 'zod';
import { getLocalDateInTimeZone } from '../../../lib/time';
import { upsertBodyMeasurement } from '../../../services/bodyMeasurements';
import { getDailyLog, incrementHydration, upsertDailyLog } from '../../../services/dailyLogs';
import { ensureUserTargetsRow } from '../../../lib/userTargets';
import { updateBodyGoals, updateDailyTargets } from '../../../services/targets';
import { immediateWriteResult } from './tool_output';
import { inchesToCm, poundsToKg } from '../../../lib/unitConversions';

const WeightInputSchema = z.object({
    value: z.number().positive(),
    unit: z.enum(['kg', 'lb']),
});

const LengthInputSchema = z.object({
    value: z.number().positive(),
    unit: z.enum(['cm', 'inch']),
});

function normalizeWeight(weight?: z.infer<typeof WeightInputSchema>) {
    if (!weight) return undefined;
    return weight.unit === 'kg' ? weight.value : poundsToKg(weight.value);
}

function normalizeLength(length?: z.infer<typeof LengthInputSchema>) {
    if (!length) return undefined;
    return length.unit === 'cm' ? length.value : inchesToCm(length.value);
}

function normalizeWaterMl(water?: { value: number; unit: 'ml' | 'liter' }) {
    if (!water) return undefined;
    return water.unit === 'ml' ? water.value : Math.round(water.value * 1000);
}

function formatTargetSummary(parts: Array<string | null | undefined>) {
    return parts.filter((part): part is string => Boolean(part)).join(' · ');
}

export function getTodayDailyLogTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Get the user\'s daily health log for the current local day: water intake, sleep minutes, steps, and calories burned.',
        inputSchema: z.object({}),
        execute: async () => {
            const date = getLocalDateInTimeZone(timeZone);
            const row = await getDailyLog(userId, date);
            return row ?? { date, waterMl: 0, sleepMinutes: 0, stepsCount: 0, caloriesBurned: 0 };
        },
    };
}

export function getUserTargetsTool(userId: number): Tool {
    return {
        description: 'Get the user\'s current daily targets such as steps, water, sleep, target weight, and calorie burn.',
        inputSchema: z.object({}),
        execute: async () => ensureUserTargetsRow(userId),
    };
}

export function logBodyProgressTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Write body progress for a specific date. Use this only when the user clearly states body metrics like weight, waist, hips, arms, chest, thighs, or body fat. Ask follow-up questions if units are ambiguous.',
        inputSchema: z.object({
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            weight: WeightInputSchema.optional(),
            bodyFatPercent: z.number().min(0).max(100).optional(),
            chest: LengthInputSchema.optional(),
            waist: LengthInputSchema.optional(),
            hips: LengthInputSchema.optional(),
            arms: LengthInputSchema.optional(),
            thighs: LengthInputSchema.optional(),
            notes: z.string().optional(),
        }),
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            const result = await upsertBodyMeasurement(userId, {
                date,
                weightKg: normalizeWeight(input.weight),
                bodyFatPercent: input.bodyFatPercent,
                chestCm: normalizeLength(input.chest),
                waistCm: normalizeLength(input.waist),
                hipsCm: normalizeLength(input.hips),
                armsCm: normalizeLength(input.arms),
                thighsCm: normalizeLength(input.thighs),
                notes: input.notes,
            });

            return immediateWriteResult({
                message: `Saved your body progress for ${date}.`,
                refreshDomains: ['body', 'growth', 'home', 'progress'],
                data: {
                    measurementId: result.measurementId,
                    xpEarned: result.xpEarned,
                },
            });
        },
    };
}

export function updateDailyHealthLogTool(userId: number, timeZone: string): Tool {
    return {
        description: 'Write daily health data such as hydration, sleep, steps, or calories burned for the current local day. Use waterMode increment when the user reports drinking more water just now.',
        inputSchema: z.object({
            date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional(),
            waterMl: z.number().int().positive().optional(),
            waterMode: z.enum(['set', 'increment']).optional(),
            sleepMinutes: z.number().int().min(0).optional(),
            stepsCount: z.number().int().min(0).optional(),
            caloriesBurned: z.number().int().min(0).optional(),
        }),
        execute: async (input) => {
            const date = input.date ?? getLocalDateInTimeZone(timeZone);
            if (input.waterMl !== undefined && input.waterMode === 'increment' &&
                input.sleepMinutes === undefined && input.stepsCount === undefined && input.caloriesBurned === undefined) {
                await incrementHydration(userId, date, input.waterMl);
                return immediateWriteResult({
                    message: `Added ${input.waterMl} ml to your hydration log for ${date}.`,
                    refreshDomains: ['home', 'targets'],
                });
            }

            await upsertDailyLog(userId, date, {
                ...(input.waterMl !== undefined ? { waterMl: input.waterMl } : {}),
                ...(input.sleepMinutes !== undefined ? { sleepMinutes: input.sleepMinutes } : {}),
                ...(input.stepsCount !== undefined ? { stepsCount: input.stepsCount } : {}),
                ...(input.caloriesBurned !== undefined ? { caloriesBurned: input.caloriesBurned } : {}),
            });

            return immediateWriteResult({
                message: `Updated your daily log for ${date}.`,
                refreshDomains: ['home', 'targets'],
            });
        },
    };
}

export function updateBodyGoalsTool(userId: number): Tool {
    return {
        description: 'Update long-lived body goals such as target weight or target body-fat percentage. This tool requires approval before it executes.',
        inputSchema: z.object({
            weightGoal: WeightInputSchema.optional(),
            bodyFatGoalPercent: z.number().min(0).max(100).optional(),
        }),
        needsApproval: true,
        execute: async (input) => {
            const weightGoalKg = normalizeWeight(input.weightGoal);
            if (weightGoalKg === undefined && input.bodyFatGoalPercent === undefined) {
                throw new Error('At least one body goal value is required.');
            }

            await updateBodyGoals(userId, {
                ...(weightGoalKg !== undefined ? { weightGoalKg } : {}),
                ...(input.bodyFatGoalPercent !== undefined
                    ? { bodyFatGoalPercent: input.bodyFatGoalPercent }
                    : {}),
            });

            return immediateWriteResult({
                message: `Updated your body goals${formatTargetSummary([
                    weightGoalKg !== undefined ? `target weight ${weightGoalKg.toFixed(1)} kg` : null,
                    input.bodyFatGoalPercent !== undefined ? `body fat ${input.bodyFatGoalPercent}%` : null,
                ]) ? `: ${formatTargetSummary([
                    weightGoalKg !== undefined ? `target weight ${weightGoalKg.toFixed(1)} kg` : null,
                    input.bodyFatGoalPercent !== undefined ? `body fat ${input.bodyFatGoalPercent}%` : null,
                ])}` : '.'}`,
                refreshDomains: ['growth', 'home', 'targets'],
            });
        },
    };
}

export function updateDailyTargetsTool(userId: number): Tool {
    return {
        description: 'Update daily targets such as water, sleep, steps, calorie burn, or target weight. This tool requires approval before it executes.',
        inputSchema: z.object({
            dailySteps: z.number().int().min(0).optional(),
            dailySleepHours: z.number().positive().optional(),
            dailyWater: z.object({
                value: z.number().positive(),
                unit: z.enum(['ml', 'liter']),
            }).optional(),
            dailyCalorieBurn: z.number().int().min(0).optional(),
            targetWeight: WeightInputSchema.optional(),
        }),
        needsApproval: true,
        execute: async (input) => {
            const dailyWaterMl = normalizeWaterMl(input.dailyWater);
            const targetWeight = normalizeWeight(input.targetWeight);

            if (
                input.dailySteps === undefined &&
                input.dailySleepHours === undefined &&
                dailyWaterMl === undefined &&
                input.dailyCalorieBurn === undefined &&
                targetWeight === undefined
            ) {
                throw new Error('At least one daily target value is required.');
            }

            await updateDailyTargets(userId, {
                ...(input.dailySteps !== undefined ? { dailySteps: input.dailySteps } : {}),
                ...(input.dailySleepHours !== undefined
                    ? { dailySleepTarget: input.dailySleepHours }
                    : {}),
                ...(dailyWaterMl !== undefined ? { dailyWaterMl } : {}),
                ...(input.dailyCalorieBurn !== undefined
                    ? { dailyCalorieBurn: input.dailyCalorieBurn }
                    : {}),
                ...(targetWeight !== undefined ? { targetWeight } : {}),
            });

            return immediateWriteResult({
                message: `Updated your daily targets${formatTargetSummary([
                    input.dailySteps !== undefined ? `${input.dailySteps} steps` : null,
                    input.dailySleepHours !== undefined ? `${input.dailySleepHours} hrs sleep` : null,
                    dailyWaterMl !== undefined ? `${dailyWaterMl} ml water` : null,
                    input.dailyCalorieBurn !== undefined ? `${input.dailyCalorieBurn} kcal burn` : null,
                    targetWeight !== undefined ? `target weight ${targetWeight.toFixed(1)} kg` : null,
                ]) ? `: ${formatTargetSummary([
                    input.dailySteps !== undefined ? `${input.dailySteps} steps` : null,
                    input.dailySleepHours !== undefined ? `${input.dailySleepHours} hrs sleep` : null,
                    dailyWaterMl !== undefined ? `${dailyWaterMl} ml water` : null,
                    input.dailyCalorieBurn !== undefined ? `${input.dailyCalorieBurn} kcal burn` : null,
                    targetWeight !== undefined ? `target weight ${targetWeight.toFixed(1)} kg` : null,
                ])}` : '.'}`,
                refreshDomains: ['home', 'targets', 'growth'],
            });
        },
    };
}

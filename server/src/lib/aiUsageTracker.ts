/**
 * AI Usage Tracker
 *
 * Central hook for recording token usage and cost for every AI SDK call.
 * Import `trackAiUsage` and call it after any generateObject / generateText /
 * streamText call with the usage object returned by the SDK.
 *
 * Usage:
 *   const { object, usage } = await generateObject({ ... });
 *   await trackAiUsage({ model, feature, userId, usage });
 *
 * For streamText the usage is available as `await result.usage` after the
 * stream has been fully consumed.
 */

import { db } from '../db';
import { aiUsageLogs } from '../db/schema';

// ─── Model Pricing Table (USD per 1 000 000 tokens) ──────────────────────────
// Sources:
//   Gemini — https://ai.google.dev/pricing
//   Add new models here as they are introduced.

interface ModelPrice {
    inputPerMillion: number;   // USD per 1M input tokens
    outputPerMillion: number;  // USD per 1M output tokens
}

const MODEL_PRICES: Record<string, ModelPrice> = {
    'gemini-3.1-flash-lite-preview': { inputPerMillion: 0.25, outputPerMillion: 1.50 },
};

// Fallback price if the exact model ID is unknown
const FALLBACK_PRICE: ModelPrice = { inputPerMillion: 0.10, outputPerMillion: 0.40 };

// ─── Feature identifiers ──────────────────────────────────────────────────────
// Use these constants at every call site for consistency.

export const AI_FEATURE = {
    DIET_GENERATION: 'diet_generation',
    WORKOUT_GENERATION: 'workout_generation',
    WORKOUT_REGENERATION: 'workout_regeneration',
    EXERCISE_REPLACEMENT: 'exercise_replacement',
    MEAL_ANALYSIS: 'meal_analysis',
    BUDDY_CHAT: 'buddy_chat',
} as const;

export type AiFeature = (typeof AI_FEATURE)[keyof typeof AI_FEATURE];

// ─── Usage shape accepted from the AI SDK ────────────────────────────────────

export interface AiTokenUsage {
    promptTokens?: number;
    completionTokens?: number;
    inputTokens?: number;
    outputTokens?: number;
    totalTokens?: number;
}

// ─── Main tracking function ───────────────────────────────────────────────────

export interface TrackAiUsageParams {
    model: string;
    feature: AiFeature | string;
    userId?: number | null;
    usage: AiTokenUsage;
}

export async function trackAiUsage({
    model,
    feature,
    userId,
    usage,
}: TrackAiUsageParams): Promise<void> {
    try {
        const inputTokens = usage.promptTokens ?? usage.inputTokens ?? 0;
        const outputTokens = usage.completionTokens ?? usage.outputTokens ?? 0;
        const totalTokens = usage.totalTokens ?? inputTokens + outputTokens;

        const price = resolvePrice(model);
        const inputCostUsd = (inputTokens / 1_000_000) * price.inputPerMillion;
        const outputCostUsd = (outputTokens / 1_000_000) * price.outputPerMillion;
        const totalCostUsd = inputCostUsd + outputCostUsd;

        await db.insert(aiUsageLogs).values({
            userId: userId ?? null,
            model,
            feature,
            inputTokens,
            outputTokens,
            totalTokens,
            inputCostUsd,
            outputCostUsd,
            totalCostUsd,
        });
    } catch (err) {
        // Never let tracking failures bubble up and break the main flow
        console.error('[aiUsageTracker] failed to record usage:', err);
    }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

function resolvePrice(model: string): ModelPrice {
    // Exact match first
    if (MODEL_PRICES[model]) return MODEL_PRICES[model];

    // Prefix match — handles versioned suffixes like '-001', '-exp', etc.
    for (const key of Object.keys(MODEL_PRICES)) {
        if (model.startsWith(key) || key.startsWith(model)) {
            return MODEL_PRICES[key];
        }
    }

    console.warn(`[aiUsageTracker] unknown model "${model}", using fallback price`);
    return FALLBACK_PRICE;
}

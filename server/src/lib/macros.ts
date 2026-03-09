// ─── Nutrition Math Utilities ─────────────────────────────────────────────
// Based on Mifflin-St Jeor equation with South Asian correction factor
// Reference: Dudeja et al. (2001), ICMR guidelines for Indians

export type Sex = 'male' | 'female';
export type ActivityLevel = 'sedentary' | 'lightly_active' | 'moderately_active' | 'very_active' | 'athlete';
export type Goal = 'muscle_gain' | 'fat_loss' | 'recomp' | 'maintain' | 'endurance';
export type BodyShape = 'skinny' | 'lean' | 'fat';
export type ExperienceLevel = 'beginner' | 'intermediate' | 'advanced';

export interface BodyFatRange {
    min: number;
    max: number;
    midpoint: number;
}

// Body fat % ranges by shape and sex (clinical/sports science reference ranges)
// "skinny" = thin/untrained, low muscle mass, moderate BF% (skinny-fat profile)
// "lean"   = athletic/fit, visible muscle tone, low BF%
const BODY_FAT_RANGES: Record<BodyShape, Record<Sex, BodyFatRange>> = {
    skinny: { male: { min: 14, max: 22, midpoint: 18 }, female: { min: 22, max: 28, midpoint: 25 } },
    lean:   { male: { min: 8,  max: 15, midpoint: 12 }, female: { min: 14, max: 22, midpoint: 18 } },
    fat:    { male: { min: 22, max: 32, midpoint: 27 }, female: { min: 30, max: 40, midpoint: 35 } },
};

/**
 * Returns estimated body fat % range for a given body shape and sex.
 */
export function deriveBodyFatRange(shape: BodyShape, sex: Sex): BodyFatRange {
    return BODY_FAT_RANGES[shape][sex];
}

export interface MacroTargets {
    calories: number;
    proteinG: number;
    carbsG: number;
    fatG: number;
    bmr: number;
    tdee: number;
}

// South Asians have ~8% lower BMR than Western populations due to lower lean mass per kg
const SOUTH_ASIAN_CORRECTION = 0.92;

// More conservative activity multipliers for Indian lifestyle
const ACTIVITY_MULTIPLIERS: Record<ActivityLevel, number> = {
    sedentary: 1.20,
    lightly_active: 1.35,
    moderately_active: 1.48,
    very_active: 1.65,
    athlete: 1.80,
};

/**
 * Mifflin-St Jeor equation for BMR (kcal/day) with South Asian correction.
 * For a typical Indian male (78kg, 182cm, 30yo): ~1674 kcal (vs Western ~1820)
 */
export function calculateBMR(weightKg: number, heightCm: number, age: number, sex: Sex): number {
    const base = (10 * weightKg) + (6.25 * heightCm) - (5 * age);
    const raw = sex === 'male' ? base + 5 : base - 161;
    return Math.round(raw * SOUTH_ASIAN_CORRECTION);
}

/**
 * TDEE = BMR × activity multiplier
 */
export function calculateTDEE(bmr: number, activityLevel: ActivityLevel): number {
    return Math.round(bmr * ACTIVITY_MULTIPLIERS[activityLevel]);
}

/**
 * Calculates macro targets based on goal.
 * Protein: 2.2g/kg for muscle_gain/recomp, 2.0g/kg for fat_loss
 * Fat: 25% of total calories
 * Carbs: remaining
 */
export function calculateMacros(
    weightKg: number,
    tdee: number,
    goal: Goal,
    bmr: number
): MacroTargets {
    let targetCalories: number;
    let proteinMultiplierGKg: number;

    switch (goal) {
        case 'muscle_gain':
            targetCalories = tdee + 250;   // leaner bulk
            proteinMultiplierGKg = 2.2;
            break;
        case 'fat_loss':
            // 500 kcal deficit, floored at BMR+200 for safety
            targetCalories = Math.max(tdee - 500, bmr + 200);
            proteinMultiplierGKg = 2.0;    // preserve muscle
            break;
        case 'recomp':
            targetCalories = tdee - 150;   // slight deficit works better for Indians with higher bf%
            proteinMultiplierGKg = 2.2;
            break;
        case 'endurance':
        case 'maintain':
        default:
            targetCalories = tdee;
            proteinMultiplierGKg = 1.8;
    }

    const proteinG = Math.round(weightKg * proteinMultiplierGKg);
    const fatG = Math.round((targetCalories * 0.25) / 9);
    const proteinCals = proteinG * 4;
    const fatCals = fatG * 9;
    const carbsCals = targetCalories - proteinCals - fatCals;
    const carbsG = Math.round(carbsCals / 4);

    return {
        calories: targetCalories,
        proteinG,
        carbsG,
        fatG,
        bmr: Math.round(bmr),
        tdee,
    };
}

/**
 * Distribute macros across 7 days (slight variation to keep things interesting)
 */
export function getDayMacros(targetCalories: number, dayIndex: number): {
    calories: number;
    variation: number;
} {
    // ±50–100 kcal variation per day to avoid monotony
    const variations = [0, 50, -50, 75, -75, 50, -50];
    const variation = variations[dayIndex % 7];
    return { calories: targetCalories + variation, variation };
}

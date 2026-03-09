import { z } from 'zod';
import { eq } from 'drizzle-orm';
import { db } from '../../../db';
import { userProfile, users } from '../../../db/schema';
import { Tool } from 'ai';

export function getUserProfileTool(userId: number): Tool {
    return {
        description:
            "Get the user's profile — name, physical stats (age, weight, height, sex), fitness goal, activity level, diet type, equipment, and food preferences. Call this when you need the user's personal details, goal, or dietary restrictions.",
        inputSchema: z.object({}),
        execute: async () => {
            const [profile] = await db
                .select({
                    name: users.name,
                    age: userProfile.age,
                    sex: userProfile.sex,
                    weight: userProfile.weight,
                    height: userProfile.height,
                    goal: userProfile.goal,
                    activityLevel: userProfile.activityLevel,
                    dietType: userProfile.dietType,
                    weeklyWorkoutDays: userProfile.weeklyWorkoutDays,
                    equipment: userProfile.equipment,
                    waterTargetMl: userProfile.waterTargetMl,
                    preferredFoods: userProfile.preferredFoods,
                    useProteinPowder: userProfile.useProteinPowder,
                    mealPrepTime: userProfile.mealPrepTime,
                })
                .from(users)
                .leftJoin(userProfile, eq(userProfile.userId, users.id))
                .where(eq(users.id, userId))
                .limit(1);

            if (!profile) throw new Error('User profile not found');

            return {
                name: profile.name,
                age: profile.age,
                sex: profile.sex,
                weightKg: profile.weight,
                heightCm: profile.height,
                goal: profile.goal?.replace(/_/g, ' '),
                activityLevel: profile.activityLevel?.replace(/_/g, ' '),
                dietType: profile.dietType,
                weeklyWorkoutDays: profile.weeklyWorkoutDays,
                equipment: profile.equipment,
                waterTargetMl: profile.waterTargetMl,
                preferredFoods: profile.preferredFoods,
                useProteinPowder: profile.useProteinPowder,
                mealPrepTime: profile.mealPrepTime,
            };
        },
    };
}

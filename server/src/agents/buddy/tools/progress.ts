import { z } from 'zod';
import { eq, inArray } from 'drizzle-orm';
import { db } from '../../../db';
import { userProgress, achievements, userAchievements } from '../../../db/schema';
import { getLevel, getLevelLabel } from '../../../lib/xp';
import { Tool } from 'ai';

export function getUserProgressTool(userId: string): Tool {
    return {
        description:
            "Get the user's gamification progress — XP total, current level and label, workout streak, best streak, total workouts completed, and recently unlocked achievements. Call this when the user asks about their level, XP, streak, achievements, overall progress, or how they're doing in the app.",
        inputSchema: z.object({}),
        execute: async () => {
            const [prog] = await db
                .select()
                .from(userProgress)
                .where(eq(userProgress.userId, userId))
                .limit(1);

            if (!prog) return { message: 'No progress data yet — user has not completed any workouts.' };

            const level = getLevel(prog.totalXp);
            const levelLabel = getLevelLabel(level);

            // Recent unlocked achievements (last 5)
            const recentUnlocks = await db
                .select({ achievementId: userAchievements.achievementId, unlockedAt: userAchievements.unlockedAt })
                .from(userAchievements)
                .where(eq(userAchievements.userId, userId))
                .orderBy(userAchievements.unlockedAt)
                .limit(5);

            const achievementIds = recentUnlocks.map(u => u.achievementId);
            const achievementRows = achievementIds.length > 0
                ? await db
                    .select({ id: achievements.id, name: achievements.name, description: achievements.description })
                    .from(achievements)
                    .where(inArray(achievements.id, achievementIds))
                : [];

            const achievementMap = new Map(achievementRows.map(a => [a.id, a]));
            const recentAchievements = recentUnlocks.map(u => {
                const a = achievementMap.get(u.achievementId);
                return a ? { name: a.name, description: a.description, unlockedAt: u.unlockedAt } : null;
            }).filter(Boolean);

            return {
                level,
                levelLabel,
                totalXp: prog.totalXp,
                currentStreak: prog.currentStreak,
                longestStreak: prog.longestStreak,
                totalWorkoutsCompleted: prog.totalWorkoutsCompleted,
                lastWorkoutDate: prog.lastWorkoutDate,
                recentAchievements,
            };
        },
    };
}

import { type Tool } from 'ai';
import { getUserProfileTool } from './profile';
import { getTodayDietTool } from './today_diet';
import { getTodayWorkoutTool } from './today_workout';
import { getFullDietPlanTool } from './diet_plan';
import { getFullWorkoutPlanTool } from './workout_plan';
import { getRecentSessionsTool } from './sessions';
import { getUserProgressTool } from './progress';
import {
    getTodayDailyLogTool,
    getUserTargetsTool,
    logBodyProgressTool,
    updateBodyGoalsTool,
    updateDailyHealthLogTool,
    updateDailyTargetsTool,
} from './health';
import { getDietMealSlotTool, replaceDietMealTool } from './diet_actions';
import { getMealPhotoAttachmentTool, logMealPhotoTool } from './meal_photo';
import {
    getWorkoutLoggingContextTool,
    logWorkoutSummaryTool,
    logDetailedWorkoutTool,
} from './workout_logging';

function withLogging(name: string, tool: Tool): Tool {
    const originalExecute = tool.execute;
    if (!originalExecute) return tool;
    return {
        ...tool,
        execute: async (args: unknown, options: unknown) => {
            console.log(`[buddy/tool] → ${name}`, Object.keys(args as object).length ? args : '');
            const start = Date.now();
            try {
                const result = await (originalExecute as Function)(args, options);
                console.log(`[buddy/tool] ✓ ${name} (${Date.now() - start}ms)`);
                return result;
            } catch (err) {
                console.error(`[buddy/tool] ✗ ${name} (${Date.now() - start}ms)`, err);
                throw err;
            }
        },
    };
}

/**
 * Creates all Buddy AI tools bound to a specific user.
 * Each tool is lazy — it only hits the DB when the model decides to call it.
 */
export function createBuddyTools(userId: number, timeZone: string): Record<string, Tool> {
    const tools = {
        getUserProfile: getUserProfileTool(userId),
        getTodayDiet: getTodayDietTool(userId, timeZone),
        getTodayWorkout: getTodayWorkoutTool(userId, timeZone),
        getFullDietPlan: getFullDietPlanTool(userId),
        getFullWorkoutPlan: getFullWorkoutPlanTool(userId),
        getRecentSessions: getRecentSessionsTool(userId),
        getUserProgress: getUserProgressTool(userId),
        getTodayDailyLog: getTodayDailyLogTool(userId, timeZone),
        getUserTargets: getUserTargetsTool(userId),
        getDietMealSlot: getDietMealSlotTool(userId, timeZone),
        getWorkoutLoggingContext: getWorkoutLoggingContextTool(userId, timeZone),
        getMealPhotoAttachment: getMealPhotoAttachmentTool(userId),
        logBodyProgress: logBodyProgressTool(userId, timeZone),
        updateDailyHealthLog: updateDailyHealthLogTool(userId, timeZone),
        logDetailedWorkout: logDetailedWorkoutTool(userId, timeZone),
        updateDailyTargets: updateDailyTargetsTool(userId),
        updateBodyGoals: updateBodyGoalsTool(userId),
        replaceDietMeal: replaceDietMealTool(userId, timeZone),
        logMealPhoto: logMealPhotoTool(userId, timeZone),
        logWorkoutSummary: logWorkoutSummaryTool(userId, timeZone),
    };
    return Object.fromEntries(
        Object.entries(tools).map(([name, tool]) => [name, withLogging(name, tool)])
    );
}

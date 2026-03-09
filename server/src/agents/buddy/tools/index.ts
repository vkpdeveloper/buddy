import { type Tool } from 'ai';
import { getUserProfileTool } from './profile';
import { getTodayDietTool } from './today_diet';
import { getTodayWorkoutTool } from './today_workout';
import { getFullDietPlanTool } from './diet_plan';
import { getFullWorkoutPlanTool } from './workout_plan';
import { getRecentSessionsTool } from './sessions';
import { getUserProgressTool } from './progress';

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
export function createBuddyTools(userId: number): Record<string, Tool> {
    const tools = {
        getUserProfile: getUserProfileTool(userId),
        getTodayDiet: getTodayDietTool(userId),
        getTodayWorkout: getTodayWorkoutTool(userId),
        getFullDietPlan: getFullDietPlanTool(userId),
        getFullWorkoutPlan: getFullWorkoutPlanTool(userId),
        getRecentSessions: getRecentSessionsTool(userId),
        getUserProgress: getUserProgressTool(userId),
    };
    return Object.fromEntries(
        Object.entries(tools).map(([name, tool]) => [name, withLogging(name, tool)])
    );
}

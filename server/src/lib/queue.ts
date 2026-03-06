import { Queue } from 'bullmq';
import { env } from './env';

export const connection = { url: env.REDIS_URL };

export const plansQueue = new Queue('plans-generation', {
    connection,
    defaultJobOptions: {
        attempts: 4,
        backoff: {
            type: 'exponential',
            delay: 30_000, // 30s → 60s → 120s → 240s
        },
        removeOnComplete: 100,
        removeOnFail: 200,
    },
});

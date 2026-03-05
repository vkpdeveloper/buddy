import { Queue } from 'bullmq';
import { env } from './env';

export const connection = { url: env.REDIS_URL };

export const plansQueue = new Queue('plans-generation', { connection });

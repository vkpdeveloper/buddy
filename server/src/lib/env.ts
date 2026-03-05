import { z } from 'zod';

const envSchema = z.object({
    GEMINI_API_KEY: z.string().min(1, 'GEMINI_API_KEY is required'),
    DEEPGRAM_API_KEY: z.string().min(1, 'DEEPGRAM_API_KEY is required'),
    TURSO_DATABASE_URL: z.string().default('file:local.db'),
    TURSO_AUTH_TOKEN: z.string().optional(),
    PORT: z.string().default('3000'),
    FAL_API_KEY: z.string().min(1, 'FAL_API_KEY is required'),
    REDIS_URL: z.string().default('redis://localhost:6379'),
});

export const env = envSchema.parse(Bun.env);

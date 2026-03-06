import { Hono } from 'hono';
import { cors } from 'hono/cors';
import { logger } from 'hono/logger';
import { prettyJSON } from 'hono/pretty-json';

import { env } from './lib/env';
import { clerkAuth } from './lib/clerkAuth';
import profileRouter from './routes/profile';
import dietRouter from './routes/diet';
import workoutRouter from './routes/workout';
import ttsRouter from './routes/tts';
import logsRouter from './routes/logs';
import progressRouter, { seedAchievements } from './routes/progress';
import bodyRouter from './routes/body';
import generationRouter from './routes/generation';
import exercisesRouter from './routes/exercises';
import { seedCatalog } from './lib/seedCatalog';

const app = new Hono();

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use('*', logger());
app.use('*', prettyJSON());
app.use('*', cors({
    origin: '*',
    allowMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowHeaders: ['Content-Type', 'Authorization'],
    exposeHeaders: ['Content-Length', 'Content-Type'],
}));

// ─── Clerk JWT auth on all /api/* routes ─────────────────────────────────────
app.use('/api/*', clerkAuth(env.CLERK_PUBLISHABLE_KEY));

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get('/', (c) => c.json({
    service: 'Ledger Fitness API',
    version: '1.0.0',
    status: 'running',
    timestamp: new Date().toISOString(),
}));

// ─── Routes ───────────────────────────────────────────────────────────────────
app.route('/api/profile', profileRouter);
app.route('/api/diet', dietRouter);
app.route('/api/workout', workoutRouter);
app.route('/api/tts', ttsRouter);
app.route('/api/logs', logsRouter);
app.route('/api/progress', progressRouter);
app.route('/api/body', bodyRouter);
app.route('/api/generation', generationRouter);
app.route('/api/exercises', exercisesRouter);

// ─── Startup tasks ────────────────────────────────────────────────────────────
seedAchievements().catch(console.error);
seedCatalog().catch(console.error);

// ─── 404 Fallback ─────────────────────────────────────────────────────────────
app.notFound((c) => c.json({ success: false, error: 'Route not found' }, 404));

app.onError((err, c) => {
    console.error('Unhandled error:', err);
    return c.json({ success: false, error: err.message }, 500);
});

// ─── Start ────────────────────────────────────────────────────────────────────
const port = parseInt(env.PORT);
console.log(`\n🏋️  Ledger Fitness API`);
console.log(`🚀 Running at: http://localhost:${port}`);
console.log(`📦 DB: ${env.TURSO_DATABASE_URL}\n`);

export default {
    port,
    fetch: app.fetch,
    idleTimeout: 120,
};

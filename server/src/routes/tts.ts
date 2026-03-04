import type { Context } from 'hono';
import { Hono } from 'hono';
import { zValidator } from '@hono/zod-validator';
import { z } from 'zod';
import crypto from 'node:crypto';
import { env } from '../lib/env';

const router = new Hono();

const ttsSchema = z.object({
    text: z.string().min(1).max(2000),
});

const handleTts = async (text: string, c: Context) => {
    const startedAt = Date.now();
    const requestId = crypto.randomUUID();
    console.log(`[tts] start id=${requestId} len=${text.length}`);

    const response = await fetch('https://api.deepgram.com/v1/speak?model=aura-2-thalia-en', {
        method: 'POST',
        headers: {
            Authorization: `Token ${env.DEEPGRAM_API_KEY}`,
            'Content-Type': 'application/json',
        },
        body: JSON.stringify({ text }),
    });

    if (!response.ok || !response.body) {
        const errorText = await response.text().catch(() => '');
        console.error(`[tts] deepgram error id=${requestId} status=${response.status} ${errorText}`);
        return c.json({ success: false, error: 'Deepgram request failed' }, 502);
    }

    // Buffer the full MP3 from Deepgram so we can set Content-Length and
    // avoid any chunked-transfer truncation issues in the proxy leg.
    const audioBuffer = await response.arrayBuffer();
    const totalMs = Date.now() - startedAt;
    console.log(`[tts] done id=${requestId} bytes=${audioBuffer.byteLength} totalMs=${totalMs}`);

    c.header('Content-Type', 'audio/mpeg');
    c.header('Content-Length', String(audioBuffer.byteLength));
    c.header('Cache-Control', 'no-cache');
    return c.body(audioBuffer);
};

// GET /api/tts?text=...
// Returns: streaming MP3 audio
router.get('/', zValidator('query', ttsSchema), async (c) => {
    try {
        const { text } = c.req.valid('query');
        return await handleTts(text, c);
    } catch (err) {
        console.error('[tts]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// POST /api/tts
// Body: { text: string }
// Returns: streaming MP3 audio
router.post('/', zValidator('json', ttsSchema), async (c) => {
    try {
        const { text } = c.req.valid('json');
        return await handleTts(text, c);
    } catch (err) {
        console.error('[tts]', err);
        return c.json({ success: false, error: String(err) }, 500);
    }
});

// GET /api/tts/voices — Returns available Deepgram Aura-2 voice names
router.get('/voices', (c) => {
    return c.json({
        success: true,
        data: [
            { id: 'aura-2-orion-en',   description: 'Deep, authoritative male — ideal for workout coaching' },
            { id: 'aura-2-zeus-en',    description: 'Powerful, commanding male' },
            { id: 'aura-2-thalia-en',  description: 'Calm, clear female' },
            { id: 'aura-2-luna-en',    description: 'Warm, supportive female' },
            { id: 'aura-2-asteria-en', description: 'Friendly, energetic female' },
        ],
    });
});

export default router;

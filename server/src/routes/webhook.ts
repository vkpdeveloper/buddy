import { Hono } from 'hono';
import { db } from '../db';
import { users } from '../db/schema';
import { env } from '../lib/env';

const router = new Hono();

// ─── Svix webhook verification (no external dep) ─────────────────────────────

async function verifyClerkWebhook(
    body: string,
    headers: Headers,
): Promise<boolean> {
    const svixId = headers.get('svix-id');
    const svixTimestamp = headers.get('svix-timestamp');
    const svixSignature = headers.get('svix-signature');

    if (!svixId || !svixTimestamp || !svixSignature) return false;

    // Clerk webhook secrets are prefixed with "whsec_"
    const secretBase64 = env.CLERK_WEBHOOK_SECRET.replace(/^whsec_/, '');
    const secretBytes = Uint8Array.from(atob(secretBase64), (c) => c.charCodeAt(0));

    const signedContent = `${svixId}.${svixTimestamp}.${body}`;

    const key = await crypto.subtle.importKey(
        'raw',
        secretBytes,
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign'],
    );

    const sig = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(signedContent));
    const computed = `v1,${btoa(String.fromCharCode(...new Uint8Array(sig)))}`;

    // svix-signature header may contain multiple space-separated signatures
    return svixSignature.split(' ').some((s) => s === computed);
}

// ─── POST /webhooks/clerk ─────────────────────────────────────────────────────

router.post('/clerk', async (c) => {
    const body = await c.req.text();

    const valid = await verifyClerkWebhook(body, c.req.raw.headers);
    if (!valid) {
        console.warn('[webhook/clerk] invalid signature');
        return c.json({ error: 'Invalid signature' }, 401);
    }

    let event: { type: string; data: Record<string, any> };
    try {
        event = JSON.parse(body);
    } catch {
        return c.json({ error: 'Invalid JSON' }, 400);
    }

    const { type, data } = event;

    if (type === 'user.created' || type === 'user.updated') {
        const clerkId: string = data.id;
        const email: string =
            data.email_addresses?.find((e: any) => e.id === data.primary_email_address_id)?.email_address
            ?? data.email_addresses?.[0]?.email_address
            ?? '';
        const firstName: string = data.first_name ?? '';
        const lastName: string = data.last_name ?? '';
        const name = [firstName, lastName].filter(Boolean).join(' ');
        const registeredAt = new Date(data.created_at);

        await db
            .insert(users)
            .values({ clerkId, email, name, registeredAt })
            .onConflictDoUpdate({
                target: users.clerkId,
                set: { email, name, updatedAt: new Date() },
            });

        console.log(`[webhook/clerk] ${type} — upserted user ${clerkId} (${email})`);
    }

    return c.json({ success: true });
});

export default router;

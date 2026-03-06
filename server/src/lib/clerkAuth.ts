import type { Context, Next } from 'hono';

/**
 * Clerk JWT middleware for Hono.
 *
 * Verifies the Bearer token from the Authorization header using Clerk's
 * public JWKS endpoint, then injects `c.var.userId` (the Clerk `sub` claim)
 * into the request context.
 *
 * Clerk JWTs are RS256-signed. We cache the JWKS in-memory so we only
 * fetch it once per server boot (Clerk rotates keys rarely).
 */

const CLERK_JWKS_CACHE: { keys: CryptoKey[]; fetchedAt: number } = {
    keys: [],
    fetchedAt: 0,
};
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour

async function getClerkJwks(publishableKey: string): Promise<CryptoKey[]> {
    const now = Date.now();
    if (CLERK_JWKS_CACHE.keys.length > 0 && now - CLERK_JWKS_CACHE.fetchedAt < JWKS_TTL_MS) {
        return CLERK_JWKS_CACHE.keys;
    }

    // Derive the frontend API URL from the publishable key
    // pk_live_... → https://<instance>.clerk.accounts.dev
    // pk_test_... → https://<instance>.clerk.accounts.dev
    const instancePart = publishableKey.replace(/^pk_(live|test)_/, '');
    // The instance is base64-encoded; decode it to get the domain
    const decoded = Buffer.from(instancePart, 'base64').toString('utf-8').replace(/\0/g, '');
    // decoded looks like "clerk.<domain>$" – strip the trailing $
    const domain = decoded.replace(/\$$/, '').replace(/^clerk\./, '');
    const jwksUrl = `https://${domain}/.well-known/jwks.json`;

    const res = await fetch(jwksUrl);
    if (!res.ok) throw new Error(`Failed to fetch JWKS: ${res.status}`);
    const { keys } = await res.json() as { keys: JsonWebKey[] };

    const cryptoKeys: CryptoKey[] = await Promise.all(
        keys.map((k) =>
            crypto.subtle.importKey(
                'jwk',
                k,
                { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
                false,
                ['verify'],
            )
        )
    );

    CLERK_JWKS_CACHE.keys = cryptoKeys;
    CLERK_JWKS_CACHE.fetchedAt = now;
    return cryptoKeys;
}

function base64urlDecode(str: string): Uint8Array {
    const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
    const padded = base64.padEnd(base64.length + (4 - base64.length % 4) % 4, '=');
    const binary = atob(padded);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
    }
    return bytes;
}

async function verifyClerkJwt(token: string, publishableKey: string): Promise<{ sub: string }> {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid JWT format');

    const [headerB64, payloadB64, sigB64] = parts;
    const signingInput = `${headerB64}.${payloadB64}`;

    const signature = base64urlDecode(sigB64);
    const data = new TextEncoder().encode(signingInput);

    const keys = await getClerkJwks(publishableKey);

    let verified = false;
    for (const key of keys) {
        try {
            verified = await crypto.subtle.verify(
                { name: 'RSASSA-PKCS1-v1_5' },
                key,
                signature,
                data,
            );
            if (verified) break;
        } catch {
            // try next key
        }
    }

    if (!verified) throw new Error('JWT signature verification failed');

    const payload = JSON.parse(
        new TextDecoder().decode(base64urlDecode(payloadB64))
    ) as { sub: string; exp: number };

    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
        throw new Error('JWT expired');
    }

    return { sub: payload.sub };
}

declare module 'hono' {
    interface ContextVariableMap {
        userId: string;
    }
}

export function clerkAuth(publishableKey: string) {
    return async (c: Context, next: Next) => {
        const authHeader = c.req.header('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
            return c.json({ success: false, error: 'Unauthorized' }, 401);
        }

        const token = authHeader.slice(7);
        try {
            const { sub } = await verifyClerkJwt(token, publishableKey);
            c.set('userId', sub);
            await next();
        } catch (err) {
            console.error('[clerkAuth]', err);
            return c.json({ success: false, error: 'Invalid or expired token' }, 401);
        }
    };
}

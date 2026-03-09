import type { Context, Next } from 'hono';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { users } from '../db/schema';

/**
 * Firebase Auth JWT middleware for Hono.
 *
 * Verifies the Bearer token from the Authorization header using Firebase's
 * public JWKS endpoint, then injects `c.var.userId` (the Firebase `sub` claim)
 * into the request context.
 *
 * Firebase JWTs are RS256-signed. We cache the JWKS in-memory with a 1-hour TTL.
 */

const FIREBASE_JWKS_URL =
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com';

const JWKS_CACHE: { keys: CryptoKey[]; fetchedAt: number } = {
    keys: [],
    fetchedAt: 0,
};
const JWKS_TTL_MS = 60 * 60 * 1000; // 1 hour

async function getFirebaseJwks(): Promise<CryptoKey[]> {
    const now = Date.now();
    if (JWKS_CACHE.keys.length > 0 && now - JWKS_CACHE.fetchedAt < JWKS_TTL_MS) {
        return JWKS_CACHE.keys;
    }

    const res = await fetch(FIREBASE_JWKS_URL);
    if (!res.ok) throw new Error(`Failed to fetch Firebase JWKS: ${res.status}`);
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const { keys } = await res.json() as { keys: any[] };

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

    JWKS_CACHE.keys = cryptoKeys;
    JWKS_CACHE.fetchedAt = now;
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

async function verifyFirebaseJwt(token: string, projectId: string): Promise<{ sub: string; email?: string; name?: string; picture?: string }> {
    const parts = token.split('.');
    if (parts.length !== 3) throw new Error('Invalid JWT format');

    const [headerB64, payloadB64, sigB64] = parts;
    const signingInput = `${headerB64}.${payloadB64}`;

    const signature = base64urlDecode(sigB64);
    const data = new TextEncoder().encode(signingInput);

    const keys = await getFirebaseJwks();

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
    ) as { sub: string; exp: number; iss: string; aud: string; email?: string; name?: string; picture?: string };

    if (payload.exp && payload.exp < Math.floor(Date.now() / 1000)) {
        throw new Error('JWT expired');
    }

    const expectedIssuer = `https://securetoken.google.com/${projectId}`;
    if (payload.iss !== expectedIssuer) {
        throw new Error(`Invalid issuer: ${payload.iss}`);
    }

    if (payload.aud !== projectId) {
        throw new Error(`Invalid audience: ${payload.aud}`);
    }

    return {
        sub: payload.sub,
        email: payload.email,
        name: payload.name,
        picture: payload.picture,
    };
}

declare module 'hono' {
    interface ContextVariableMap {
        firebaseUid: string;  // Raw Firebase UID — used only by auth routes
        userId: number;       // Internal integer DB ID from users.id — used by all data routes
    }
}

export function firebaseAuth(projectId: string) {
    return async (c: Context, next: Next) => {
        const authHeader = c.req.header('Authorization');
        if (!authHeader?.startsWith('Bearer ')) {
            return c.json({ success: false, error: 'Unauthorized' }, 401);
        }

        const token = authHeader.slice(7);
        try {
            const { sub } = await verifyFirebaseJwt(token, projectId);
            c.set('firebaseUid', sub);

            // Resolve the integer DB id. Auth routes (/api/auth/*) tolerate 0
            // for the new-user registration case; all other routes require a valid id.
            const [user] = await db
                .select({ id: users.id })
                .from(users)
                .where(eq(users.firebaseUid, sub))
                .limit(1);

            const isAuthRoute = c.req.path.startsWith('/api/auth');
            if (!user && !isAuthRoute) {
                return c.json({ success: false, error: 'User not registered' }, 401);
            }

            c.set('userId', user?.id ?? 0);

            await next();
        } catch (err) {
            console.error('[firebaseAuth]', err);
            return c.json({ success: false, error: 'Invalid or expired token' }, 401);
        }
    };
}

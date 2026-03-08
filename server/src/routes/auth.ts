import { Hono } from 'hono';
import { eq } from 'drizzle-orm';
import { db } from '../db';
import { users } from '../db/schema';
import { ok } from '../lib/response';

const router = new Hono();

// POST /api/auth/register
// Called once after Firebase sign-in to upsert the user record.
// The Firebase JWT (verified by middleware) provides the UID; the client
// sends name, email, and photoUrl from the Google account.
router.post('/register', async (c) => {
    const userId = c.var.userId;
    const { email, name, photoUrl } = await c.req.json<{
        email: string;
        name: string;
        photoUrl?: string;
    }>();

    const [user] = await db
        .insert(users)
        .values({
            firebaseUid: userId,
            email,
            name,
            photoUrl: photoUrl ?? '',
        })
        .onConflictDoUpdate({
            target: users.firebaseUid,
            set: {
                email,
                name,
                photoUrl: photoUrl ?? '',
                updatedAt: new Date(),
            },
        })
        .returning();

    return ok(c, user);
});

// GET /api/auth/me — returns current user record (including onboarded flag).
// If no users row exists yet (e.g. register not yet called), returns onboarded: false
// rather than 404 so the client can safely route to onboarding.
router.get('/me', async (c) => {
    const userId = c.var.userId;
    const [user] = await db
        .select()
        .from(users)
        .where(eq(users.firebaseUid, userId))
        .limit(1);

    if (!user) {
        return ok(c, { onboarded: false });
    }

    return ok(c, user);
});

// POST /api/auth/complete-onboarding — marks the user as fully onboarded.
// Upserts so it works even if the users row was never created via /register.
router.post('/complete-onboarding', async (c) => {
    const userId = c.var.userId;
    const [user] = await db
        .insert(users)
        .values({
            firebaseUid: userId,
            email: '',
            name: '',
            photoUrl: '',
            onboarded: true,
        })
        .onConflictDoUpdate({
            target: users.firebaseUid,
            set: { onboarded: true, updatedAt: new Date() },
        })
        .returning();

    return ok(c, user);
});

export default router;

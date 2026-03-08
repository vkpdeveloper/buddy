import { Hono } from 'hono';
import { db } from '../db';
import { users } from '../db/schema';

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

    return c.json({ success: true, data: user });
});

export default router;

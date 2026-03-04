/**
 * Fixes the migration history by marking 0001_peaceful_husk as already applied,
 * then runs the new 0002_lyrical_jubilee migration directly.
 *
 * Run: bun run scripts/fix-migrations.ts
 */
import { createClient } from '@libsql/client';
import { readFileSync } from 'fs';
import { join } from 'path';
import { env } from '../src/lib/env';

const client = createClient({
    url: env.TURSO_DATABASE_URL,
    authToken: env.TURSO_AUTH_TOKEN,
});

// The hash drizzle-kit stores is the createdAt timestamp from the journal.
// But actually drizzle stores it as a hash of the SQL. We'll just INSERT the
// journal entry with the same `created_at` timestamp drizzle uses (milliseconds).
// Drizzle's __drizzle_migrations table schema: (id, hash, created_at)
// The hash is SHA256(sql) in hex. We compute it here.

async function sha256hex(text: string): Promise<string> {
    const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return Array.from(new Uint8Array(buf)).map(b => b.toString(16).padStart(2, '0')).join('');
}

async function main() {
    // 1. Ensure __drizzle_migrations table exists
    await client.execute(`
        CREATE TABLE IF NOT EXISTS __drizzle_migrations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            hash text NOT NULL,
            created_at numeric
        )
    `);

    // 2. Read the SQL for 0001_peaceful_husk
    const sql0001 = readFileSync(
        join(import.meta.dir, '../drizzle/0001_peaceful_husk.sql'),
        'utf-8'
    );

    const hash0001 = await sha256hex(sql0001);

    // Check if already recorded
    const existing = await client.execute(
        `SELECT id FROM __drizzle_migrations WHERE hash = ?`,
        [hash0001]
    );

    if (existing.rows.length === 0) {
        await client.execute(
            `INSERT INTO __drizzle_migrations (hash, created_at) VALUES (?, ?)`,
            [hash0001, 1772630341953]  // timestamp from journal
        );
        console.log('✓ Marked 0001_peaceful_husk as applied');
    } else {
        console.log('— 0001_peaceful_husk already recorded');
    }

    // 3. Now run the 0002 migration statements directly
    const sql0002 = readFileSync(
        join(import.meta.dir, '../drizzle/0002_lyrical_jubilee.sql'),
        'utf-8'
    );

    // Split on --> statement-breakpoint and run each statement
    const statements = sql0002
        .split('--> statement-breakpoint')
        .map(s => s.trim())
        .filter(s => s.length > 0);

    for (const stmt of statements) {
        try {
            await client.execute(stmt);
            console.log(`✓ ${stmt.slice(0, 60).replace(/\n/g, ' ')}…`);
        } catch (err: any) {
            if (err.message?.includes('already exists') || err.message?.includes('duplicate column')) {
                console.log(`— already exists, skipping`);
            } else {
                throw err;
            }
        }
    }

    // 4. Record 0002 in __drizzle_migrations
    const hash0002 = await sha256hex(sql0002);
    const existing2 = await client.execute(
        `SELECT id FROM __drizzle_migrations WHERE hash = ?`,
        [hash0002]
    );
    if (existing2.rows.length === 0) {
        await client.execute(
            `INSERT INTO __drizzle_migrations (hash, created_at) VALUES (?, ?)`,
            [hash0002, 1772640943085]
        );
        console.log('✓ Recorded 0002_lyrical_jubilee as applied');
    } else {
        console.log('— 0002_lyrical_jubilee already recorded');
    }

    console.log('\n✅ Migration fix complete');
}

main().catch(err => {
    console.error('Migration failed:', err);
    process.exit(1);
});

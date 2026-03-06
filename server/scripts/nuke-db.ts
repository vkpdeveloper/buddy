#!/usr/bin/env bun
// scripts/nuke-db.ts — Drop every table and re-run all migrations from scratch.
// Use this when you need a completely clean slate (e.g. after a schema rewrite).
import 'dotenv/config';
import { createInterface } from 'readline';
import { spawnSync } from 'child_process';

// ─── Helpers ──────────────────────────────────────────────────────────────────

const rl = createInterface({ input: process.stdin, output: process.stdout });
function ask(q: string): Promise<string> {
    return new Promise((resolve) => rl.question(q, resolve));
}
function red(s: string)    { return `\x1b[31m${s}\x1b[0m`; }
function yellow(s: string) { return `\x1b[33m${s}\x1b[0m`; }
function green(s: string)  { return `\x1b[32m${s}\x1b[0m`; }
function bold(s: string)   { return `\x1b[1m${s}\x1b[0m`; }
function dim(s: string)    { return `\x1b[2m${s}\x1b[0m`; }

// ─── Banner ───────────────────────────────────────────────────────────────────

console.log();
console.log(bold(red('  ☢   DB NUKE UTILITY')));
console.log(dim('  Drops ALL tables and re-runs every migration from scratch.'));
console.log();

// ─── Guard ────────────────────────────────────────────────────────────────────

const dbUrl = process.env.TURSO_DATABASE_URL ?? '';
console.log(`  Target: ${yellow(dbUrl || '(no TURSO_DATABASE_URL set)')}`);
console.log();

if (!dbUrl) {
    console.log(red('  ✕  TURSO_DATABASE_URL is not set. Aborting.\n'));
    rl.close();
    process.exit(1);
}

// ─── Confirmation ─────────────────────────────────────────────────────────────

const confirm = await ask(
    `  ${bold(red('This will destroy ALL data and schema.'))} Type ${bold('nuke')} to confirm: `
);
rl.close();

if (confirm.trim() !== 'nuke') {
    console.log('\n  Aborted — database untouched.\n');
    process.exit(0);
}

// ─── Connect & discover tables ────────────────────────────────────────────────

console.log('\n  Connecting to database...');

const { db } = await import('../src/db');
const { sql } = await import('drizzle-orm');

// Fetch every table from sqlite_master (skips internal sqlite_ tables)
const rows = await db.all<{ name: string }>(
    sql`SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%'`
);
const tables = rows.map((r) => r.name);

if (tables.length === 0) {
    console.log(dim('\n  No tables found — database is already empty.'));
} else {
    console.log(`\n  Dropping ${tables.length} table${tables.length !== 1 ? 's' : ''}:\n`);

    // Disable FK checks so we can drop in any order
    await db.run(sql`PRAGMA foreign_keys = OFF`);

    let dropped = 0;
    let failed  = 0;

    for (const table of tables) {
        try {
            await db.run(sql.raw(`DROP TABLE IF EXISTS "${table}"`));
            console.log(`    ${green('✓')} dropped  ${dim(table)}`);
            dropped++;
        } catch (err: any) {
            console.log(`    ${red('✕')} failed   ${dim(table)} — ${err?.message ?? err}`);
            failed++;
        }
    }

    await db.run(sql`PRAGMA foreign_keys = ON`);

    console.log();
    if (failed > 0) {
        console.log(yellow(`  ⚠  ${dropped} dropped, ${failed} failed.`));
    } else {
        console.log(green(`  ✓  All ${dropped} table${dropped !== 1 ? 's' : ''} dropped.`));
    }
}

// ─── Re-run migrations ────────────────────────────────────────────────────────

console.log('\n  Running migrations...\n');

const result = spawnSync('bunx', ['drizzle-kit', 'migrate'], {
    stdio: 'inherit',
    shell: false,
});

console.log();
if (result.status === 0) {
    console.log(green('  ✅  Database rebuilt successfully.\n'));
} else {
    console.log(red(`  ✕  Migration failed (exit ${result.status}).\n`));
    process.exit(result.status ?? 1);
}

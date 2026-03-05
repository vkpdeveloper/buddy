#!/usr/bin/env bun
// scripts/reset-db.ts — Wipe all data for dev purposes (asks before destroying anything)
import 'dotenv/config';
import { createInterface } from 'readline';

// ─── Prompts ─────────────────────────────────────────────────────────────────

const rl = createInterface({ input: process.stdin, output: process.stdout });

function ask(question: string): Promise<string> {
    return new Promise((resolve) => rl.question(question, resolve));
}

function red(s: string) { return `\x1b[31m${s}\x1b[0m`; }
function yellow(s: string) { return `\x1b[33m${s}\x1b[0m`; }
function green(s: string) { return `\x1b[32m${s}\x1b[0m`; }
function bold(s: string) { return `\x1b[1m${s}\x1b[0m`; }
function dim(s: string) { return `\x1b[2m${s}\x1b[0m`; }

// ─── Table groups ─────────────────────────────────────────────────────────────

const TABLE_GROUPS = {
    'User profile & progress': [
        'user_profile',
        'user_progress',
        'user_achievements',
    ],
    'Workout data': [
        'workout_sessions',
        'workout_exercises',
        'workout_days',
        'workout_plans',
    ],
    'Diet data': [
        'diet_meal_logs',
        'diet_meals',
        'diet_days',
        'diet_plans',
    ],
    'Daily logs & measurements': [
        'daily_logs',
        'body_measurements',
    ],
    'Achievements (seeded)': [
        'achievements',
    ],
} as const;

// ─── Main ─────────────────────────────────────────────────────────────────────

console.log();
console.log(bold('  ⚠️  DB RESET UTILITY'));
console.log(dim('  ledger-server — development only'));
console.log();

// Guard: refuse to run against a production URL
const dbUrl = process.env.TURSO_DATABASE_URL ?? '';
if (!dbUrl.includes('localhost') && !dbUrl.includes('127.0.0.1') && !dbUrl.includes('libsql://')) {
    // Allow Turso remote but warn loudly
    console.log(yellow('  ⚠  Remote Turso database detected:'));
    console.log(dim(`     ${dbUrl}`));
    console.log();
}

// Q1: Confirm environment
const env = await ask(`  ${bold('1/3')} You are targeting: ${yellow(dbUrl || '(no URL set)')}\n      Continue? ${dim('[y/N]')} `);
if (env.trim().toLowerCase() !== 'y') {
    console.log('\n  Aborted.\n');
    rl.close();
    process.exit(0);
}

console.log();

// Q2: What to wipe
console.log(`  ${bold('2/3')} What would you like to clear?\n`);
const groupNames = Object.keys(TABLE_GROUPS) as (keyof typeof TABLE_GROUPS)[];
groupNames.forEach((g, i) => {
    const tables = TABLE_GROUPS[g];
    console.log(`       ${dim(`[${i + 1}]`)} ${g}`);
    console.log(dim(`           tables: ${tables.join(', ')}`));
});
console.log(`       ${dim(`[A]`)} Everything (all of the above)`);
console.log();

const choice = await ask(`      Enter numbers separated by commas, or A for all: `);
const trimmed = choice.trim().toUpperCase();

let tablesToWipe: string[];

if (trimmed === 'A') {
    tablesToWipe = groupNames.flatMap((g) => [...TABLE_GROUPS[g]]);
} else {
    const indices = trimmed
        .split(',')
        .map((s) => parseInt(s.trim(), 10) - 1)
        .filter((i) => i >= 0 && i < groupNames.length);

    if (indices.length === 0) {
        console.log('\n  ' + red('No valid selection. Aborted.\n'));
        rl.close();
        process.exit(1);
    }

    tablesToWipe = indices.flatMap((i) => [...TABLE_GROUPS[groupNames[i]]]);
}

console.log();
console.log(`  Tables that will be wiped:`);
tablesToWipe.forEach((t) => console.log(`    ${red('✕')} ${t}`));
console.log();

// Q3: Final "type to confirm" guard
const confirm = await ask(
    `  ${bold('3/3')} ${red('This cannot be undone.')} Type ${bold('reset')} to confirm: `
);

if (confirm.trim() !== 'reset') {
    console.log('\n  Aborted — database untouched.\n');
    rl.close();
    process.exit(0);
}

rl.close();

// ─── Execute ──────────────────────────────────────────────────────────────────

console.log();
console.log('  Connecting to database...');

const { db } = await import('../src/db');
const { sql } = await import('drizzle-orm');

let cleared = 0;
let failed = 0;

for (const table of tablesToWipe) {
    try {
        await db.run(sql.raw(`DELETE FROM ${table}`));
        // Reset autoincrement counters where the sqlite_sequence row exists
        await db.run(sql.raw(
            `DELETE FROM sqlite_sequence WHERE name = '${table}'`
        )).catch(() => {}); // sqlite_sequence may not exist — ignore
        console.log(`  ${green('✓')} ${table}`);
        cleared++;
    } catch (err: any) {
        console.log(`  ${red('✕')} ${table} — ${err?.message ?? err}`);
        failed++;
    }
}

console.log();
if (failed === 0) {
    console.log(green(`  ✅ Done — ${cleared} table${cleared !== 1 ? 's' : ''} cleared.\n`));
} else {
    console.log(yellow(`  ⚠  Done — ${cleared} cleared, ${failed} failed.\n`));
}

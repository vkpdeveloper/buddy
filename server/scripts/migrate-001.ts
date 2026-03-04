#!/usr/bin/env bun
// scripts/migrate-001.ts — Add daily_logs table and new user_profile columns
import 'dotenv/config';
import { db } from '../src/db';
import { sql } from 'drizzle-orm';

console.log('🗃  Running migration 001...');

// Add new columns to user_profile (ignore errors if they already exist)
try {
  await db.run(sql`ALTER TABLE user_profile ADD COLUMN water_target_ml INTEGER NOT NULL DEFAULT 2500`);
  console.log('✅ Added water_target_ml to user_profile');
} catch (e: any) {
  if (e.message?.includes('duplicate column')) {
    console.log('⏭  water_target_ml already exists');
  } else { throw e; }
}

try {
  await db.run(sql`ALTER TABLE user_profile ADD COLUMN weight_goal_kg REAL`);
  console.log('✅ Added weight_goal_kg to user_profile');
} catch (e: any) {
  if (e.message?.includes('duplicate column')) {
    console.log('⏭  weight_goal_kg already exists');
  } else { throw e; }
}

// Create daily_logs table
await db.run(sql`
  CREATE TABLE IF NOT EXISTS daily_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    date TEXT NOT NULL UNIQUE,
    water_ml INTEGER NOT NULL DEFAULT 0,
    sleep_minutes INTEGER NOT NULL DEFAULT 0,
    steps_count INTEGER NOT NULL DEFAULT 0,
    calories_burned INTEGER NOT NULL DEFAULT 0,
    updated_at TEXT DEFAULT (datetime('now'))
  )
`);
console.log('✅ Created daily_logs table');

console.log('🎉 Migration 001 complete!');

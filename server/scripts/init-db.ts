#!/usr/bin/env bun
// scripts/init-db.ts — Run once to create all tables
import 'dotenv/config';
import { db } from '../src/db';
import { sql } from 'drizzle-orm';

console.log('🗃  Initialising Ledger Fitness DB...');

// Create tables by running raw SQL (Turso/local compatible)
await db.run(sql`
  CREATE TABLE IF NOT EXISTS user_profile (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    height REAL NOT NULL DEFAULT 175,
    weight REAL NOT NULL DEFAULT 70,
    age INTEGER NOT NULL DEFAULT 25,
    sex TEXT NOT NULL DEFAULT 'male',
    goal TEXT NOT NULL DEFAULT 'muscle_gain',
    activity_level TEXT NOT NULL DEFAULT 'moderately_active',
    weekly_workout_days INTEGER NOT NULL DEFAULT 4,
    equipment TEXT NOT NULL DEFAULT '["dumbbells","bodyweight"]',
    workout_cycle TEXT NOT NULL DEFAULT 'ppl',
    use_protein_powder INTEGER NOT NULL DEFAULT 1,
    protein_level TEXT NOT NULL DEFAULT 'high',
    name TEXT NOT NULL DEFAULT 'Athlete',
    updated_at TEXT DEFAULT (datetime('now'))
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS diet_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    total_calories INTEGER NOT NULL,
    protein_g REAL NOT NULL,
    carbs_g REAL NOT NULL,
    fat_g REAL NOT NULL,
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS diet_days (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES diet_plans(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    day_name TEXT NOT NULL,
    total_calories INTEGER NOT NULL,
    protein_g REAL NOT NULL,
    carbs_g REAL NOT NULL,
    fat_g REAL NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS diet_meals (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    day_id INTEGER NOT NULL REFERENCES diet_days(id) ON DELETE CASCADE,
    meal_type TEXT NOT NULL,
    meal_name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    calories INTEGER NOT NULL,
    protein_g REAL NOT NULL,
    carbs_g REAL NOT NULL,
    fat_g REAL NOT NULL,
    is_completed INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL DEFAULT ''
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS workout_plans (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    cycle_type TEXT NOT NULL,
    days_per_week INTEGER NOT NULL,
    equipment TEXT NOT NULL DEFAULT '["dumbbells"]',
    is_active INTEGER NOT NULL DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now'))
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS workout_days (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
    day_number INTEGER NOT NULL,
    day_label TEXT NOT NULL,
    is_rest_day INTEGER NOT NULL DEFAULT 0,
    notes TEXT NOT NULL DEFAULT ''
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS workout_exercises (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    day_id INTEGER NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
    order_index INTEGER NOT NULL,
    name TEXT NOT NULL,
    sets INTEGER NOT NULL,
    reps_or_time TEXT NOT NULL,
    rest_seconds INTEGER NOT NULL DEFAULT 60,
    muscle_group TEXT NOT NULL DEFAULT '',
    equipment TEXT NOT NULL DEFAULT '',
    notes TEXT NOT NULL DEFAULT ''
  )
`);

await db.run(sql`
  CREATE TABLE IF NOT EXISTS workout_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plan_id INTEGER NOT NULL REFERENCES workout_plans(id) ON DELETE CASCADE,
    day_id INTEGER NOT NULL REFERENCES workout_days(id) ON DELETE CASCADE,
    started_at TEXT DEFAULT (datetime('now')),
    completed_at TEXT,
    total_duration_seconds INTEGER
  )
`);

console.log('✅ All tables created successfully!');
console.log('🚀 Start the server with: bun run dev');

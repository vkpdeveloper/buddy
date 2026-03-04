CREATE TABLE IF NOT EXISTS diet_meal_logs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  meal_id INTEGER NOT NULL REFERENCES diet_meals(id) ON DELETE CASCADE,
  date TEXT NOT NULL,
  is_completed INTEGER NOT NULL DEFAULT 0,
  logged_at TEXT DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS diet_meal_logs_meal_date_idx ON diet_meal_logs (meal_id, date);

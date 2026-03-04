import { readFileSync } from "fs";
import { defineConfig } from "drizzle-kit";

// Manually parse .env to avoid dotenv@17 quirks with already-set env vars
try {
  readFileSync(".env", "utf-8").split("\n").forEach((line) => {
    const [k, ...v] = line.split("=");
    if (k?.trim() && v.length && !process.env[k.trim()]) {
      process.env[k.trim()] = v.join("=").trim();
    }
  });
} catch {}

if (!process.env.TURSO_DATABASE_URL) {
  throw new Error("TURSO_DATABASE_URL is not set — refusing to fall back to local.db");
}

export default defineConfig({
  schema: "./src/db/schema.ts",
  out: "./drizzle",
  dialect: "turso",
  dbCredentials: {
    url: process.env.TURSO_DATABASE_URL,
    authToken: process.env.TURSO_AUTH_TOKEN ?? undefined,
  },
});

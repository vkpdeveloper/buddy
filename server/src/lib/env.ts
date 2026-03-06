import { z } from "zod";

const _ = { r: "\x1b[0m", bold: "\x1b[1m", red: "\x1b[31m", yellow: "\x1b[33m", dim: "\x1b[2m" };

function prettyEnvError(error: z.ZodError): never {
  const lines = error.issues.map(
    (i) => `  ${_.red}✗${_.r} ${_.bold}${String(i.path[0])}${_.r}  ${_.dim}${i.message}${_.r}`
  );
  console.error(`\n${_.bold}${_.red}Environment validation failed${_.r}\n\n${lines.join("\n")}\n`);
  process.exit(1);
}

// ── Schema ──────────────────────────────────────────────────────────────────
const envSchema = z.object({
  GEMINI_API_KEY: z.string().min(1, "GEMINI_API_KEY is required"),
  DEEPGRAM_API_KEY: z.string().min(1, "DEEPGRAM_API_KEY is required"),
  DATABASE_URL: z.string().min(1, "DATABASE_URL is required"),
  PORT: z.string().default("3000"),
  FAL_API_KEY: z.string().min(1, "FAL_API_KEY is required"),
  REDIS_URL: z.string().default("redis://localhost:6379"),

  R2_ACCOUNT_ID: z.string().min(1, "R2_ACCOUNT_ID is required"),
  R2_ACCESS_KEY_ID: z.string().min(1, "R2_ACCESS_KEY_ID is required"),
  R2_SECRET_ACCESS_KEY: z.string().min(1, "R2_SECRET_ACCESS_KEY is required"),
  R2_BUCKET_NAME: z.string().min(1, "R2_BUCKET_NAME is required"),
  R2_PUBLIC_BASE_URL: z.string().optional(),

  // Clerk
  CLERK_PUBLISHABLE_KEY: z.string().min(1, "CLERK_PUBLISHABLE_KEY is required"),
  CLERK_SECRET_KEY: z.string().min(1, "CLERK_SECRET_KEY is required"),
});

// ── Parse & export ──────────────────────────────────────────────────────────
const parsed = (() => {
  try {
    return envSchema.parse(Bun.env);
  } catch (e) {
    if (e instanceof z.ZodError) prettyEnvError(e);
    throw e;
  }
})();

export const env = parsed;

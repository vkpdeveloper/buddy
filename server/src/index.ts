import { Hono } from "hono";
import { cors } from "hono/cors";
import { logger } from "hono/logger";
import { prettyJSON } from "hono/pretty-json";

import { env } from "./lib/env";
import { AppError } from "./lib/errors";
import { fail } from "./lib/response";
import { firebaseAuth } from "./lib/firebaseAuth";
import authRouter from "./routes/auth";
import profileRouter from "./routes/profile";
import dietRouter from "./routes/diet";
import workoutRouter from "./routes/workout";
import ttsRouter from "./routes/tts";
import logsRouter from "./routes/logs";
import progressRouter, { seedAchievements } from "./routes/progress";
import bodyRouter from "./routes/body";
import generationRouter from "./routes/generation";
import exercisesRouter from "./routes/exercises";
import mediaRouter from "./routes/media";
import buddyRouter from "./routes/buddy";
import targetsRouter from "./routes/targets";
import { seedCatalog } from "./lib/seedCatalog";

const app = new Hono();

// ─── Middleware ───────────────────────────────────────────────────────────────
app.use("*", logger());
app.use("*", prettyJSON());
app.use(
  "*",
  cors({
    origin: "*",
    allowMethods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowHeaders: ["Content-Type", "Authorization"],
    exposeHeaders: ["Content-Length", "Content-Type"],
  }),
);

// ─── Firebase JWT auth on all /api/* routes ──────────────────────────────────
app.use("/api/*", firebaseAuth(env.FIREBASE_PROJECT_ID));

// ─── Health Check ─────────────────────────────────────────────────────────────
app.get("/", (c) =>
  c.json({
    service: "Buddy Fitness API",
    version: "1.0.0",
    status: "running",
    timestamp: new Date().toISOString(),
  }),
);

// ─── Routes ───────────────────────────────────────────────────────────────────
app.route("/api/auth", authRouter);
app.route("/api/profile", profileRouter);
app.route("/api/diet", dietRouter);
app.route("/api/workout", workoutRouter);
app.route("/api/tts", ttsRouter);
app.route("/api/logs", logsRouter);
app.route("/api/progress", progressRouter);
app.route("/api/body", bodyRouter);
app.route("/api/targets", targetsRouter);
app.route("/api/generation", generationRouter);
app.route("/api/exercises", exercisesRouter);
app.route("/api/diet/media", mediaRouter);
app.route("/api/buddy", buddyRouter);

// ─── Startup tasks ────────────────────────────────────────────────────────────
seedAchievements().catch(console.error);
seedCatalog().catch(console.error);

// ─── 404 Fallback ─────────────────────────────────────────────────────────────
app.notFound((c) => c.json({ success: false, error: "Route not found" }, 404));

app.onError((err, c) => {
  if (err instanceof AppError) {
    return fail(c, err.message, err.statusCode as 400, err.code);
  }
  console.error("Unhandled error:", err);
  return fail(c, "Internal server error", 500);
});

// ─── Start ────────────────────────────────────────────────────────────────────
const port = parseInt(env.PORT);

export default {
  port,
  fetch: app.fetch,
  idleTimeout: 120,
};

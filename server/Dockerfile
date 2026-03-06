FROM oven/bun:1 AS base
WORKDIR /app

# Install dependencies (cached layer)
FROM base AS deps
COPY server/package.json server/bun.lock* ./
RUN bun install --frozen-lockfile

# Production image
FROM base AS runner
COPY --from=deps /app/node_modules ./node_modules
COPY server/ .

# Default: run the API server
# Override CMD in Railway worker service to: bun run src/worker.ts
CMD ["bun", "run", "src/index.ts"]

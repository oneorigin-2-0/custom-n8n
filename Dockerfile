# --- Stage 1: Builder ---
FROM node:22-slim AS builder

# 1. Install system build tools
RUN apt-get update && apt-get install -y python3 make g++ git jq

# 2. Force a specific, stable PNPM version (v9)
# We use 'jq' to delete the "packageManager" field from package.json
# so it stops trying to download pnpm v10 automatically.
RUN corepack enable && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

# Copy all files
COPY . .

# 3. SURGICAL FIX: Remove the forced pnpm version from package.json
RUN jq 'del(.packageManager)' package.json > temp.json && mv temp.json package.json

# 4. Install dependencies WITHOUT running heavy scripts
# This prevents the "ELIFECYCLE" crash by skipping post-install compilations
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm install --no-frozen-lockfile --ignore-scripts

# 5. Build the application
# We run the build explicitly now
RUN pnpm build

# 6. Clean up (Prune)
RUN pnpm prune --prod

# --- Stage 2: Runner ---
FROM node:22-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y graphicsmagick dumb-init

# Copy the compiled app from the builder stage
COPY --from=builder /app /app

# Set Environment
ENV NODE_ENV=production
ENV PORT=5678
EXPOSE 5678

# Start
CMD ["node", "packages/cli/bin/n8n"]

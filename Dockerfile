# --- Stage 1: Build ---
FROM node:22-slim AS builder

# 1. Install basics
RUN apt-get update && apt-get install -y python3 make g++ git

# 2. Block heavy/useless downloads (Saves RAM & prevents crashes)
ENV CYPRESS_INSTALL_BINARY=0
ENV PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

# 3. Use a specific, stable PNPM version (Safe for n8n)
RUN corepack enable && corepack prepare pnpm@9.12.0 --activate

WORKDIR /app

# Copy source
COPY . .

# 4. Install dependencies with increased memory limit
# We use --no-frozen-lockfile to prevent "lockfile mismatch" errors since you forked it
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm install --no-frozen-lockfile

# 5. Build
RUN pnpm build

# 6. Prune (Remove dev files)
RUN pnpm prune --prod

# --- Stage 2: Run ---
FROM node:22-slim

WORKDIR /app

# Install runtime basics
RUN apt-get update && apt-get install -y graphicsmagick dumb-init

# Copy built app
COPY --from=builder /app /app

ENV NODE_ENV=production
ENV PORT=5678
EXPOSE 5678

# Start
CMD ["node", "packages/cli/bin/n8n"]

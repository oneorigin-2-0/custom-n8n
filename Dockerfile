# --- Stage 1: Build ---
FROM node:22-slim AS builder

# 1. Install system tools
RUN apt-get update && apt-get install -y python3 make g++ git

# 2. FORCE install pnpm v10+ (Fixes the "Unsupported environment" error)
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# 3. Copy source files
COPY . .

# 4. Install dependencies
# We use --max-old-space-size to try and prevent your NAS from crashing out of RAM
ENV NODE_OPTIONS="--max-old-space-size=4096"
RUN pnpm install --no-frozen-lockfile

# 5. Build
RUN pnpm build

# 6. Prune (Clean up)
RUN pnpm prune --prod

# --- Stage 2: Run ---
FROM node:22-slim

WORKDIR /app

# Runtime dependencies
RUN apt-get update && apt-get install -y graphicsmagick dumb-init

# Copy built app
COPY --from=builder /app /app

ENV NODE_ENV=production
ENV PORT=5678
EXPOSE 5678

CMD ["node", "packages/cli/bin/n8n"]

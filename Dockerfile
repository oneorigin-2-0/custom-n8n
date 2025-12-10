# --- Stage 1: Build ---
FROM node:22-slim AS builder

# Install system dependencies for native modules
RUN apt-get update && apt-get install -y \
    python3 \
    make \
    g++ \
    git \
    build-essential \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    librsvg2-dev \
    libpixman-1-dev \
    && rm -rf /var/lib/apt/lists/*

# Pin to pnpm 9.x
RUN corepack enable && corepack prepare pnpm@9.15.0 --activate

WORKDIR /app

# Copy everything at once - simpler and works with any repo structure
COPY . .

# Memory management + reduced concurrency for NAS
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Install dependencies
RUN pnpm install --no-frozen-lockfile

# Build
RUN pnpm build

# Prune dev dependencies
RUN pnpm prune --prod

# --- Stage 2: Run ---
FROM node:22-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    graphicsmagick \
    tini \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app

ENV NODE_ENV=production
ENV N8N_PORT=5678

EXPOSE 5678

ENTRYPOINT ["tini", "--"]
CMD ["node", "packages/cli/bin/n8n"]

# --- Stage 1: Build ---
FROM node:22-slim AS builder

# Install system dependencies
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

# Enable corepack for pnpm 10.x
RUN corepack enable

WORKDIR /app

# Copy everything
COPY . .

# Memory management
ENV NODE_OPTIONS="--max-old-space-size=4096"

# Step 1: Install deps WITHOUT running lifecycle scripts (this will succeed)
RUN pnpm install --no-frozen-lockfile --ignore-scripts

# Step 2: Run postinstall scripts explicitly with full output
RUN pnpm rebuild || true

# Step 3: Build - this will show actual errors
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

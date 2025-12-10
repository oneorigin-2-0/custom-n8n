# --- Stage 1: Build ---
FROM node:22-slim AS builder

# 1. Install ALL system dependencies n8n needs for native modules
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

# 2. Enable corepack and install pnpm
RUN corepack enable && corepack prepare pnpm@9.15.0 --activate

WORKDIR /app

# 3. Copy package files first for better caching
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY patches ./patches/

# 4. Copy all package.json files from workspaces
COPY packages/cli/package.json ./packages/cli/
COPY packages/core/package.json ./packages/core/
COPY packages/design-system/package.json ./packages/design-system/
COPY packages/editor-ui/package.json ./packages/editor-ui/
COPY packages/nodes-base/package.json ./packages/nodes-base/
COPY packages/workflow/package.json ./packages/workflow/
COPY packages/@n8n ./packages/@n8n/

# 5. Install dependencies with extra memory and verbose logging
ENV NODE_OPTIONS="--max-old-space-size=8192"
RUN pnpm install --no-frozen-lockfile --reporter=append-only 2>&1 | tee /tmp/install.log || \
    (echo "=== INSTALL FAILED - Last 100 lines ===" && tail -100 /tmp/install.log && exit 1)

# 6. Now copy all source code
COPY . .

# 7. Build with extra memory
RUN pnpm build

# 8. Prune dev dependencies
RUN pnpm prune --prod

# --- Stage 2: Run ---
FROM node:22-slim

WORKDIR /app

# Runtime dependencies for GraphicsMagick and other native modules
RUN apt-get update && apt-get install -y \
    graphicsmagick \
    dumb-init \
    tini \
    && rm -rf /var/lib/apt/lists/*

# Copy built application
COPY --from=builder /app /app

ENV NODE_ENV=production
ENV N8N_PORT=5678
ENV GENERIC_TIMEZONE=America/Phoenix

EXPOSE 5678

ENTRYPOINT ["tini", "--"]
CMD ["node", "packages/cli/bin/n8n"]

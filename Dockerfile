FROM node:22-slim AS builder

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
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable

WORKDIR /app
COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN pnpm install --no-frozen-lockfile --ignore-scripts

# Rebuild native modules for x86
RUN pnpm rebuild

# Build packages one at a time to manage memory
RUN pnpm --filter=n8n-workflow build
RUN pnpm --filter=n8n-core build  
RUN pnpm --filter=n8n-nodes-base build
RUN pnpm --filter=@n8n/n8n-nodes-langchain build
RUN pnpm --filter=n8n-editor-ui build
RUN pnpm --filter=n8n build

RUN pnpm prune --prod

FROM node:22-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    graphicsmagick \
    tini \
    libsqlite3-0 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app

ENV NODE_ENV=production
ENV N8N_PORT=5678

EXPOSE 5678

ENTRYPOINT ["tini", "--"]
CMD ["node", "packages/cli/bin/n8n"]

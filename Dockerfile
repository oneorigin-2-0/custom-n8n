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
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable

WORKDIR /app
COPY . .

ENV NODE_OPTIONS="--max-old-space-size=16384"

RUN pnpm install --no-frozen-lockfile --ignore-scripts

RUN pnpm rebuild

RUN pnpm build

RUN pnpm prune --prod

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

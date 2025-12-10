FROM node:22-slim

RUN apt-get update && apt-get install -y \
    python3 make g++ git build-essential \
    libcairo2-dev libpango1.0-dev libjpeg-dev libgif-dev \
    librsvg2-dev libpixman-1-dev libsqlite3-dev \
    graphicsmagick tini \
    && rm -rf /var/lib/apt/lists/*

RUN corepack enable

WORKDIR /app
COPY . .

ENV NODE_OPTIONS="--max-old-space-size=4096"

RUN pnpm install --no-frozen-lockfile --ignore-scripts
RUN pnpm --filter=@n8n/config --filter=@n8n/errors build
RUN pnpm build
RUN pnpm prune --prod

ENV NODE_ENV=production
ENV N8N_PORT=5678

EXPOSE 5678

ENTRYPOINT ["tini", "--"]
CMD ["node", "packages/cli/bin/n8n"]

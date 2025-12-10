# --- Stage 1: Build the Application ---
# UPDATED: Changed from node:20 to node:22
FROM node:22-slim AS builder

# Install system dependencies
RUN apt-get update && apt-get install -y python3 make g++ git

# Enable pnpm
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy source
COPY . .

# Install and build
# This will now pass because we are on Node 22
RUN pnpm install
RUN pnpm build

# Prune dev dependencies
RUN pnpm prune --prod

# --- Stage 2: Run the Application ---
# UPDATED: Changed from node:20 to node:22
FROM node:22-slim

WORKDIR /app

# Install runtime dependencies
RUN apt-get update && apt-get install -y graphicsmagick dumb-init

# Copy built app
COPY --from=builder /app /app

# Env vars
ENV NODE_ENV=production
ENV PORT=5678

EXPOSE 5678

# Start
CMD ["node", "packages/cli/bin/n8n"]

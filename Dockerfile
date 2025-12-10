# --- Stage 1: Build the Application ---
FROM node:20-slim AS builder

# Install system dependencies required for building
RUN apt-get update && apt-get install -y python3 make g++ git

# Enable pnpm (n8n uses pnpm, not npm)
RUN corepack enable && corepack prepare pnpm@latest --activate

WORKDIR /app

# Copy all source code
COPY . .

# Install dependencies and build
# This step takes time! It compiles the whole project.
RUN pnpm install
RUN pnpm build

# Remove development files to keep the image smaller
RUN pnpm prune --prod

# --- Stage 2: Run the Application ---
FROM node:20-slim

WORKDIR /app

# Install runtime dependencies (fonts, graphics tools for n8n)
RUN apt-get update && apt-get install -y graphicsmagick dumb-init

# Copy the built application from Stage 1
COPY --from=builder /app /app

# Set environment variables
ENV NODE_ENV=production
ENV PORT=5678

EXPOSE 5678

# Start n8n using the CLI bin
CMD ["node", "packages/cli/bin/n8n"]

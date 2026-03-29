# Dashboard Container
# Builds the React frontend and runs the Node.js aggregation server

# --- Build stage ---
FROM oven/bun:1 AS builder

WORKDIR /app

# Copy package files
COPY package.json bun.lock* ./

# Install dependencies
RUN bun install --frozen-lockfile

# Copy source
COPY . .

# Build frontend (Vite) and server (TSC)
RUN bun run build:all

# --- Production stage ---
FROM node:22-bookworm-slim

WORKDIR /app

# Copy package files and install production deps only
COPY package.json ./
COPY --from=builder /app/node_modules ./node_modules

# Copy built frontend
COPY --from=builder /app/dist ./dist

# Copy built server
COPY --from=builder /app/dist-server ./dist-server

# Expose port
EXPOSE 3000

ENV PORT=3000
ENV NODE_ENV=production

CMD ["node", "dist-server/index.js"]

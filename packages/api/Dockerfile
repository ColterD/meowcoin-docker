# --- Builder stage ---
FROM node:20-alpine AS builder

WORKDIR /repo

# Copy monorepo package files
COPY package.json ./
COPY package-lock.json ./
COPY packages ./packages

# Install all dependencies (including workspaces)
RUN npm install

# Build shared and api packages
RUN npm run build --workspace packages/shared && npm run build --workspace packages/api

# --- Production stage ---
FROM node:20-alpine

WORKDIR /app

# Copy only API package.json for production install
COPY packages/api/package.json ./
COPY package.json ./
COPY package-lock.json ./

# Install production dependencies for API only
RUN npm install --omit=dev

# Copy root node_modules to ensure hoisted dependencies are available
COPY --from=builder /repo/node_modules ./node_modules

# Copy built API dist from builder (flattened for runtime)
COPY --from=builder /repo/packages/api/dist/packages/api/src ./dist
# Copy full shared package for monorepo runtime
COPY --from=builder /repo/packages/shared ./node_modules/@meowcoin/shared
# Copy full blockchain package for monorepo runtime
COPY --from=builder /repo/packages/blockchain ./node_modules/@meowcoin/blockchain

# Copy config if needed (optional, handled by compose)
# COPY --from=builder /repo/config ./config

ENV NODE_ENV=production
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
CMD ["node", "dist/index.js"]
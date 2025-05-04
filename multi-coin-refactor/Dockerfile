# Multi-stage build for Multi-Coin Blockchain Platform
# May 2025 Best Practices

# Build stage
FROM node:20-alpine AS build

# Set working directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci

# Copy source code
COPY . .

# Build the application
RUN npm run build

# Production stage
FROM node:20-alpine AS production

# Set working directory
WORKDIR /app

# Set environment variables
ENV NODE_ENV=production
ENV PORT=12000

# Copy package files
COPY package*.json ./

# Install production dependencies only
RUN npm ci --only=production

# Copy built files from build stage
COPY --from=build /app/dist ./dist
COPY --from=build /app/public ./public
COPY --from=build /app/server ./server

# Create data directory for SQLite databases
RUN mkdir -p /app/data && \
    chown -R node:node /app/data

# Use non-root user for security
USER node

# Expose port
EXPOSE 12000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:12000/api/v1/health || exit 1

# Start the application
CMD ["node", "server/index.js"]
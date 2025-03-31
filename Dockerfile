# Build stage for shared types module
FROM node:18-alpine AS shared-builder
WORKDIR /app/shared

# Copy shared module files
COPY shared/package*.json ./
COPY shared/tsconfig.json ./
COPY shared/src ./src

# Install dependencies and build
RUN npm install
RUN npm run build

# Build stage for backend
FROM node:18-alpine AS backend-builder
WORKDIR /app/backend

# Copy package files and install dependencies
COPY backend/package*.json ./
RUN npm install

# Create a tsconfig.json file
RUN echo '{"compilerOptions":{"target":"ES2020","module":"CommonJS","outDir":"./dist","rootDir":"./src","esModuleInterop":true,"skipLibCheck":true,"forceConsistentCasingInFileNames":true},"include":["src/**/*"],"exclude":["node_modules"]}' > tsconfig.json

# Create a simple backend
RUN mkdir -p src && echo 'import express from "express";\nimport http from "http";\nimport { Server } from "socket.io";\nimport cors from "cors";\nimport path from "path";\n\nconst app = express();\nconst server = http.createServer(app);\nconst io = new Server(server, {\n  cors: {\n    origin: "*",\n    methods: ["GET", "POST"]\n  }\n});\n\napp.use(cors());\napp.use(express.json());\n\napp.use(express.static("/var/www/html"));\n\napp.get("/api/status", (req, res) => {\n  res.json({\n    status: "running",\n    blockchain: {\n      blocks: 0,\n      headers: 0,\n      progress: "0.00"\n    },\n    node: {\n      version: "Meow-v2.0.5",\n      connections: 0,\n      bytesReceived: 0,\n      bytesSent: 0\n    },\n    system: {\n      memory: {\n        used: 0,\n        total: 0,\n        percent: "0.0"\n      },\n      disk: {\n        size: "0G",\n        used: "0G",\n        percent: 0\n      }\n    }\n  });\n});\n\napp.get("*", (req, res) => {\n  res.sendFile(path.resolve("/var/www/html/index.html"));\n});\n\nconst PORT = process.env.PORT || 8080;\nserver.listen(PORT, () => {\n  console.log(`Server running on port ${PORT}`);\n});\n\nprocess.on("SIGTERM", () => {\n  console.log("SIGTERM signal received: closing HTTP server");\n  server.close(() => {\n    console.log("HTTP server closed");\n    process.exit(0);\n  });\n});' > src/index.ts

# Copy the built shared module
COPY --from=shared-builder /app/shared/dist ./node_modules/shared/dist
COPY --from=shared-builder /app/shared/package.json ./node_modules/shared/package.json

# Build backend
RUN npm run build

# Build stage for Meowcoin binaries
FROM debian:bullseye-slim AS meowcoin-builder
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates jq wget tar gzip file && \
    rm -rf /var/lib/apt/lists/*

# Set Meowcoin version
ARG MEOWCOIN_VERSION="Meow-v2.0.5"

# Download Meowcoin binaries
WORKDIR /tmp
RUN set -ex && \
    echo "Downloading Meowcoin version: ${MEOWCOIN_VERSION}" && \
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION}) && \
    DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("x86_64-linux-gnu.tar.gz$")) | .browser_download_url' | head -1) && \
    curl -L -o /tmp/meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    mkdir -p /tmp/extract && \
    tar -xzvf /tmp/meowcoin.tar.gz -C /tmp/extract && \
    mkdir -p /usr/local/bin && \
    DAEMON_PATH=$(find /tmp/extract -name "meowcoind" -type f | head -1) && \
    CLI_PATH=$(find /tmp/extract -name "meowcoin-cli" -type f | head -1) && \
    cp -v "$DAEMON_PATH" /usr/local/bin/ && \
    cp -v "$CLI_PATH" /usr/local/bin/ && \
    chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli

# Final image
FROM debian:bullseye-slim

# Add non-root user first for better security
RUN groupadd -g 10000 meowcoin && \
    useradd -u 10000 -g meowcoin -s /bin/bash -m meowcoin && \
    mkdir -p /data /config /var/www/html/api

# Install dependencies - reduced list with only necessary ones
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl jq ca-certificates nodejs npm \
        procps libboost-system1.74.0 libboost-filesystem1.74.0 \
        gosu python3 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/nginx

# Copy Meowcoin binaries
COPY --from=meowcoin-builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=meowcoin-builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli

# Create a simple HTML file for the frontend
RUN echo '<!DOCTYPE html><html><head><title>Meowcoin Dashboard</title><style>body{font-family:Arial,sans-serif;max-width:800px;margin:0 auto;padding:20px}.card{border:1px solid #ccc;border-radius:5px;padding:20px;margin-bottom:20px}.status{display:inline-block;padding:5px 10px;border-radius:5px;background-color:#4CAF50;color:white}</style></head><body><h1>Meowcoin Dashboard</h1><div class="card"><h2>Node Status</h2><p>Status: <span class="status">Running</span></p><p>Version: Meow-v2.0.5</p><p>Connections: 0</p></div><div class="card"><h2>Blockchain Info</h2><p>Blocks: 0</p><p>Sync Progress: 0%</p></div><div class="card"><h2>System Resources</h2><p>Memory: 0%</p><p>Disk: 0%</p></div><div class="card"><h2>API Endpoints</h2><p><a href="/api/status">/api/status</a> - Get node status information</p></div><footer><p>Meowcoin Node Dashboard © 2025</p></footer></body></html>' > /var/www/html/index.html

# Copy backend files
COPY --from=backend-builder /app/backend/dist /app/backend/dist
COPY --from=backend-builder /app/backend/package.json /app/backend/
WORKDIR /app/backend

# Install production dependencies
RUN npm install --only=production

# Add scripts and configs
COPY scripts/functions.sh /scripts/
COPY scripts/auto-configure.sh /scripts/
COPY scripts/entrypoint.sh /scripts/
COPY scripts/healthcheck.sh /scripts/
COPY scripts/backup-manager.sh /scripts/
COPY scripts/update-node.sh /scripts/
RUN chmod +x /scripts/*.sh

# Set proper ownership
RUN chown -R meowcoin:meowcoin /data /config /var/www/html /app

# Set up volumes and ports
VOLUME ["/data", "/config"]
EXPOSE 9766 8788 8080

# Environment variables
ENV HOME=/home/meowcoin \
    MEOWCOIN_DATA=/data \
    MEOWCOIN_CONFIG=/config \
    PATH=/scripts:$PATH \
    NODE_ENV=production

# Set up healthcheck
HEALTHCHECK --interval=60s --timeout=10s --start-period=30s --retries=3 \
  CMD ["/scripts/healthcheck.sh"]

# Start both the Meowcoin daemon and web server
ENTRYPOINT ["/scripts/entrypoint.sh"]
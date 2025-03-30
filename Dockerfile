# Build stage for React frontend
FROM node:18-alpine as frontend-builder
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build

# Build stage for Node.js backend
FROM node:18-alpine as backend-builder
WORKDIR /app/backend
COPY backend/package*.json ./
RUN npm ci
COPY backend/ ./
RUN npm run build

# Build stage for Meowcoin binaries
FROM debian:stable-slim as meowcoin-builder
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
FROM debian:stable-slim

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl jq ca-certificates bc nodejs npm \
        procps libboost-system1.74.0 libboost-filesystem1.74.0 \
        libboost-program-options1.74.0 libboost-thread1.74.0 \
        libboost-chrono1.74.0 gosu file docker.io && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/nginx

# Copy Meowcoin binaries
COPY --from=meowcoin-builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=meowcoin-builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli

# Copy frontend files
COPY --from=frontend-builder /app/frontend/dist /var/www/html

# Copy backend files
COPY --from=backend-builder /app/backend/dist /app/backend
COPY backend/package*.json /app/backend/
WORKDIR /app/backend
RUN npm ci --production

# Add scripts and configs (only the essential ones we still need)
COPY scripts/functions.sh /scripts/
COPY scripts/auto-configure.sh /scripts/
COPY scripts/entrypoint.sh /scripts/
COPY scripts/healthcheck.sh /scripts/
COPY scripts/backup-manager.sh /scripts/
RUN chmod +x /scripts/*.sh

# Create meowcoin user
RUN groupadd -g 10000 meowcoin && \
    useradd -u 10000 -g meowcoin -s /bin/bash -m meowcoin && \
    mkdir -p /data /config /var/www/html/api && \
    chown -R meowcoin:meowcoin /data /config /var/www/html

# Set up volumes and ports
VOLUME ["/data", "/config"]
EXPOSE 9766 8788 8080

# Environment variables
ENV HOME=/home/meowcoin \
    MEOWCOIN_DATA=/data \
    MEOWCOIN_CONFIG=/config \
    PATH=/scripts:$PATH

# Start both the Meowcoin daemon and web server
ENTRYPOINT ["/scripts/entrypoint.sh"]
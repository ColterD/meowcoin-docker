# Build stage
FROM debian:stable-slim as builder

# Install dependencies for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates jq wget tar gzip file && \
    rm -rf /var/lib/apt/lists/*

# Set Meowcoin version
ARG MEOWCOIN_VERSION="Meow-v2.0.5"

# Download Meowcoin binaries with better debugging and error handling
WORKDIR /tmp
RUN set -ex && \
    echo "Downloading Meowcoin version: ${MEOWCOIN_VERSION}" && \
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION}) && \
    echo "Assets: ${RELEASE_ASSETS}" && \
    # Fix the pattern to correctly match the x86_64 Linux binary
    DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("x86_64-linux-gnu.tar.gz$")) | .browser_download_url' | head -1) && \
    echo "Download URL: ${DOWNLOAD_URL}" && \
    if [ -z "${DOWNLOAD_URL}" ]; then \
        echo "Could not find Linux tarball!" && \
        echo "Available assets:" && \
        echo "${RELEASE_ASSETS}" | jq -r '.assets[] | .name' && \
        exit 1; \
    fi && \
    echo "Downloading: ${DOWNLOAD_URL}" && \
    curl -L -o /tmp/meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    mkdir -p /tmp/extract && \
    tar -xzvf /tmp/meowcoin.tar.gz -C /tmp/extract && \
    echo "Archive contents:" && \
    find /tmp/extract -type f -exec ls -la {} \; && \
    # Create bin directory
    mkdir -p /usr/local/bin && \
    # Find and copy binaries with error handling
    DAEMON_PATH=$(find /tmp/extract -name "meowcoind" -type f | head -1) && \
    if [ -z "$DAEMON_PATH" ]; then \
        echo "ERROR: meowcoind binary not found in downloaded archive!" && \
        echo "Archive contents:" && \
        find /tmp/extract -type f && \
        exit 1; \
    fi && \
    CLI_PATH=$(find /tmp/extract -name "meowcoin-cli" -type f | head -1) && \
    if [ -z "$CLI_PATH" ]; then \
        echo "ERROR: meowcoin-cli binary not found in downloaded archive!" && \
        echo "Archive contents:" && \
        find /tmp/extract -type f && \
        exit 1; \
    fi && \
    # Copy binaries
    cp -v "$DAEMON_PATH" /usr/local/bin/ && \
    cp -v "$CLI_PATH" /usr/local/bin/ && \
    # Verify binaries are present and executable
    if [ ! -f "/usr/local/bin/meowcoind" ]; then \
        echo "ERROR: Failed to copy meowcoind binary!" && \
        exit 1; \
    fi && \
    if [ ! -f "/usr/local/bin/meowcoin-cli" ]; then \
        echo "ERROR: Failed to copy meowcoin-cli binary!" && \
        exit 1; \
    fi && \
    # Check binary type
    file /usr/local/bin/meowcoind && \
    file /usr/local/bin/meowcoin-cli && \
    chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli && \
    # Verify executables work
    /usr/local/bin/meowcoind --version || echo "WARNING: Could not execute meowcoind in builder"

# Runtime stage (using Debian instead of Alpine for better compatibility)
FROM debian:stable-slim

# Install dependencies - we're using gosu instead of su-exec
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl jq ca-certificates bc python3 nginx \
        procps libboost-system1.74.0 libboost-filesystem1.74.0 \
        libboost-program-options1.74.0 libboost-thread1.74.0 \
        libboost-chrono1.74.0 gosu file \
        libnginx-mod-http-lua && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/nginx

# Copy binaries from builder stage with verbose output and verification
COPY --from=builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN ls -la /usr/local/bin && \
    file /usr/local/bin/meowcoind && \
    file /usr/local/bin/meowcoin-cli && \
    chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli && \
    echo "Verifying binaries copy was successful..." && \
    if [ ! -f "/usr/local/bin/meowcoind" ]; then \
        echo "ERROR: meowcoind binary missing after COPY!" && \
        exit 1; \
    fi && \
    if [ ! -f "/usr/local/bin/meowcoin-cli" ]; then \
        echo "ERROR: meowcoin-cli binary missing after COPY!" && \
        exit 1; \
    fi

# Add scripts and configs
COPY scripts/ /scripts/
COPY web/ /var/www/html/
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

# Entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
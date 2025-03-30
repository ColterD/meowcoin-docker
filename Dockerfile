# Build stage
FROM debian:stable-slim as builder

# Install dependencies for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates jq wget tar gzip && \
    rm -rf /var/lib/apt/lists/*

# Set Meowcoin version
ARG MEOWCOIN_VERSION="Meow-v2.0.5"

# Download Meowcoin binaries with better debugging
WORKDIR /tmp
RUN set -ex && \
    echo "Downloading Meowcoin version: ${MEOWCOIN_VERSION}" && \
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION}) && \
    echo "Assets: ${RELEASE_ASSETS}" && \
    DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("linux.*x86_64.*tar.gz$")) | .browser_download_url' | head -1) && \
    echo "Download URL: ${DOWNLOAD_URL}" && \
    if [ -z "${DOWNLOAD_URL}" ]; then \
        echo "Could not find Linux tarball!" && \
        exit 1; \
    fi && \
    echo "Downloading: ${DOWNLOAD_URL}" && \
    curl -L -o /tmp/meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    mkdir -p /tmp/extract && \
    tar -xzvf /tmp/meowcoin.tar.gz -C /tmp/extract && \
    echo "Archive contents:" && \
    find /tmp/extract -type f -name "meowcoin*" && \
    # Create bin directory
    mkdir -p /usr/local/bin && \
    # Find and copy binaries (use cp directly)
    find /tmp/extract -name "meowcoind" -type f -exec cp -v {} /usr/local/bin/ \; && \
    find /tmp/extract -name "meowcoin-cli" -type f -exec cp -v {} /usr/local/bin/ \; && \
    # Verify binaries are present
    ls -la /usr/local/bin && \
    # Set permissions
    chmod +x /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli || true

# Runtime stage (using Debian instead of Alpine for better compatibility)
FROM debian:stable-slim

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl jq ca-certificates bc python3 nginx \
        procps libboost-system1.74.0 libboost-filesystem1.74.0 \
        libboost-program-options1.74.0 libboost-thread1.74.0 \
        libboost-chrono1.74.0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/nginx

# Copy binaries from builder stage (with verbose output)
COPY --from=builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN ls -la /usr/local/bin && \
    chmod +x /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli || echo "Setting permissions failed"

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
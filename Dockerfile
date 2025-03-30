# Build stage
FROM debian:11-slim as builder

# Install dependencies for building
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates jq wget tar gzip && \
    rm -rf /var/lib/apt/lists/*

<<<<<<< HEAD
# Set working directory
=======
# Set Meowcoin version
ARG MEOWCOIN_VERSION="Meow-v2.0.5"

# Download Meowcoin binaries with better debugging
>>>>>>> parent of 0706e65 (refactor)
WORKDIR /tmp

# Fetch the latest Meowcoin version dynamically
ARG MEOWCOIN_VERSION="Meow-v2.0.5"
RUN set -ex && \
    echo "Fetching latest Meowcoin release from GitHub..." && \
    LATEST_VERSION=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest | jq -r '.tag_name') && \
    echo "Latest version: ${LATEST_VERSION}" && \
    echo "Current version: ${MEOWCOIN_VERSION}" && \
    if [ "${LATEST_VERSION}" != "${MEOWCOIN_VERSION}" ]; then \
        echo "Newer version available: ${LATEST_VERSION}" && \
        echo "Would you like to upgrade from ${MEOWCOIN_VERSION} to ${LATEST_VERSION}? (yes/no)" && \
        echo "Set MEOWCOIN_VERSION=${LATEST_VERSION} in your build args to upgrade." && \
        echo "Continuing with ${MEOWCOIN_VERSION} for now..."; \
    else \
        echo "Using latest version: ${MEOWCOIN_VERSION}"; \
    fi && \
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION}) && \
<<<<<<< HEAD
    DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("x86_64-linux-gnu.(tar.gz|tgz)$")) | .browser_download_url' | head -1) && \
    if [ -z "${DOWNLOAD_URL}" ]; then \
        echo "Could not find Linux tarball for version ${MEOWCOIN_VERSION}!" && \
        echo "Available assets:" && \
        echo "${RELEASE_ASSETS}" | jq -r '.assets[] | .name' && \
=======
    echo "Assets: ${RELEASE_ASSETS}" && \
    DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("linux.*x86_64.*tar.gz$")) | .browser_download_url' | head -1) && \
    echo "Download URL: ${DOWNLOAD_URL}" && \
    if [ -z "${DOWNLOAD_URL}" ]; then \
        echo "Could not find Linux tarball!" && \
>>>>>>> parent of 0706e65 (refactor)
        exit 1; \
    fi && \
    echo "Downloading: ${DOWNLOAD_URL}" && \
    curl -L -o /tmp/meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    mkdir -p /tmp/extract && \
    tar -xzvf /tmp/meowcoin.tar.gz -C /tmp/extract && \
<<<<<<< HEAD
    mkdir -p /usr/local/bin && \
    DAEMON_PATH=$(find /tmp/extract -name "meowcoind" -type f | head -1) && \
    CLI_PATH=$(find /tmp/extract -name "meowcoin-cli" -type f | head -1) && \
    [ -n "$DAEMON_PATH" ] || { echo "ERROR: meowcoind not found!"; exit 1; } && \
    [ -n "$CLI_PATH" ] || { echo "ERROR: meowcoin-cli not found!"; exit 1; } && \
    cp -v "$DAEMON_PATH" /usr/local/bin/ && \
    cp -v "$CLI_PATH" /usr/local/bin/ && \
    chmod 755 /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli
=======
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
>>>>>>> parent of 0706e65 (refactor)

# Runtime stage
FROM debian:11-slim

<<<<<<< HEAD
# Install runtime dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash curl jq ca-certificates bc python3 nginx procps \
    libboost-system1.74.0 libboost-filesystem1.74.0 \
    libboost-program-options1.74.0 libboost-thread1.74.0 \
    libboost-chrono1.74.0 gosu file && \
=======
# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        bash curl jq ca-certificates bc python3 nginx \
        procps libboost-system1.74.0 libboost-filesystem1.74.0 \
        libboost-program-options1.74.0 libboost-thread1.74.0 \
        libboost-chrono1.74.0 && \
>>>>>>> parent of 0706e65 (refactor)
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    mkdir -p /run/nginx

<<<<<<< HEAD
# Copy binaries from builder
COPY --from=builder --chown=meowcoin:meowcoin /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=builder --chown=meowcoin:meowcoin /usr/local/bin/meowcoin-cli /usr/local/bin/
=======
# Copy binaries from builder stage (with verbose output)
COPY --from=builder /usr/local/bin/meowcoind /usr/local/bin/
COPY --from=builder /usr/local/bin/meowcoin-cli /usr/local/bin/
RUN ls -la /usr/local/bin && \
    chmod +x /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli || echo "Setting permissions failed"
>>>>>>> parent of 0706e65 (refactor)

# Add scripts and web content
COPY --chown=meowcoin:meowcoin scripts/ /scripts/
COPY --chown=meowcoin:meowcoin web/ /var/www/html/
RUN chmod +x /scripts/*.sh

# Create meowcoin user and directories
RUN groupadd -g 10000 meowcoin && \
    useradd -u 10000 -g meowcoin -s /bin/bash -m meowcoin && \
    mkdir -p /data /data/backups /data/.meowcoin /config /var/www/html/api && \
    chown -R meowcoin:meowcoin /data /config /var/www/html

# Set up volumes and ports
VOLUME ["/data", "/config"]
EXPOSE 9766 8788 8080

# Environment variables
ENV HOME=/home/meowcoin \
    MEOWCOIN_DATA=/data \
    MEOWCOIN_CONFIG=/config \
    PATH=/scripts:$PATH

# Healthcheck
HEALTHCHECK --interval=1m --timeout=10s --retries=3 --start-period=30s \
    CMD /scripts/healthcheck.sh

# Metadata
LABEL version="2.0.5" \
      maintainer="Meowcoin Foundation <support@meowcoin.org>"

# Run as non-root user
USER meowcoin

# Entrypoint
ENTRYPOINT ["/scripts/entrypoint.sh"]
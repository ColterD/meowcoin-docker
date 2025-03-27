# Build stage
FROM ubuntu:22.04 AS builder

# Set ARG for BuildKit cache control
ARG BUILDKIT_INLINE_CACHE=1

# Add labels for better maintainability
LABEL org.opencontainers.image.source="https://github.com/Meowcoin-Foundation/Meowcoin-docker"
LABEL org.opencontainers.image.description="Docker image for Meowcoin Core"
LABEL org.opencontainers.image.licenses="MIT"

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libssl-dev \
    libboost-all-dev \
    libminiupnpc-dev \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy version file
COPY meowcoin_version.txt .

# Build Meowcoin with proper caching
RUN MEOWCOIN_VERSION=$(cat meowcoin_version.txt) && \
    git clone --depth 1 --branch $MEOWCOIN_VERSION https://github.com/Meowcoin-Foundation/Meowcoin.git && \
    cd Meowcoin && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-tests --disable-bench && \
    make -j$(nproc) && \
    make install DESTDIR=/install

# Runtime stage
FROM ubuntu:22.04

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker image for Meowcoin Core"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libssl3 \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-thread1.74.0 \
    libboost-chrono1.74.0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create meowcoin user with specific UID/GID for better security
RUN groupadd -r meowcoin -g 1000 && \
    useradd -r -m -u 1000 -g meowcoin meowcoin

# Copy binaries from builder
COPY --from=builder /install/usr/bin/meowcoin* /usr/bin/

# Copy default config template
COPY config/meowcoin.conf.template /home/meowcoin/.meowcoin/meowcoin.conf.template

# Copy entrypoint script
COPY scripts/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Copy version information
COPY meowcoin_version.txt /meowcoin_version.txt

# Data directory with proper permissions
RUN mkdir -p /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Switch to non-root user
USER meowcoin
WORKDIR /home/meowcoin

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports
EXPOSE 8332 8333

# Health check with realistic timeouts accounting for initial sync
HEALTHCHECK --interval=1m --timeout=30s --start-period=30m --retries=3 \
  CMD meowcoin-cli -datadir=/home/meowcoin/.meowcoin getblockchaininfo > /dev/null 2>&1 || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command if no arguments provided
CMD ["meowcoind"]
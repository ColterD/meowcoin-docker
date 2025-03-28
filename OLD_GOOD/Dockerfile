# Build stage
FROM ubuntu:22.04 AS builder

# Set ARG for BuildKit cache control and version
ARG BUILDKIT_INLINE_CACHE=1
ARG MEOWCOIN_VERSION

# Add labels for better maintainability
LABEL org.opencontainers.image.source="https://github.com/ColterD/meowcoin-docker"
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

# Copy version file or use ARG
COPY meowcoin_version.txt .
RUN if [ -z "$MEOWCOIN_VERSION" ]; then \
    MEOWCOIN_VERSION=$(cat meowcoin_version.txt); \
    else echo $MEOWCOIN_VERSION > meowcoin_version.txt; \
    fi

# Build Meowcoin with proper caching
RUN MEOWCOIN_VERSION=$(cat meowcoin_version.txt) && \
    git clone --depth 1 --branch $MEOWCOIN_VERSION https://github.com/Meowcoin-Foundation/Meowcoin.git && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-tests --disable-bench && \
    make -j$(nproc) && \
    make install DESTDIR=/install

# Build Prometheus exporter (optional)
RUN apt-get update && apt-get install -y --no-install-recommends \
    golang && \
    rm -rf /var/lib/apt/lists/* && \
    go install github.com/prometheus/meowcoin_exporter@latest && \
    if [ -d /root/go/bin ]; then \
      mkdir -p /install/usr/local/bin/; \
      cp /root/go/bin/meowcoin_exporter /install/usr/local/bin/meowcoin-exporter 2>/dev/null || echo "Exporter not available"; \
    fi

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
    gettext-base \
    openssl \
    cron \
    fail2ban \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Set up fail2ban configuration
COPY config/fail2ban/jail.local /etc/fail2ban/jail.local
COPY config/fail2ban/filter.d/meowcoin-rpc.conf /etc/fail2ban/filter.d/

# Create meowcoin user with specific UID/GID for better security
RUN groupadd -r meowcoin -g 1000 && \
    useradd -r -m -u 1000 -g meowcoin meowcoin

# Copy binaries from builder
COPY --from=builder /install/usr/bin/meowcoin* /usr/bin/

# Handle Prometheus exporter (fix for the error)
COPY --from=builder /install/usr/local/bin/ /usr/local/bin/

# Copy scripts
COPY scripts/entrypoint.sh /entrypoint.sh
COPY scripts/backup-blockchain.sh /usr/local/bin/backup-blockchain.sh
RUN chmod +x /entrypoint.sh && \
    (chmod +x /usr/local/bin/backup-blockchain.sh 2>/dev/null || true)

# Copy supervisor config
COPY config/supervisord.conf /etc/supervisor/conf.d/meowcoin.conf

# Create healthcheck script
RUN echo '#!/bin/sh \n\
meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf getblockchaininfo >/dev/null 2>&1 \n\
exit $?' > /healthcheck.sh && \
chmod +x /healthcheck.sh

# Copy default config template
COPY config/meowcoin.conf.template /home/meowcoin/.meowcoin/meowcoin.conf.template

# Copy version information
COPY meowcoin_version.txt /meowcoin_version.txt

# Data directory with proper permissions
RUN mkdir -p /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports (RPC, P2P, and optionally Prometheus metrics)
EXPOSE 8332 8333 9449 28332

# Health check
HEALTHCHECK --interval=1m --timeout=30s --start-period=30m --retries=3 \
  CMD /healthcheck.sh

# Use supervisor as the entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/meowcoin.conf"]
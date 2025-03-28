# build/Dockerfile
FROM alpine:3.19 AS builder

# Set ARG for BuildKit cache control and version
ARG BUILDKIT_INLINE_CACHE=1
ARG MEOWCOIN_VERSION

# Install build dependencies with explicit versions
RUN apk add --no-cache \
    build-base \
    openssl-dev \
    boost-dev \
    miniupnpc-dev \
    git \
    curl \
    ca-certificates \
    autoconf \
    automake \
    libtool \
    go

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
    cd Meowcoin && \
    ./autogen.sh && \
    ./configure --prefix=/usr --disable-tests --disable-bench && \
    make -j$(nproc) && \
    make install DESTDIR=/install

# Build Prometheus exporter
RUN export GOPATH=/go && \
    mkdir -p /go && \
    go install github.com/prometheus/meowcoin_exporter@latest && \
    mkdir -p /install/usr/local/bin/ && \
    if [ -d /go/bin ]; then \
      cp /go/bin/meowcoin_exporter /install/usr/local/bin/meowcoin-exporter 2>/dev/null || echo "Exporter not available"; \
    fi

# Runtime stage
FROM alpine:3.19

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker image for Meowcoin Core"

# Install runtime dependencies
RUN apk add --no-cache \
    openssl \
    boost-system \
    boost-filesystem \
    boost-thread \
    boost-chrono \
    ca-certificates \
    gettext \
    bash \
    coreutils \
    supervisor \
    fail2ban \
    tzdata \
    shadow

# Create meowcoin user
RUN addgroup -g 1000 -S meowcoin && \
    adduser -u 1000 -S meowcoin -G meowcoin -h /home/meowcoin

# Copy binaries from builder
COPY --from=builder /install/usr/bin/meowcoin* /usr/bin/
COPY --from=builder /install/usr/local/bin/ /usr/local/bin/

# Create necessary directories
RUN mkdir -p /etc/meowcoin \
    /var/log/meowcoin \
    /var/lib/meowcoin \
    /home/meowcoin/.meowcoin/certs \
    /home/meowcoin/.meowcoin/logs \
    /home/meowcoin/.meowcoin/backups && \
    chown -R meowcoin:meowcoin /home/meowcoin

# Copy scripts
COPY scripts/entrypoint/ /usr/local/bin/entrypoint/
COPY scripts/backup/ /usr/local/bin/backup/
COPY scripts/monitoring/ /usr/local/bin/monitoring/

# Setup script permissions
RUN chmod -R +x /usr/local/bin/entrypoint/ /usr/local/bin/backup/ /usr/local/bin/monitoring/ && \
    ln -s /usr/local/bin/entrypoint/main.sh /entrypoint.sh

# Copy supervisor config
COPY config/supervisord/supervisord.conf /etc/supervisor/conf.d/meowcoin.conf

# Copy fail2ban config
COPY config/fail2ban/ /etc/fail2ban/

# Copy config templates
COPY config/templates/ /etc/meowcoin/templates/

# Copy version information
COPY meowcoin_version.txt /meowcoin_version.txt

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports (RPC, P2P, ZMQ, and Prometheus metrics)
EXPOSE 8332 8333 9449 28332

# Health check
HEALTHCHECK --interval=1m --timeout=30s --start-period=30m --retries=3 \
  CMD /usr/local/bin/monitoring/health-check.sh

# Use supervisor as the entrypoint
ENTRYPOINT ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/meowcoin.conf"]
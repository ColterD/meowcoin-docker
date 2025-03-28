# build/Dockerfile
FROM alpine:3.19.1 AS builder

# Set ARG for BuildKit cache control and version
ARG BUILDKIT_INLINE_CACHE=1
ARG MEOWCOIN_VERSION

# Add labels for metadata
LABEL org.opencontainers.image.source="https://github.com/colterd/meowcoin-docker"
LABEL org.opencontainers.image.description="Docker image for Meowcoin Core"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.vendor="ColterD"
LABEL org.opencontainers.image.documentation="https://github.com/colterd/meowcoin-docker/wiki"

# Install build dependencies - pinned versions for reproducibility
RUN apk add --no-cache \
    build-base=0.5-r3 \
    openssl-dev=3.1.4-r5 \
    boost-dev=1.82.0-r1 \
    libevent-dev=2.1.12-r8 \
    miniupnpc-dev=2.2.5-r0 \
    git=2.43.0-r0 \
    curl=8.5.0-r0 \
    ca-certificates=20230506-r0 \
    autoconf=2.71-r2 \
    automake=1.16.5-r1 \
    libtool=2.4.7-r1 \
    go=1.21.7-r0

# Set working directory
WORKDIR /build

# Copy version file or use ARG
COPY meowcoin_version.txt .
RUN if [ -z "$MEOWCOIN_VERSION" ]; then \
    MEOWCOIN_VERSION=$(cat meowcoin_version.txt); \
    else echo $MEOWCOIN_VERSION > meowcoin_version.txt; \
    fi

# Create build info file with detailed information
RUN echo "Build date: $(date -u -Iseconds)" > /build-info.txt && \
    echo "Builder: Alpine $(cat /etc/alpine-release)" >> /build-info.txt && \
    echo "Meowcoin version: $(cat meowcoin_version.txt)" >> /build-info.txt && \
    echo "Build architecture: $(uname -m)" >> /build-info.txt && \
    echo "Compiler: $(cc --version | head -n 1)" >> /build-info.txt

# Verify version format
RUN MEOWCOIN_VERSION=$(cat meowcoin_version.txt) && \
    if [[ ! $MEOWCOIN_VERSION =~ ^Meow-v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?$ ]]; then \
        echo "Error: Invalid version format: $MEOWCOIN_VERSION"; \
        echo "Expected format: Meow-v1.2.3"; \
        exit 1; \
    fi

# Build Meowcoin
RUN MEOWCOIN_VERSION=$(cat meowcoin_version.txt) && \
    echo "Cloning Meowcoin repository at version $MEOWCOIN_VERSION..." && \
    git clone --depth 1 --branch $MEOWCOIN_VERSION https://github.com/Meowcoin-Foundation/Meowcoin.git && \
    cd Meowcoin && \
    echo "Running autogen.sh..." && \
    ./autogen.sh && \
    echo "Running configure with security hardening options..." && \
    ./configure --prefix=/usr \
                --disable-tests \
                --disable-bench \
                --with-gui=no \
                --disable-wallet \
                --without-miniupnpc \
                --enable-hardening \
                --enable-reduce-exports \
                --with-pic \
                --disable-ccache \
                CXXFLAGS="-O2 -pipe -fPIC -fstack-protector-all" \
                LDFLAGS="-Wl,-z,relro,-z,now" && \
    echo "Building Meowcoin..." && \
    make -j$(nproc) && \
    echo "Installing Meowcoin..." && \
    make install DESTDIR=/install && \
    echo "Stripping binaries..." && \
    strip /install/usr/bin/meowcoin* && \
    echo "Build completed successfully at $(date -u -Iseconds)" >> /build-info.txt

# Build Prometheus exporter
RUN export GOPATH=/go && \
    mkdir -p /go && \
    echo "Building Prometheus exporter..." && \
    GO111MODULE=on go install github.com/prometheus/meowcoin_exporter@v0.3.0 && \
    mkdir -p /install/usr/local/bin/ && \
    if [ -d /go/bin ]; then \
      cp /go/bin/meowcoin_exporter /install/usr/local/bin/meowcoin-exporter 2>/dev/null || echo "Exporter not available"; \
      if [ -f /install/usr/local/bin/meowcoin-exporter ]; then \
        strip /install/usr/local/bin/meowcoin-exporter; \
        echo "Prometheus exporter built successfully" >> /build-info.txt; \
      fi \
    else \
      echo "Failed to build Prometheus exporter" >> /build-info.txt; \
    fi

# Verify binary integrity and security
RUN echo "Verifying binary integrity..." && \
    ldd /install/usr/bin/meowcoind | grep -v "not a dynamic executable" >> /build-info.txt && \
    echo "Binary dependencies verified" >> /build-info.txt && \
    sha256sum /install/usr/bin/meowcoin* >> /build-info.txt

# Copy build info
COPY --from=0 /build-info.txt /install/build-info.txt

# Runtime stage with minimized layers
FROM alpine:3.19.1

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker image for Meowcoin Core"
LABEL org.opencontainers.image.source="https://github.com/colterd/meowcoin-docker"
LABEL org.opencontainers.image.description="Docker image for Meowcoin Core"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.documentation="https://github.com/colterd/meowcoin-docker/wiki"
LABEL org.opencontainers.image.created="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
LABEL org.opencontainers.image.version="$(cat /meowcoin_version.txt 2>/dev/null || echo 'unknown')"

# Install runtime dependencies in a single layer to reduce image size
RUN apk add --no-cache \
    openssl=3.1.4-r5 \
    boost-filesystem=1.82.0-r1 \
    boost-thread=1.82.0-r1 \
    boost-system=1.82.0-r1 \
    libevent=2.1.12-r8 \
    ca-certificates=20230506-r0 \
    gettext=0.22.3-r0 \
    bash=5.2.21-r0 \
    jq=1.7.1-r0 \
    coreutils=9.4-r0 \
    supervisor=4.2.5-r2 \
    fail2ban=1.0.2-r3 \
    tzdata=2023d-r0 \
    shadow=4.14.2-r0 \
    curl=8.5.0-r0 \
    tini=0.19.0-r1 && \
    rm -rf /var/cache/apk/*

# Create meowcoin user with specific UID/GID for better security
RUN addgroup -g 1000 -S meowcoin && \
    adduser -u 1000 -S meowcoin -G meowcoin -h /home/meowcoin -s /sbin/nologin

# Create necessary directories with proper permissions in one layer
RUN mkdir -p /etc/meowcoin \
    /var/log/meowcoin \
    /var/lib/meowcoin \
    /home/meowcoin/.meowcoin/certs \
    /home/meowcoin/.meowcoin/logs \
    /home/meowcoin/.meowcoin/backups \
    /data && \
    chown -R meowcoin:meowcoin /home/meowcoin && \
    chown meowcoin:meowcoin /data && \
    chmod 750 /home/meowcoin && \
    chmod 750 /data && \
    chmod 750 /home/meowcoin/.meowcoin

# Copy binaries from builder
COPY --from=builder /install/usr/bin/meowcoin* /usr/bin/
COPY --from=builder /install/usr/local/bin/ /usr/local/bin/
COPY --from=builder /install/build-info.txt /build-info.txt

# Copy scripts and configuration in one layer
COPY scripts/entrypoint/ /usr/local/bin/entrypoint/
COPY scripts/backup/ /usr/local/bin/backup/
COPY scripts/monitoring/ /usr/local/bin/monitoring/
COPY scripts/utils/ /usr/local/bin/utils/
COPY config/supervisord/ /etc/supervisor/conf.d/
COPY config/fail2ban/ /etc/fail2ban/
COPY config/templates/ /etc/meowcoin/templates/
COPY meowcoin_version.txt /meowcoin_version.txt

# Setup script permissions
RUN chmod -R +x /usr/local/bin/entrypoint/ /usr/local/bin/backup/ /usr/local/bin/monitoring/ /usr/local/bin/utils/ && \
    ln -s /usr/local/bin/entrypoint/main.sh /entrypoint.sh && \
    chmod 640 /etc/fail2ban/jail.* && \
    echo "* hard core 0" > /etc/security/limits.conf && \
    echo "* hard nofile 65535" >> /etc/security/limits.conf && \
    echo "* soft nofile 65535" >> /etc/security/limits.conf && \
    sha256sum /usr/bin/meowcoin* > /bin-checksums.txt

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports (RPC, P2P, ZMQ, and Prometheus metrics)
EXPOSE 8332 8333 9449 28332

# Detailed health check 
HEALTHCHECK --interval=5m --timeout=30s --start-period=30m --retries=3 \
  CMD /usr/local/bin/monitoring/health-check.sh || exit 1

# Use tini as init for proper signal handling and zombie process reaping
ENTRYPOINT ["/sbin/tini", "--", "/entrypoint.sh"]
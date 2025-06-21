FROM debian:bookworm-slim

# Add labels for better maintainability
LABEL maintainer="Meowcoin Docker Maintainers"
LABEL description="Meowcoin monitoring service"
LABEL version="2.0"
LABEL org.opencontainers.image.source="https://github.com/ColterD/meowcoin-docker"
LABEL org.opencontainers.image.licenses="MIT"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    curl \
    jq \
    netcat-openbsd \
    tini \
    iputils-ping \
    iproute2 \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for the monitor
RUN adduser --system --group --shell /bin/bash monitor

# Copy the entrypoint script and make it executable
COPY meowcoin-monitor/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create data and log directories
RUN mkdir -p /data && chown -R monitor:monitor /data && \
    mkdir -p /var/log/meowcoin && chown -R monitor:monitor /var/log/meowcoin && \
    chmod 755 /var/log/meowcoin

# Set volumes
VOLUME /data
VOLUME /var/log/meowcoin

# Add healthcheck
HEALTHCHECK --interval=60s --timeout=20s --start-period=120s --retries=5 \
  CMD nc -z meowcoin-core ${MEOWCOIN_RPC_PORT:-9766} -w 10 || nc -z meowcoin-node ${MEOWCOIN_RPC_PORT:-9766} -w 10 || nc -z localhost ${MEOWCOIN_RPC_PORT:-9766} -w 10 || nc -z 127.0.0.1 ${MEOWCOIN_RPC_PORT:-9766} -w 10 || exit 1

# Switch to non-root user
USER monitor
WORKDIR /home/monitor

# Use tini as init for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

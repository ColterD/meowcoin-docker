FROM debian:bookworm-slim

# Add labels
LABEL maintainer="Meowcoin Docker Maintainers"
LABEL description="Meowcoin monitoring service"
LABEL version="2.0"

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    bc \
    ca-certificates \
    curl \
    jq \
    netcat-openbsd \
    tini \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create a non-root user
RUN adduser --system --group --shell /bin/bash monitor

# Copy scripts
COPY docker/monitor/entrypoint.sh /entrypoint.sh
COPY docker/scripts/common.sh /usr/local/bin/common.sh

# Set permissions
RUN chmod +x /entrypoint.sh /usr/local/bin/common.sh \
    && mkdir -p /data \
    && chown -R monitor:monitor /data

# Create data directory
VOLUME /data

# Switch to non-root user
USER monitor
WORKDIR /home/monitor

# Use tini as init
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]
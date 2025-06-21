FROM debian:bookworm-slim

# Add labels for better maintainability
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

# Create a non-root user for the monitor
RUN adduser --system --group --shell /bin/bash monitor

# Copy the entrypoint script and make it executable
COPY meowcoin-monitor/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create data directory
RUN mkdir -p /data && chown -R monitor:monitor /data

# Set volume
VOLUME /data

# Switch to non-root user
USER monitor
WORKDIR /home/monitor

# Use tini as init for proper signal handling
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

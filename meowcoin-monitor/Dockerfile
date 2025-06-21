FROM debian:bookworm-slim

# Install dependencies, including bash for the entrypoint script
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    bc \
    bash \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user for the monitor
RUN adduser --system --group --shell /bin/bash monitor

# Copy the entrypoint script and make it executable in a single layer
COPY --chmod=0755 meowcoin-monitor/entrypoint.sh /entrypoint.sh

# Switch to the non-root user
USER monitor

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"] 

FROM debian:bookworm-slim

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    jq \
    bc \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Copy the entrypoint script and make it executable
COPY meowcoin-monitor/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"] 

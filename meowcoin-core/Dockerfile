# Stage 1: Fetcher
# Use a debian-based image for glibc compatibility with official releases
FROM debian:bookworm-slim AS fetcher

# Install dependencies needed to download and extract the release
RUN apt-get update && apt-get install -y --no-install-recommends curl tar xz-utils jq ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /downloads

# Fetch the latest release URL from the GitHub API and download it
RUN DOWNLOAD_URL=$(curl -s https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest | jq -r ".assets[] | select(.name | test(\"x86_64-linux-gnu.tar.gz$\")) | .browser_download_url") && \
    echo "Downloading latest Meowcoin release from: ${DOWNLOAD_URL}" && \
    curl -L -o meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    tar -xzf meowcoin.tar.gz

# Stage 2: Final image
FROM debian:bookworm-slim

# Install runtime dependencies and gosu (for privilege-dropping)
RUN apt-get update && apt-get install -y --no-install-recommends bash libjemalloc2 jq openssl gettext ca-certificates curl && \
    curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user to run the application
# We use a system user for better security practices
RUN adduser --system --group --shell /bin/bash meowcoin

# Copy all necessary files and set permissions
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoind /usr/local/bin/
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoin-cli /usr/local/bin/
COPY meowcoin-core/entrypoint.sh /entrypoint.sh

# Set permissions and create data directory
RUN chmod +x /entrypoint.sh && \
    mkdir -p /home/meowcoin/.meowcoin && \
    chown meowcoin:meowcoin /home/meowcoin/.meowcoin

VOLUME /home/meowcoin/.meowcoin

# Healthcheck to ensure the node is running and responsive
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 \
  CMD gosu meowcoin meowcoin-cli -datadir=/home/meowcoin/.meowcoin getblockchaininfo || exit 1

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command can be overridden
CMD ["meowcoind"]

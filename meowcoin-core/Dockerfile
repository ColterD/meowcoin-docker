# Stage 1: Fetcher
# Use a debian-based image for glibc compatibility with official releases
FROM debian:bookworm-slim AS fetcher

# Install dependencies needed to download, verify, and extract the release
# We add bash to ensure our verification script runs with the correct interpreter.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    tar \
    xz-utils \
    jq \
    ca-certificates \
    gnupg \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Add build arguments for version pinning and architecture
ARG MEOWCOIN_VERSION=latest
ARG MEOWCOIN_ARCH=x86_64-linux-gnu

WORKDIR /downloads

# Copy the GPG key and verification script into the build stage
COPY meowcoin-core/meowcoin_release.asc /meowcoin_release.asc
COPY meowcoin-core/download-and-verify.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/download-and-verify.sh

# Execute the script to download, verify, and extract Meowcoin Core.
# The script now uses the bundled GPG key, making the build self-contained.
ENV MEOWCOIN_VERSION=${MEOWCOIN_VERSION}
ENV MEOWCOIN_ARCH=${MEOWCOIN_ARCH}
RUN bash /usr/local/bin/download-and-verify.sh

# Stage 2: Final image
FROM debian:bookworm-slim

# Add labels for better maintainability
LABEL maintainer="Meowcoin Docker Maintainers"
LABEL description="Meowcoin Core node in Docker"
LABEL version="2.0"

# Install runtime dependencies and gosu (for privilege-dropping)
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    libjemalloc2 \
    jq \
    openssl \
    gettext \
    ca-certificates \
    curl \
    tini \
    && curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" \
    && chmod +x /usr/local/bin/gosu \
    && rm -rf /var/lib/apt/lists/*

# Add build arguments for user and group IDs
ARG MEOWCOIN_UID=1000
ARG MEOWCOIN_GID=1000

# Create a non-root user to run the application
RUN groupadd -g "${MEOWCOIN_GID}" meowcoin && \
    useradd -u "${MEOWCOIN_UID}" -g "${MEOWCOIN_GID}" -s /bin/bash -m -d /home/meowcoin meowcoin

# Copy all necessary files and set permissions
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoind /usr/local/bin/
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoin-cli /usr/local/bin/
COPY meowcoin-core/entrypoint.sh /entrypoint.sh

# Set permissions and create data directory
RUN chmod +x /entrypoint.sh && \
    mkdir -p /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Define volume for persistent data
VOLUME /home/meowcoin/.meowcoin

# Healthcheck to ensure the node is running and responsive
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 \
  CMD gosu meowcoin meowcoin-cli -datadir=/home/meowcoin/.meowcoin getblockchaininfo || exit 1

# Use tini as init to handle signals properly
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command can be overridden
CMD ["meowcoind"]

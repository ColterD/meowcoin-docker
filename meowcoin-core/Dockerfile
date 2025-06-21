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
LABEL org.opencontainers.image.source="https://github.com/ColterD/meowcoin-docker"
LABEL org.opencontainers.image.licenses="MIT"

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
    gnupg \
    netcat-openbsd \
    procps \
    && curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" \
    && chmod +x /usr/local/bin/gosu \
    && gosu --version \
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
COPY meowcoin-core/healthcheck.sh /healthcheck.sh

# Create config directory and copy template
RUN mkdir -p /etc/meowcoin
COPY config/meowcoin.conf.template /etc/meowcoin/meowcoin.conf.template

# Set permissions and create data and log directories
RUN chmod +x /entrypoint.sh && \
    chmod +x /healthcheck.sh && \
    mkdir -p /home/meowcoin/.meowcoin && \
    mkdir -p /var/log/meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /var/log/meowcoin && \
    chmod 755 /var/log/meowcoin

# Define volumes for persistent data and logs
VOLUME /home/meowcoin/.meowcoin
VOLUME /var/log/meowcoin

# Healthcheck removed - using docker-compose healthcheck instead

# Use tini as init to handle signals properly
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command can be overridden
CMD ["meowcoind"]

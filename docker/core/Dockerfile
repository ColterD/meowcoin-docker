# Stage 1: Fetcher
# Use a debian-based image for glibc compatibility with official releases
FROM debian:bookworm-slim AS fetcher

# Install dependencies needed to download, verify, and extract the release
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg \
    jq \
    tar \
    xz-utils \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Set up work directory
WORKDIR /downloads

# Copy scripts
COPY docker/scripts/download.sh /usr/local/bin/
COPY docker/scripts/verify.sh /usr/local/bin/
COPY docker/scripts/common.sh /usr/local/bin/
COPY docker/core/meowcoin_release.asc /etc/meowcoin/keys/

# Make scripts executable
RUN chmod +x /usr/local/bin/download.sh \
    && chmod +x /usr/local/bin/verify.sh \
    && chmod +x /usr/local/bin/common.sh

# Set build arguments with defaults
ARG MEOWCOIN_VERSION=latest
ARG MEOWCOIN_ARCH=x86_64-linux-gnu
ARG SKIP_VERIFY=false

# Download and verify Meowcoin
RUN /usr/local/bin/download.sh "${MEOWCOIN_VERSION}" "${MEOWCOIN_ARCH}" /downloads \
    && if [ "${SKIP_VERIFY}" != "true" ]; then /usr/local/bin/verify.sh /downloads /etc/meowcoin/keys/meowcoin_release.asc; fi \
    && tar -xzf /downloads/meowcoin-*.tar.gz -C /downloads \
    && rm -f /downloads/meowcoin-*.tar.gz

# Stage 2: Final image
FROM debian:bookworm-slim

# Add labels for better maintainability
LABEL maintainer="Meowcoin Docker Maintainers"
LABEL description="Meowcoin Core node in Docker"
LABEL version="2.0"

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    ca-certificates \
    curl \
    gettext \
    jq \
    libjemalloc2 \
    openssl \
    tini \
    gosu \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set up non-root user
ARG MEOWCOIN_UID=1000
ARG MEOWCOIN_GID=1000
RUN groupadd -g "${MEOWCOIN_GID}" meowcoin \
    && useradd -u "${MEOWCOIN_UID}" -g "${MEOWCOIN_GID}" -s /bin/bash -m -d /home/meowcoin meowcoin

# Copy binaries from fetcher stage
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoind /usr/local/bin/
COPY --from=fetcher /downloads/meowcoin-*/bin/meowcoin-cli /usr/local/bin/

# Copy configuration and scripts
COPY docker/core/entrypoint.sh /entrypoint.sh
COPY docker/core/healthcheck.sh /healthcheck.sh
COPY config/meowcoin.conf.template /etc/meowcoin/meowcoin.conf.template
COPY docker/scripts/common.sh /usr/local/bin/

# Set permissions
RUN chmod +x /entrypoint.sh /healthcheck.sh /usr/local/bin/common.sh \
    && mkdir -p /home/meowcoin/.meowcoin \
    && chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Define volume
VOLUME /home/meowcoin/.meowcoin

# Set up healthcheck
HEALTHCHECK --interval=60s --timeout=30s --start-period=300s --retries=3 \
  CMD /healthcheck.sh

# Use tini as init to handle signals properly
ENTRYPOINT ["/usr/bin/tini", "--", "/entrypoint.sh"]

# Default command
CMD ["meowcoind"]
# Stage 1: Fetcher
# Use a debian-based image for glibc compatibility with official releases
FROM debian:bookworm-slim AS fetcher

# Install dependencies needed to download, verify, and extract the release
RUN apt-get update && apt-get install -y --no-install-recommends curl tar xz-utils jq ca-certificates gnupg && \
    rm -rf /var/lib/apt/lists/*

# Add build argument for version pinning, default to latest
ARG MEOWCOIN_VERSION=latest

# Meowcoin release signing keys - add more keys as needed
# Find keys on meowcoin.org or the Meowcoin-Foundation GitHub organization
ARG MEOWCOIN_SIGNING_KEYS="1D4428469865B21B2123B4409D334999B8B35B42"

WORKDIR /downloads

# Download and extract the specified or latest Meowcoin release
RUN set -x && \
    if [ "${MEOWCOIN_VERSION}" = "latest" ]; then \
      RELEASE_URL=$(curl -s --fail https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest); \
      DOWNLOAD_URL=$(echo "${RELEASE_URL}" | jq -r ".assets[] | select(.name | test(\\"x86_64-linux-gnu.tar.gz$\\")) | .browser_download_url"); \
      DOWNLOAD_SUMS_URL=$(echo "${RELEASE_URL}" | jq -r ".assets[] | select(.name | test(\\"SHA256SUMS.asc$\\")) | .browser_download_url"); \
    else \
      DOWNLOAD_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-x86_64-linux-gnu.tar.gz"; \
      DOWNLOAD_SUMS_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/v${MEOWCOIN_VERSION}/SHA256SUMS.asc"; \
    fi && \
    if [ -z "${DOWNLOAD_URL}" ] || [ -z "${DOWNLOAD_SUMS_URL}" ]; then \
      echo "Error: Could not determine download URL. Please check MEOWCOIN_VERSION and network connectivity." >&2; \
      exit 1; \
    fi && \
    echo "Downloading Meowcoin release from: ${DOWNLOAD_URL}" && \
    curl --fail -L -o meowcoin.tar.gz "${DOWNLOAD_URL}" && \
    curl --fail -L -o SHA256SUMS.asc "${DOWNLOAD_SUMS_URL}" && \
    \
    echo "Verifying GPG signature..." && \
    export GNUPGHOME="$(mktemp -d)" && \
    gpg --keyserver keyserver.ubuntu.com --recv-keys ${MEOWCOIN_SIGNING_KEYS} && \
    gpg --verify SHA256SUMS.asc && \
    \
    echo "Verifying checksum..." && \
    grep "$(sha256sum meowcoin.tar.gz | awk '{print $1}')" SHA256SUMS.asc && \
    \
    tar -xzf meowcoin.tar.gz && \
    rm -rf "$GNUPGHOME"

# Stage 2: Final image
FROM debian:bookworm-slim

# Install runtime dependencies and gosu (for privilege-dropping)
RUN apt-get update && apt-get install -y --no-install-recommends bash libjemalloc2 jq openssl gettext ca-certificates curl && \
    curl -L -o /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/1.17/gosu-amd64" && \
    chmod +x /usr/local/bin/gosu && \
    rm -rf /var/lib/apt/lists/*

# Add build arguments for user and group IDs
ARG MEOWCOIN_UID=1000
ARG MEOWCOIN_GID=1000

# Create a non-root user to run the application
# We use a system user for better security practices
RUN groupadd -g "${MEOWCOIN_GID}" meowcoin && \
    adduser --system --uid "${MEOWCOIN_UID}" --gid "${MEOWCOIN_GID}" --shell /bin/bash meowcoin

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

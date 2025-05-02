FROM debian:bullseye-slim

LABEL maintainer="MeowCoin Platform <support@meowcoin.com>"
LABEL description="MeowCoin Node for the MeowCoin Platform"

# Set environment variables
ENV MEOWCOIN_VERSION=2.1.0
ENV MEOWCOIN_DATA=/root/.meowcoin
ENV MEOWCOIN_CONFIG=/etc/meowcoin
ENV PATH=/usr/local/bin:$PATH

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    gnupg \
    ca-certificates \
    apt-transport-https \
    software-properties-common \
    gosu \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p ${MEOWCOIN_DATA} \
    && mkdir -p ${MEOWCOIN_CONFIG}

# Download and install MeowCoin binaries
RUN wget -q https://github.com/meowcoin/meowcoin/releases/download/v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-x86_64-linux-gnu.tar.gz \
    && tar -xzf meowcoin-${MEOWCOIN_VERSION}-x86_64-linux-gnu.tar.gz -C /usr/local --strip-components=1 \
    && rm meowcoin-${MEOWCOIN_VERSION}-x86_64-linux-gnu.tar.gz

# Copy configuration files
COPY config/meowcoin.conf ${MEOWCOIN_CONFIG}/meowcoin.conf
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY scripts/entrypoint.sh /entrypoint.sh

# Make scripts executable
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 9332 9333

# Set volume
VOLUME ["${MEOWCOIN_DATA}", "${MEOWCOIN_CONFIG}"]

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD meowcoin-cli -conf=${MEOWCOIN_CONFIG}/meowcoin.conf getblockchaininfo || exit 1

# Set entrypoint
ENTRYPOINT ["/entrypoint.sh"]

# Default command
CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
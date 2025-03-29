FROM debian:stable-slim

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker image for Meowcoin Core"

# Install dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    bash \
    curl \
    wget \
    jq \
    supervisor \
    openssl \
    tzdata \
    nodejs \
    npm \
    ca-certificates \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-program-options1.74.0 \
    libboost-thread1.74.0 \
    libboost-chrono1.74.0 \
    git \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create meowcoin user with a specific GID/UID
RUN groupadd -g 10000 meowcoin && \
    useradd -u 10000 -g meowcoin -s /sbin/nologin -m meowcoin

# Create necessary directories
RUN mkdir -p /etc/meowcoin \
    /var/log/meowcoin \
    /var/lib/meowcoin \
    /home/meowcoin/.meowcoin/logs \
    /home/meowcoin/.meowcoin/backups \
    /app && \
    chown -R meowcoin:meowcoin /home/meowcoin && \
    chmod 750 /home/meowcoin

# Create supervisor directories
RUN mkdir -p /etc/supervisor/conf.d /var/log/supervisor

# Install Block Explorer
RUN mkdir -p /app/explorer && \
    cd /app/explorer && \
    npm install btc-rpc-explorer@3.3.0 && \
    chown -R meowcoin:meowcoin /app/explorer

# Copy or fetch the version file
COPY meowcoin_version.txt /meowcoin_version.txt

# Fetch and install Meowcoin binaries
RUN set -ex && \
    # If no version is specified, fetch the latest from GitHub API
    if [ ! -s /meowcoin_version.txt ]; then \
        echo "No version specified, fetching latest release..." && \
        LATEST_RELEASE=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest | jq -r .tag_name) && \
        echo "${LATEST_RELEASE}" > /meowcoin_version.txt; \
    fi && \
    # Get the version tag from the file
    MEOWCOIN_VERSION=$(cat /meowcoin_version.txt) && \
    VERSION_NUM=${MEOWCOIN_VERSION#Meow-v} && \
    echo "Installing Meowcoin version: ${MEOWCOIN_VERSION}" && \
    # Fetch release assets list
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION} | jq -r '.assets[].browser_download_url') && \
    # Find the Linux x86_64 tarball - taking only the first match
    LINUX_TARBALL=$(echo "${RELEASE_ASSETS}" | grep -i "linux" | grep -i "x86_64\|amd64\|linux64" | grep -i "tar.gz" | grep -v "md5\|sha256" | head -1) && \
    if [ -z "${LINUX_TARBALL}" ]; then \
        echo "Could not find Linux tarball, listing available assets:" && \
        echo "${RELEASE_ASSETS}" && \
        exit 1; \
    fi && \
    echo "Downloading: ${LINUX_TARBALL}" && \
    curl -L -o /tmp/meowcoin.tar.gz "${LINUX_TARBALL}" && \
    # Extract the tarball
    mkdir -p /tmp/extract && \
    tar -xzf /tmp/meowcoin.tar.gz -C /tmp/extract && \
    # Check for lib directory and copy libraries if needed
    if [ -d "/tmp/extract/meowcoin-"*"/lib" ]; then \
        echo "Found lib directory, copying libraries..." && \
        cp -r /tmp/extract/meowcoin-*/lib/* /usr/lib/ || echo "Could not copy libraries"; \
    fi && \
    # Check if we got the binaries - need to find them in the structure
    MEOWCOIN_DIR=$(find /tmp/extract -type d -name "bin" | head -1) && \
    if [ -z "${MEOWCOIN_DIR}" ]; then \
        echo "Could not find bin directory, searching for binaries directly..." && \
        MEOWCOIN_D=$(find /tmp/extract -name "meowcoind" | head -1) && \
        MEOWCOIN_CLI=$(find /tmp/extract -name "meowcoin-cli" | head -1) && \
        if [ -n "${MEOWCOIN_D}" ] && [ -n "${MEOWCOIN_CLI}" ]; then \
            cp "${MEOWCOIN_D}" /usr/bin/ && \
            cp "${MEOWCOIN_CLI}" /usr/bin/; \
        else \
            echo "Could not find binaries in extracted archive" && \
            find /tmp/extract -type f -executable && \
            exit 1; \
        fi; \
    else \
        # Copy binaries from bin directory
        cp ${MEOWCOIN_DIR}/meowcoind /usr/bin/ || echo "meowcoind not found in ${MEOWCOIN_DIR}" && \
        cp ${MEOWCOIN_DIR}/meowcoin-cli /usr/bin/ || echo "meowcoin-cli not found in ${MEOWCOIN_DIR}"; \
    fi && \
    # Verify binaries were copied
    if [ ! -f /usr/bin/meowcoind ] || [ ! -f /usr/bin/meowcoin-cli ]; then \
        echo "Failed to copy binaries to /usr/bin" && \
        exit 1; \
    fi && \
    # Make binaries executable
    chmod +x /usr/bin/meowcoind /usr/bin/meowcoin-cli && \
    # Clean up
    rm -rf /tmp/meowcoin.tar.gz /tmp/extract && \
    # Binaries installed successfully
    echo "Binaries installed successfully"

# Use a fixed password instead of randomly generating one
RUN mkdir -p /home/meowcoin/.meowcoin && \
    echo "server=1" > /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcuser=meowcoin" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcpassword=meowcoinpass123" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcport=9766" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcbind=127.0.0.1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcallowip=127.0.0.1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "datadir=/home/meowcoin/.meowcoin" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Create links for the root user to use the meowcoin configuration
RUN mkdir -p /root/.meowcoin && \
    ln -s /home/meowcoin/.meowcoin/meowcoin.conf /root/.meowcoin/meowcoin.conf

# Create a wrapper script for meowcoin-cli
RUN echo '#!/bin/bash' > /usr/local/bin/meowcoin-cli-wrapper && \
    echo 'meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf -datadir=/home/meowcoin/.meowcoin "$@"' >> /usr/local/bin/meowcoin-cli-wrapper && \
    chmod +x /usr/local/bin/meowcoin-cli-wrapper

# Create environment file for the block explorer
RUN mkdir -p /app/explorer/env && \
    echo "BTCEXP_COIN=BTC" > /app/explorer/env/.env && \
    echo "BTCEXP_HOST=0.0.0.0" >> /app/explorer/env/.env && \
    echo "BTCEXP_PORT=3001" >> /app/explorer/env/.env && \
    echo "BTCEXP_BITCOIND_HOST=127.0.0.1" >> /app/explorer/env/.env && \
    echo "BTCEXP_BITCOIND_PORT=9766" >> /app/explorer/env/.env && \
    echo "BTCEXP_BITCOIND_USER=meowcoin" >> /app/explorer/env/.env && \
    echo "BTCEXP_BITCOIND_PASS=meowcoinpass123" >> /app/explorer/env/.env && \
    echo "BTCEXP_BITCOIND_RPC_TIMEOUT=10000" >> /app/explorer/env/.env && \
    echo "BTCEXP_ADDRESS_API=blockchain.com" >> /app/explorer/env/.env && \
    echo "BTCEXP_SITE_TITLE=Meowcoin Explorer" >> /app/explorer/env/.env && \
    echo "BTCEXP_UI_THEME=dark" >> /app/explorer/env/.env && \
    chown -R meowcoin:meowcoin /app/explorer/env

# Copy source files for auxiliary tools
COPY src/ /app/
COPY config/ /etc/meowcoin/

# Copy supervisor config to the correct location
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Add block explorer configuration to supervisord
RUN echo "[program:explorer]" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "command=cd /app/explorer && node /app/explorer/node_modules/btc-rpc-explorer/bin/www" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "user=meowcoin" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "directory=/app/explorer" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "autostart=true" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "autorestart=true" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "priority=20" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile=/dev/stdout" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stdout_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile=/dev/stderr" >> /etc/supervisor/conf.d/supervisord.conf && \
    echo "stderr_logfile_maxbytes=0" >> /etc/supervisor/conf.d/supervisord.conf

# Override the meowcoin command in supervisord config to use proper datadir
RUN sed -i 's|command=/usr/bin/meowcoind -conf=/home/meowcoin/.meowcoin/meowcoin.conf|command=/usr/bin/meowcoind -conf=/home/meowcoin/.meowcoin/meowcoin.conf -datadir=/home/meowcoin/.meowcoin|g' /etc/supervisor/conf.d/supervisord.conf

# Install minimal Node.js dependencies for the auxiliary tools
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --no-package-lock

# Set up environment
ENV PATH="/app/bin:/usr/local/bin:${PATH}"
ENV NODE_ENV="production"

# Make scripts executable
RUN chmod -R +x /app/bin/

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports: 
# - 9766: RPC port
# - 9767: P2P port (following Bitcoin convention of P2P = RPC+1)
# - 9449: Metrics port (if enabled)
# - 3001: Block Explorer UI
EXPOSE 9766 9767 9449 3001

# Use entrypoint.js
CMD ["node", "/app/entrypoint.js"]
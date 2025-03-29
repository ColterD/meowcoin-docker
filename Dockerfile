FROM debian:stable-slim

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker container for official Meowcoin Core"
LABEL version="1.0"

# Install minimal dependencies needed for Meowcoin Core to run
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    wget \
    jq \
    ca-certificates \
    libboost-system1.74.0 \
    libboost-filesystem1.74.0 \
    libboost-program-options1.74.0 \
    libboost-thread1.74.0 \
    libboost-chrono1.74.0 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create meowcoin user with a specific GID/UID
RUN groupadd -g 10000 meowcoin && \
    useradd -u 10000 -g meowcoin -s /bin/bash -m meowcoin

# Create data directory
RUN mkdir -p /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin

# Set Meowcoin version - hardcoded for reliability
ENV MEOWCOIN_VERSION="Meow-v2.0.5"

# Download and install official Meowcoin binaries
RUN set -ex && \
    echo "Installing Meowcoin version: ${MEOWCOIN_VERSION}" && \
    # Fetch release assets from GitHub
    RELEASE_ASSETS=$(curl -sL https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${MEOWCOIN_VERSION} | jq -r '.assets[].browser_download_url') && \
    # Find the Linux x86_64 tarball
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
    # Find and copy binaries
    MEOWCOIN_DIR=$(find /tmp/extract -type d -name "bin" | head -1) && \
    if [ -z "${MEOWCOIN_DIR}" ]; then \
        # Try to find binaries directly
        MEOWCOIN_D=$(find /tmp/extract -name "meowcoind" | head -1) && \
        MEOWCOIN_CLI=$(find /tmp/extract -name "meowcoin-cli" | head -1) && \
        if [ -n "${MEOWCOIN_D}" ] && [ -n "${MEOWCOIN_CLI}" ]; then \
            cp "${MEOWCOIN_D}" /usr/local/bin/ && \
            cp "${MEOWCOIN_CLI}" /usr/local/bin/; \
        else \
            echo "Could not find binaries in extracted archive" && \
            exit 1; \
        fi; \
    else \
        # Copy binaries from bin directory
        cp ${MEOWCOIN_DIR}/meowcoind /usr/local/bin/ && \
        cp ${MEOWCOIN_DIR}/meowcoin-cli /usr/local/bin/; \
    fi && \
    # Make binaries executable
    chmod +x /usr/local/bin/meowcoind /usr/local/bin/meowcoin-cli && \
    # Clean up
    rm -rf /tmp/meowcoin.tar.gz /tmp/extract

# Create default configuration with random RPC password
RUN mkdir -p /home/meowcoin/.meowcoin && \
    # Generate a random password
    RPC_PASSWORD=$(openssl rand -base64 32) && \
    echo "# Meowcoin Configuration File" > /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "# Network settings" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "server=1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "listen=1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "txindex=1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "# RPC settings" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcuser=meowcoin" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcpassword=${RPC_PASSWORD}" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcallowip=0.0.0.0/0" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcbind=0.0.0.0" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "rpcport=9766" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "# Performance settings" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "dbcache=450" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "maxmempool=300" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "maxconnections=40" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "# Logging settings" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "logtimestamps=1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    echo "printtoconsole=1" >> /home/meowcoin/.meowcoin/meowcoin.conf && \
    # Save the password to a readable file for the user to retrieve
    echo "${RPC_PASSWORD}" > /home/meowcoin/.meowcoin/rpcpassword && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Create config directory for custom configs
RUN mkdir -p /config && \
    chown meowcoin:meowcoin /config

# Create a simple entrypoint script with password display
RUN echo '#!/bin/bash\n\
# Check if custom config file exists and use it\n\
if [ -f /config/meowcoin.conf ]; then\n\
  echo "Using custom config from mounted volume"\n\
  cp /config/meowcoin.conf /home/meowcoin/.meowcoin/meowcoin.conf\n\
  chown meowcoin:meowcoin /home/meowcoin/.meowcoin/meowcoin.conf\n\
fi\n\
\n\
# Handle CLI commands\n\
if [ "$1" = "cli" ]; then\n\
  shift\n\
  exec su -c "meowcoin-cli -conf=/home/meowcoin/.meowcoin/meowcoin.conf \"$@\"" meowcoin\n\
elif [ "$1" = "bash" ] || [ "$1" = "sh" ]; then\n\
  exec /bin/bash\n\
elif [ "$1" = "getpassword" ]; then\n\
  if [ -f /home/meowcoin/.meowcoin/rpcpassword ]; then\n\
    cat /home/meowcoin/.meowcoin/rpcpassword\n\
  else\n\
    echo "Password file not found. Using custom configuration."\n\
  fi\n\
else\n\
  # Display the RPC credentials for the user if using auto-generated password\n\
  if [ -f /home/meowcoin/.meowcoin/rpcpassword ]; then\n\
    PASSWORD=$(cat /home/meowcoin/.meowcoin/rpcpassword)\n\
    echo "--------------------------------------------------------"\n\
    echo "RPC Credentials:"\n\
    echo "Username: meowcoin"\n\
    echo "Password: ${PASSWORD}"\n\
    echo "--------------------------------------------------------"\n\
    echo "Use these credentials to connect to the RPC interface"\n\
    echo "You can also retrieve this password with:"\n\
    echo "docker exec meowcoin-node entrypoint.sh getpassword"\n\
    echo "--------------------------------------------------------"\n\
  fi\n\
\n\
  # Run the daemon\n\
  echo "Starting Meowcoin daemon..."\n\
  exec su -c "meowcoind -conf=/home/meowcoin/.meowcoin/meowcoin.conf" meowcoin\n\
fi' > /usr/local/bin/entrypoint.sh && \
    chmod +x /usr/local/bin/entrypoint.sh

# Volume for blockchain data and custom configs
VOLUME ["/home/meowcoin/.meowcoin", "/config"]

# Expose ports:
# - 9766: RPC port
# - 8788: P2P port (official Meowcoin P2P port from logs)
EXPOSE 9766 8788

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
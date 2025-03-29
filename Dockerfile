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
    python3 \
    procps \
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

# Create the simple dashboard
RUN mkdir -p /var/www/html && \
    echo '<!DOCTYPE html>\
<html>\
<head>\
    <title>Meowcoin Node Status</title>\
    <meta http-equiv="refresh" content="10">\
    <style>\
        body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f0f0f0; }\
        .container { max-width: 800px; margin: 0 auto; background-color: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }\
        h1 { color: #333; margin-top: 0; text-align: center; }\
        .status-box { background: #f8f8f8; border-radius: 5px; padding: 15px; margin: 15px 0; border: 1px solid #e0e0e0; }\
        pre { background: #eee; padding: 10px; border-radius: 5px; overflow: auto; white-space: pre-wrap; font-family: monospace; }\
        .links { margin-top: 20px; }\
        .links a { display: inline-block; margin-right: 15px; color: #0066cc; text-decoration: none; }\
        .links a:hover { text-decoration: underline; }\
        .footer { margin-top: 20px; font-size: 12px; color: #666; text-align: center; }\
    </style>\
</head>\
<body>\
    <div class="container">\
        <h1>🐱 Meowcoin Node Status</h1>\
        <div class="status-box">\
            <h2>Node Information</h2>\
            <pre id="node-info">Loading node information...</pre>\
        </div>\
        <div class="links">\
            <h2>External Resources</h2>\
            <a href="https://explorer.mewccrypto.com/" target="_blank">Meowcoin Explorer</a>\
            <a href="https://explorer.meowcoin.lol/" target="_blank">Meowcoin Explorer 2</a>\
            <a href="https://github.com/Meowcoin-Foundation/Meowcoin" target="_blank">GitHub Repository</a>\
        </div>\
        <div class="footer">\
            Last updated: <span id="last-updated">-</span>\
        </div>\
    </div>\
    <script>\
        function updateStatus() {\
            var timestamp = new Date().toLocaleString();\
            document.getElementById("last-updated").textContent = timestamp;\
            \
            var xhr = new XMLHttpRequest();\
            xhr.open("GET", "/status.txt?" + timestamp, true);\
            xhr.onreadystatechange = function() {\
                if (xhr.readyState === 4) {\
                    if (xhr.status === 200) {\
                        document.getElementById("node-info").textContent = xhr.responseText;\
                    } else {\
                        document.getElementById("node-info").textContent = "Error loading status information. Status code: " + xhr.status;\
                    }\
                }\
            };\
            xhr.send();\
        }\
        \
        updateStatus();\
        setInterval(updateStatus, 10000);\
    </script>\
</body>\
</html>' > /var/www/html/index.html

# Create the update-status script
COPY update-status.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/update-status.sh

# Create the entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

# Volume for blockchain data and custom configs
VOLUME ["/home/meowcoin/.meowcoin", "/config"]

# Expose ports:
# - 9766: RPC port
# - 8788: P2P port
# - 8080: Web status dashboard
EXPOSE 9766 8788 8080

# Use entrypoint script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
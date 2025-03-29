FROM node:18-alpine

# Add labels
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL description="Docker image for Meowcoin Core"

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    supervisor \
    openssl \
    tzdata

# Create meowcoin user with a different GID/UID
RUN addgroup -g 10000 -S meowcoin && \
    adduser -u 10000 -S meowcoin -G meowcoin -h /home/meowcoin -s /sbin/nologin

# Create necessary directories
RUN mkdir -p /etc/meowcoin \
    /var/log/meowcoin \
    /var/lib/meowcoin \
    /home/meowcoin/.meowcoin/logs \
    /home/meowcoin/.meowcoin/backups \
    /app && \
    chown -R meowcoin:meowcoin /home/meowcoin && \
    chmod 750 /home/meowcoin

# Copy source files
COPY src/ /app/
COPY config/ /etc/meowcoin/

# Install dependencies
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --production

# Set version
COPY meowcoin_version.txt /meowcoin_version.txt

# Set up environment
ENV PATH="/app/bin:${PATH}"
ENV NODE_ENV="production"

# Make scripts executable
RUN chmod -R +x /app/bin/

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports
EXPOSE 8332 8333 9449

# Use entrypoint.js
CMD ["node", "/app/entrypoint.js"]
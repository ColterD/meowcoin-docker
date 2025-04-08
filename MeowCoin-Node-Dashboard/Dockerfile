FROM node:18-alpine

WORKDIR /app

# Install required packages
RUN apk add --no-cache curl bash libc6-compat

# Copy package files
COPY package.json ./
COPY packages/shared/package.json ./packages/shared/
COPY packages/backend/package.json ./packages/backend/
COPY packages/frontend/package.json ./packages/frontend/

# Create directories
RUN mkdir -p packages/shared/dist
RUN mkdir -p packages/backend/dist
RUN mkdir -p packages/frontend/dist

# Copy backend code
COPY packages/backend/dist/index.js ./packages/backend/dist/

# Set up directories for MeowCoin (simulated for demo)
RUN mkdir -p /app/meowcoin/bin
RUN mkdir -p /app/data
RUN mkdir -p /root/.meowcoin

# Create a mock config file
RUN echo "# MeowCoin Configuration" > /root/.meowcoin/meowcoin.conf && \
    echo "rpcuser=meowcoinuser" >> /root/.meowcoin/meowcoin.conf && \
    echo "rpcpassword=meowcoinpassword" >> /root/.meowcoin/meowcoin.conf && \
    echo "rpcport=9332" >> /root/.meowcoin/meowcoin.conf

# Create mock meowcoin binaries for the demo
RUN echo '#!/bin/sh' > /app/meowcoin/bin/meowcoind && \
    echo 'echo "MeowCoin Node (simulated) started in background"' >> /app/meowcoin/bin/meowcoind && \
    echo 'exit 0' >> /app/meowcoin/bin/meowcoind && \
    chmod +x /app/meowcoin/bin/meowcoind

RUN echo '#!/bin/sh' > /app/meowcoin/bin/meowcoin-cli && \
    echo 'echo "MeowCoin CLI (simulated) executed"' >> /app/meowcoin/bin/meowcoin-cli && \
    echo 'exit 0' >> /app/meowcoin/bin/meowcoin-cli && \
    chmod +x /app/meowcoin/bin/meowcoin-cli

# Expose ports
EXPOSE 3000 9332 9333

# Health check
HEALTHCHECK --interval=30s --timeout=5s CMD curl -f http://localhost:3000/health || exit 1

# Start application
CMD ["node", "/app/packages/backend/dist/index.js"]
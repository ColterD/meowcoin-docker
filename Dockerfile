# Build stage
FROM ubuntu:20.04 AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libssl-dev \
    libboost-all-dev \
    libminiupnpc-dev \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /build

# Copy version file
COPY meowcoin_version.txt .

# Build Meowcoin
RUN MEOWCOIN_VERSION=$(cat meowcoin_version.txt) && \
    git clone https://github.com/Meowcoin-Foundation/Meowcoin.git && \
    cd Meowcoin && \
    git checkout $MEOWCOIN_VERSION && \
    ./autogen.sh && \
    ./configure --prefix=/usr && \
    make -j$(nproc) && \
    make install DESTDIR=/install

# Runtime stage
FROM ubuntu:20.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    libssl1.1 \
    libboost-system1.71.0 \
    libboost-filesystem1.71.0 \
    libboost-thread1.71.0 \
    libboost-chrono1.71.0 \
    && rm -rf /var/lib/apt/lists/*

# Create meowcoin user
RUN useradd -r -m -U meowcoin

# Copy binaries from builder
COPY --from=builder /install/usr/bin/meowcoin* /usr/bin/

# Set metadata
LABEL maintainer="ColterD <colterdahlberg@gmail.com>"
LABEL version="1.0"
LABEL description="Docker image for Meowcoin Core"

# Copy version information
COPY meowcoin_version.txt /meowcoin_version.txt

# Data directory
RUN mkdir -p /home/meowcoin/.meowcoin && \
    chown -R meowcoin:meowcoin /home/meowcoin/.meowcoin

# Switch to non-root user
USER meowcoin
WORKDIR /home/meowcoin

# Volume for blockchain data
VOLUME ["/home/meowcoin/.meowcoin"]

# Expose ports
EXPOSE 8332 8333

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5m \
  CMD meowcoin-cli getblockchaininfo || exit 1

# Command to run
CMD ["meowcoind"]
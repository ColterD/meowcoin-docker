#!/bin/bash

# Load helper functions
source /scripts/functions.sh

# Set version from command line argument
VERSION=${1}

if [ -z "$VERSION" ]; then
    log_error "No version specified"
    exit 1
fi

log_info "Starting update to version ${VERSION}..."

# Validate version format
if [[ ! "$VERSION" =~ ^Meow-v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    log_error "Invalid version format. Expected: Meow-vX.Y.Z"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || exit 1

# Download release
log_info "Downloading ${VERSION}..."
RELEASE_ASSETS=$(curl -sL "https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/tags/${VERSION}")
DOWNLOAD_URL=$(echo "${RELEASE_ASSETS}" | jq -r '.assets[] | select(.name | test("x86_64-linux-gnu.tar.gz$")) | .browser_download_url' | head -1)

if [ -z "$DOWNLOAD_URL" ] || [ "$DOWNLOAD_URL" = "null" ]; then
    log_error "Could not find download URL for ${VERSION}"
    exit 1
fi

# Download the release
log_info "Downloading from ${DOWNLOAD_URL}..."
if ! curl -L -o "${TEMP_DIR}/meowcoin.tar.gz" "${DOWNLOAD_URL}"; then
    log_error "Download failed"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Extract archive
log_info "Extracting archive..."
mkdir -p "${TEMP_DIR}/extract"
if ! tar -xzvf "${TEMP_DIR}/meowcoin.tar.gz" -C "${TEMP_DIR}/extract"; then
    log_error "Extraction failed"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Stop the node
log_info "Stopping Meowcoin node..."
if ! gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" stop; then
    log_warn "Failed to stop node gracefully, may not be running"
fi

# Wait for node to stop
log_info "Waiting for node to stop..."
sleep 10

# Find the binaries
DAEMON_PATH=$(find "${TEMP_DIR}/extract" -name "meowcoind" -type f | head -1)
CLI_PATH=$(find "${TEMP_DIR}/extract" -name "meowcoin-cli" -type f | head -1)

if [ -z "$DAEMON_PATH" ] || [ -z "$CLI_PATH" ]; then
    log_error "Could not find binaries in extracted archive"
    rm -rf "${TEMP_DIR}"
    exit 1
fi

# Backup old binaries
log_info "Backing up old binaries..."
NOW=$(date +"%Y%m%d_%H%M%S")
if [ -f "/usr/local/bin/meowcoind" ]; then
    cp -v "/usr/local/bin/meowcoind" "/usr/local/bin/meowcoind.${NOW}"
fi
if [ -f "/usr/local/bin/meowcoin-cli" ]; then
    cp -v "/usr/local/bin/meowcoin-cli" "/usr/local/bin/meowcoin-cli.${NOW}"
fi

# Install new binaries
log_info "Installing new binaries..."
cp -v "$DAEMON_PATH" "/usr/local/bin/"
cp -v "$CLI_PATH" "/usr/local/bin/"
chmod 755 "/usr/local/bin/meowcoind" "/usr/local/bin/meowcoin-cli"

# Clean up
log_info "Cleaning up..."
rm -rf "${TEMP_DIR}"

# Start node again
log_info "Starting Meowcoin node with new version..."
gosu meowcoin meowcoind -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" -daemon

# Verify version
sleep 5
NEW_VERSION=$(gosu meowcoin meowcoin-cli -conf="${MEOWCOIN_CONFIG}/meowcoin.conf" -version | head -n 1)
log_info "Update completed. New version: ${NEW_VERSION}"

exit 0
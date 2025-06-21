#!/bin/bash
# This script is responsible for downloading and verifying a specific
# or latest version of Meowcoin Core. It's designed to be run inside
# the Docker build context.

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# --- Arguments ---
# This script reads its configuration directly from environment variables
# set by the Dockerfile's ARG instructions. This is more robust than
# passing them as command-line arguments.

if [ -z "${MEOWCOIN_VERSION}" ]; then
  echo "Error: MEOWCOIN_VERSION environment variable is not set." >&2
  exit 1
fi

if [ -z "${MEOWCOIN_ARCH}" ]; then
  MEOWCOIN_ARCH="x86_64-linux-gnu"
  echo "MEOWCOIN_ARCH not set, defaulting to ${MEOWCOIN_ARCH}"
fi

# Function to download with retry and fallback
download_with_retry() {
    local url=$1
    local output=$2
    local max_retries=3
    local timeout=30
    local retry=0
    local exit_code=0
    local wait_time=10

    echo "Downloading from $url to $output"
    
    # Try primary URL first
    while [[ $retry -lt $max_retries ]]; do
        echo "Download attempt $((retry+1))/$max_retries"
        if curl --fail --silent --location --connect-timeout $timeout -o "$output" "$url"; then
            echo "Download successful!"
            return 0
        fi
        
        exit_code=$?
        echo "Download failed with exit code $exit_code. Retrying in $wait_time seconds..."
        sleep $wait_time
        retry=$((retry+1))
        wait_time=$((wait_time*2))
    done
    
    # Try fallback mirrors if primary fails
    local fallback_mirrors=(
        "https://meowcoin-mirror.org/releases"
        "https://mirrors.meowcoin.org/releases"
    )
    
    for mirror in "${fallback_mirrors[@]}"; do
        fallback_url="${mirror}/${url##*/}"
        echo "Trying fallback mirror: $fallback_url"
        if curl --fail --silent --location --connect-timeout $timeout -o "$output" "$fallback_url"; then
            echo "Download from fallback mirror successful!"
            return 0
        fi
    done
    
    echo "All download attempts failed for $url"
    return 1
}

# --- Logic ---
if [ "${MEOWCOIN_VERSION}" = "latest" ]; then
  # Fetch release info from GitHub API
  echo "Detecting latest Meowcoin version..."
  RELEASE_INFO=$(curl -s --fail https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest)

  # Verify that we received a valid JSON response before proceeding
  if ! echo "${RELEASE_INFO}" | jq -e '.id' > /dev/null; then
    echo "Warning: Failed to fetch valid release data from GitHub API." >&2
    echo "Falling back to hardcoded version 2.0.5" >&2
    MEOWCOIN_VERSION="2.0.5"
  else
    # Extract version from tag_name
    MEOWCOIN_VERSION=$(echo "${RELEASE_INFO}" | jq -r '.tag_name' | sed 's/^[vV]//' | sed 's/^Meow-v//')
    echo "Latest version detected: ${MEOWCOIN_VERSION}"
    
    # Extract URLs using jq
    DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | jq -r --arg arch "${MEOWCOIN_ARCH}" '.assets[] | select(.name | test($arch + ".tar.gz$")) | .browser_download_url')
    DOWNLOAD_SUMS_URL=$(echo "${RELEASE_INFO}" | jq -r --arg arch "${MEOWCOIN_ARCH}" '.assets[] | select(.name | test($arch + ".tar.gz.sha256sum$")) | .browser_download_url')
  fi
fi

# If we don't have URLs yet (either because we're using a specific version or the API call failed)
if [ -z "${DOWNLOAD_URL:-}" ] || [ -z "${DOWNLOAD_SUMS_URL:-}" ]; then
  # Try to construct URLs for a specific version
  # First try with the commit hash pattern
  DOWNLOAD_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-673684e10-${MEOWCOIN_ARCH}.tar.gz"
  DOWNLOAD_SUMS_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-673684e10-${MEOWCOIN_ARCH}.tar.gz.sha256sum"
  
  # If that doesn't work, try without the commit hash
  if ! curl --head --fail --silent "${DOWNLOAD_URL}" >/dev/null 2>&1; then
    echo "Trying alternative URL pattern without commit hash..."
    DOWNLOAD_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-${MEOWCOIN_ARCH}.tar.gz"
    DOWNLOAD_SUMS_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-${MEOWCOIN_ARCH}.tar.gz.sha256sum"
  fi
fi

# Final check to ensure URLs were determined successfully
if [ -z "${DOWNLOAD_URL}" ] || [ -z "${DOWNLOAD_SUMS_URL}" ]; then
  echo "Error: Could not determine download URLs for version '${MEOWCOIN_VERSION}'." >&2
  exit 1
fi

echo "---"
echo "Version: ${MEOWCOIN_VERSION}"
echo "Download URL: ${DOWNLOAD_URL}"
echo "Checksums URL: ${DOWNLOAD_SUMS_URL}"
echo "---"

echo "Downloading Meowcoin release..."
if ! download_with_retry "${DOWNLOAD_URL}" "meowcoin.tar.gz"; then
  echo "FATAL: Failed to download Meowcoin Core from ${DOWNLOAD_URL}." >&2
  exit 3
fi

echo "Downloading checksums..."
if ! download_with_retry "${DOWNLOAD_SUMS_URL}" "meowcoin.tar.gz.sha256sum"; then
  # If we're using a specific version, failing to download checksums is a critical error
  if [ "${MEOWCOIN_VERSION}" != "latest" ]; then
    echo "FATAL: Failed to download checksums for specific version ${MEOWCOIN_VERSION}. Aborting for security reasons."
    exit 5
  else
    echo "Warning: Failed to download checksums. This is a security risk."
    # Generate our own checksum for future reference
    echo "Generating local checksum for reference..."
    sha256sum meowcoin.tar.gz > meowcoin.tar.gz.local.sha256sum
    echo "Local checksum saved to meowcoin.tar.gz.local.sha256sum"
  fi
else
  # Verify checksums
  echo "Verifying checksums..."
  EXPECTED_CHECKSUM=$(cat meowcoin.tar.gz.sha256sum | awk '{print $1}')
  ACTUAL_CHECKSUM=$(sha256sum meowcoin.tar.gz | awk '{print $1}')
  
  if [[ "$EXPECTED_CHECKSUM" != "$ACTUAL_CHECKSUM" ]]; then
    echo "Checksum verification failed!"
    echo "Expected: $EXPECTED_CHECKSUM"
    echo "Actual:   $ACTUAL_CHECKSUM"
    echo "FATAL: Checksum verification failed. Aborting for security reasons."
    exit 4
  else
    echo "Checksum verification successful!"
  fi
fi

echo "Extracting archive..."
if ! tar -xzf meowcoin.tar.gz; then
  echo "FATAL: Failed to extract meowcoin.tar.gz. tar exited with code $?." >&2
  exit 3
fi

echo "Cleaning up..."
rm -f meowcoin.tar.gz

echo "Download and verification complete."
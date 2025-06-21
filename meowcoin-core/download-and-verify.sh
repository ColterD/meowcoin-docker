#!/bin/bash
# This script is responsible for downloading and verifying a specific
# or latest version of Meowcoin Core. It's designed to be run inside
# the Docker build context.

# Exit immediately if a command exits with a non-zero status.
# Treat unset variables as an error.
# The return value of a pipeline is the status of the last command to exit with a non-zero status.
set -euo pipefail

# Enable verbose output for easier debugging in build logs
set -x

# --- Arguments ---
# This script reads its configuration directly from environment variables
# set by the Dockerfile's ARG instructions. This is more robust than
# passing them as command-line arguments.

if [ -z "${MEOWCOIN_VERSION}" ]; then
  echo "Error: MEOWCOIN_VERSION environment variable is not set." >&2
  exit 1
fi

# --- Logic ---
if [ "${MEOWCOIN_VERSION}" = "latest" ]; then
  # Fetch release info from GitHub API
  RELEASE_INFO=$(curl -s --fail https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest)

  # Verify that we received a valid JSON response before proceeding
  if ! echo "${RELEASE_INFO}" | jq -e '.id' > /dev/null; then
    echo "Error: Failed to fetch valid release data from GitHub API." >&2
    echo "Response was: ${RELEASE_INFO}" >&2
    exit 1
  fi
  # Extract URLs using jq
  DOWNLOAD_URL=$(echo "${RELEASE_INFO}" | jq -r ".assets[] | select(.name | test(\\"x86_64-linux-gnu.tar.gz$")) | .browser_download_url")
  DOWNLOAD_SUMS_URL=$(echo "${RELEASE_INFO}" | jq -r ".assets[] | select(.name | test(\\"SHA256SUMS.asc$")) | .browser_download_url")
else
  # Construct URLs for a specific version
  DOWNLOAD_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/v${MEOWCOIN_VERSION}/meowcoin-${MEOWCOIN_VERSION}-x86_64-linux-gnu.tar.gz"
  DOWNLOAD_SUMS_URL="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/v${MEOWCOIN_VERSION}/SHA256SUMS.asc"
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
curl --fail -L -o meowcoin.tar.gz "${DOWNLOAD_URL}"

echo "Downloading checksums..."
curl --fail -L -o SHA256SUMS.asc "${DOWNLOAD_SUMS_URL}"

# GPG verification requires a temporary, isolated home directory
echo "Verifying GPG signature..."
# Create a temporary directory for GPG so we don't pollute the container
export GNUPGHOME="$(mktemp -d)"

# Import the bundled GPG key instead of fetching from a network keyserver.
# This makes the build process more reliable and deterministic.
echo "Importing bundled GPG key..."
gpg --batch --import /meowcoin_release.asc

# Verify the signature of the checksums file
echo "Verifying SHA256SUMS.asc..."
gpg --batch --verify SHA256SUMS.asc

echo "Verifying checksum..."
# Use sha256sum's built-in check feature for robustness. It will exit non-zero if validation fails.
sha256sum --check --ignore-missing SHA256SUMS.asc

echo "Extracting archive..."
tar -xzf meowcoin.tar.gz

echo "Cleaning up..."
rm -f meowcoin.tar.gz SHA256SUMS.asc
rm -rf "$GNUPGHOME"

echo "Download and verification complete." 
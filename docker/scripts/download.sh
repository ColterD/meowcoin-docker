#!/bin/bash
set -euo pipefail

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

# Main download function with version detection
download_meowcoin() {
    local version=$1
    local arch=$2
    local output_dir=$3
    
    # If version is "latest", fetch the latest version from API
    if [[ "$version" == "latest" ]]; then
        echo "Detecting latest version..."
        # Try GitHub API first
        if ! version=$(curl -s --fail "https://api.github.com/repos/Meowcoin-Foundation/Meowcoin/releases/latest" | jq -r '.tag_name' | sed 's/^[vV]//' | sed 's/^Meow-v//'); then
            # Fallback to website scraping if API fails
            version=$(curl -s --fail "https://meowcoin.org/downloads/" | grep -oP 'meowcoin-\K[0-9]+\.[0-9]+\.[0-9]+' | head -1 || echo "")
        fi
        
        if [[ -z "$version" ]]; then
            echo "Failed to detect latest version. Falling back to default version."
            version="2.0.5"
        fi
        
        echo "Latest version detected: $version"
    fi
    
    # Construct download URL
    local filename="meowcoin-${version}-${arch}.tar.gz"
    local download_url="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${version}/meowcoin-${version}-673684e10-${arch}.tar.gz"
    
    # Download the file
    if ! download_with_retry "$download_url" "${output_dir}/${filename}"; then
        echo "Failed to download Meowcoin. Exiting."
        return 1
    fi
    
    echo "Successfully downloaded Meowcoin version $version for $arch"
    echo "$filename" > "${output_dir}/VERSION"
    
    return 0
}

# Main execution
if [[ $# -lt 3 ]]; then
    echo "Usage: $0 <version> <architecture> <output_directory>"
    echo "  version: Meowcoin version (e.g., 2.0.5) or 'latest'"
    echo "  architecture: Target architecture (e.g., x86_64-linux-gnu)"
    echo "  output_directory: Directory to save downloaded files"
    exit 1
fi

VERSION="$1"
ARCH="$2"
OUTPUT_DIR="$3"

# Ensure output directory exists
mkdir -p "$OUTPUT_DIR"

# Download Meowcoin
download_meowcoin "$VERSION" "$ARCH" "$OUTPUT_DIR"
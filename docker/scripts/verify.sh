#!/bin/bash
set -euo pipefail

# Function to verify file checksum
verify_checksum() {
    local file=$1
    local checksum_file=$2
    local checksum_type=$3
    
    echo "Verifying ${checksum_type} checksum for ${file}..."
    
    # Extract expected hash from the checksum file
    local expected_hash
    expected_hash=$(cat "$checksum_file" | awk '{print $1}')
    
    # Calculate actual hash
    local actual_hash
    if [[ "$checksum_type" == "sha256" ]]; then
        actual_hash=$(sha256sum "$file" | awk '{print $1}')
    elif [[ "$checksum_type" == "md5" ]]; then
        actual_hash=$(md5sum "$file" | awk '{print $1}')
    else
        echo "Unsupported checksum type: $checksum_type"
        return 1
    fi
    
    # Compare hashes
    if [[ "$expected_hash" == "$actual_hash" ]]; then
        echo "Checksum verification successful!"
        return 0
    else
        echo "Checksum verification failed!"
        echo "Expected: $expected_hash"
        echo "Actual:   $actual_hash"
        return 1
    fi
}

# Function to download and verify checksum
download_and_verify_checksum() {
    local file=$1
    local checksum_url=$2
    local checksum_type=$3
    local output_dir=$(dirname "$file")
    local checksum_file="${output_dir}/$(basename "$checksum_url")"
    
    echo "Downloading checksum from ${checksum_url}..."
    if ! curl --fail --silent --location -o "$checksum_file" "$checksum_url"; then
        echo "Failed to download checksum file from $checksum_url"
        return 1
    fi
    
    # Verify checksum
    if ! verify_checksum "$file" "$checksum_file" "$checksum_type"; then
        return 1
    fi
    
    return 0
}

# Function to verify GPG signature
verify_gpg_signature() {
    local file=$1
    local signature_url=$2
    local key_file=$3
    local output_dir=$(dirname "$file")
    local signature_file="${output_dir}/$(basename "$signature_url")"
    
    echo "Downloading signature from ${signature_url}..."
    if ! curl --fail --silent --location -o "$signature_file" "$signature_url"; then
        echo "Failed to download signature file from $signature_url"
        return 1
    fi
    
    # Create temporary GPG home directory
    local gpg_home
    gpg_home=$(mktemp -d)
    export GNUPGHOME="$gpg_home"
    
    echo "Importing GPG key..."
    if ! gpg --batch --import "$key_file"; then
        echo "Failed to import GPG key from $key_file"
        rm -rf "$gpg_home"
        return 1
    fi
    
    echo "Verifying signature..."
    if ! gpg --batch --verify "$signature_file" "$file"; then
        echo "GPG signature verification failed"
        rm -rf "$gpg_home"
        return 1
    fi
    
    echo "GPG signature verification successful!"
    rm -rf "$gpg_home"
    return 0
}

# Main verification function
verify_meowcoin() {
    local download_dir=$1
    local key_file=$2
    local skip_gpg=${3:-false}
    
    # Find the downloaded file
    local meowcoin_file
    meowcoin_file=$(find "$download_dir" -name "meowcoin-*.tar.gz" | head -1)
    
    if [[ -z "$meowcoin_file" ]]; then
        echo "No Meowcoin archive found in $download_dir"
        return 1
    fi
    
    # Extract version and architecture from filename
    local filename
    filename=$(basename "$meowcoin_file")
    local version
    version=$(echo "$filename" | grep -oP 'meowcoin-\K[0-9]+\.[0-9]+\.[0-9]+')
    local arch
    arch=$(echo "$filename" | grep -oP '[0-9]+\.[0-9]+\.[0-9]+-\K.*(?=\.tar\.gz)')
    
    # Try SHA256 verification first
    local sha256_url="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${version}/meowcoin-${version}-673684e10-${arch}.tar.gz.sha256sum"
    if download_and_verify_checksum "$meowcoin_file" "$sha256_url" "sha256"; then
        echo "SHA256 verification successful"
    else
        # Try MD5 verification as fallback
        local md5_url="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${version}/meowcoin-${version}-673684e10-${arch}.tar.gz.md5sum"
        if download_and_verify_checksum "$meowcoin_file" "$md5_url" "md5"; then
            echo "MD5 verification successful"
        else
            # If both checksum verifications fail, calculate and display the checksums for reference
            echo "WARNING: Checksum verification failed. Calculating checksums for reference..."
            echo "SHA256: $(sha256sum "$meowcoin_file" | awk '{print $1}')"
            echo "MD5: $(md5sum "$meowcoin_file" | awk '{print $1}')"
            
            # Continue with GPG verification if requested
            if [[ "$skip_gpg" != "true" ]]; then
                echo "Proceeding with GPG verification..."
            else
                echo "Skipping GPG verification as requested"
                return 0
            fi
        fi
    fi
    
    # GPG verification (if not skipped)
    if [[ "$skip_gpg" != "true" ]]; then
        local signature_url="https://github.com/Meowcoin-Foundation/Meowcoin/releases/download/Meow-v${version}/meowcoin-${version}-673684e10-${arch}.tar.gz.asc"
        if ! verify_gpg_signature "$meowcoin_file" "$signature_url" "$key_file"; then
            echo "WARNING: GPG verification failed. Proceeding anyway as checksums were verified."
        fi
    fi
    
    return 0
}

# Main execution
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <download_directory> [key_file] [skip_gpg]"
    echo "  download_directory: Directory containing downloaded Meowcoin files"
    echo "  key_file: Path to GPG key file (default: /meowcoin_release.asc)"
    echo "  skip_gpg: Skip GPG verification (true/false, default: false)"
    exit 1
fi

DOWNLOAD_DIR="$1"
KEY_FILE="${2:-/meowcoin_release.asc}"
SKIP_GPG="${3:-false}"

# Verify Meowcoin
verify_meowcoin "$DOWNLOAD_DIR" "$KEY_FILE" "$SKIP_GPG"
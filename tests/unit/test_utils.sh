#!/bin/bash
# tests/unit/test_utils.sh
# Unit tests for utility functions

# Get script directory and project root
TEST_DIR=$(dirname "$0")
PROJECT_ROOT=$(cd "$TEST_DIR/../.." && pwd)
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
UTILS_SCRIPT="$SCRIPTS_DIR/core/utils.sh"

# Source utility functions
source "$UTILS_SCRIPT"

# Test generate_secure_random function
function test_generate_secure_random() {
    echo "Testing generate_secure_random function"
    
    # Test with default parameters
    local RESULT=$(generate_secure_random)
    if [[ ${#RESULT} -ne 32 ]]; then
        echo "FAIL: Default length should be 32, got ${#RESULT}"
        return 1
    fi
    
    # Test with custom length
    local RESULT=$(generate_secure_random 16)
    if [[ ${#RESULT} -ne 16 ]]; then
        echo "FAIL: Requested length 16, got ${#RESULT}"
        return 1
    fi
    
    # Test different types
    local HEX=$(generate_secure_random 16 "hex")
    local BASE64=$(generate_secure_random 16 "base64")
    local ALPHANUM=$(generate_secure_random 16 "alphanumeric")
    local PASSWORD=$(generate_secure_random 16 "password")
    
    # Verify hex characters only
    if [[ ! $HEX =~ ^[0-9a-f]+$ ]]; then
        echo "FAIL: Hex string contains non-hex characters: $HEX"
        return 1
    fi
    
    # Verify base64 characters
    if [[ ! $BASE64 =~ ^[A-Za-z0-9\-_]+$ ]]; then
        echo "FAIL: Base64 string contains invalid characters: $BASE64"
        return 1
    fi
    
    # Verify alphanumeric
    if [[ ! $ALPHANUM =~ ^[A-Za-z0-9]+$ ]]; then
        echo "FAIL: Alphanumeric string contains invalid characters: $ALPHANUM"
        return 1
    fi
    
    # Verify password has special chars
    if [[ ! $PASSWORD =~ [!@#$%^&*()\-_=+] ]]; then
        echo "FAIL: Password should contain special characters: $PASSWORD"
        return 1
    fi
    
    echo "PASS: generate_secure_random tests"
    return 0
}

# Test is_valid_ip function
function test_is_valid_ip() {
    echo "Testing is_valid_ip function"
    
    # Valid IPs
    local VALID_IPS=("127.0.0.1" "192.168.1.1" "10.0.0.1" "172.16.0.1" "255.255.255.255")
    
    # Invalid IPs
    local INVALID_IPS=("256.0.0.1" "192.168.1" "10.0.0.0.1" "172.16.0.1x" "test")
    
    # Test valid IPs
    for IP in "${VALID_IPS[@]}"; do
        if ! is_valid_ip "$IP"; then
            echo "FAIL: IP $IP should be valid"
            return 1
        fi
    done
    
    # Test invalid IPs
    for IP in "${INVALID_IPS[@]}"; do
        if is_valid_ip "$IP"; then
            echo "FAIL: IP $IP should be invalid"
            return 1
        fi
    done
    
    echo "PASS: is_valid_ip tests"
    return 0
}

# Run all tests
function run_tests() {
    echo "Running utils.sh unit tests"
    
    # Run individual tests
    test_generate_secure_random
    local RESULT1=$?
    
    test_is_valid_ip
    local RESULT2=$?
    
    # Check if any test failed
    if [[ $RESULT1 -ne 0 || $RESULT2 -ne 0 ]]; then
        echo "FAIL: Some tests failed"
        return 1
    fi
    
    echo "SUCCESS: All tests passed"
    return 0
}

# Execute tests
run_tests
exit $?
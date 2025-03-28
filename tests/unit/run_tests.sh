#!/bin/bash
# tests/unit/run_tests.sh
# Unit test framework for Meowcoin Docker scripts

# Global variables
TEST_DIR=$(dirname "$0")
PROJECT_ROOT=$(cd "$TEST_DIR/../.." && pwd)
SCRIPTS_DIR="$PROJECT_ROOT/scripts"
UTILS_SCRIPT="$SCRIPTS_DIR/core/utils.sh"
TEST_RESULTS_DIR="$TEST_DIR/results"
TEST_LOG="$TEST_RESULTS_DIR/test_run_$(date +%Y%m%d_%H%M%S).log"
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Initialize test environment
function init_test_env() {
    echo "Initializing test environment"
    mkdir -p "$TEST_RESULTS_DIR"
    
    # Source utilities
    if [[ -f "$UTILS_SCRIPT" ]]; then
        source "$UTILS_SCRIPT"
    else
        echo "ERROR: Could not find utils script at $UTILS_SCRIPT"
        exit 1
    fi
    
    # Create log file
    touch "$TEST_LOG"
    
    echo "Test run started at $(date -Iseconds)" | tee -a "$TEST_LOG"
    echo "Project root: $PROJECT_ROOT" | tee -a "$TEST_LOG"
    echo "Script directory: $SCRIPTS_DIR" | tee -a "$TEST_LOG"
    echo "---------------------------------" | tee -a "$TEST_LOG"
}

# Run a test
function run_test() {
    local TEST_FILE="$1"
    local TEST_NAME=$(basename "$TEST_FILE" .sh)
    
    echo "Running test: $TEST_NAME" | tee -a "$TEST_LOG"
    
    # Run the test
    bash "$TEST_FILE" > "$TEST_RESULTS_DIR/${TEST_NAME}_output.log" 2>&1
    local TEST_RESULT=$?
    
    # Update counters
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    if [[ $TEST_RESULT -eq 0 ]]; then
        echo "✓ PASS: $TEST_NAME" | tee -a "$TEST_LOG"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo "✗ FAIL: $TEST_NAME (exit code: $TEST_RESULT)" | tee -a "$TEST_LOG"
        echo "  See $TEST_RESULTS_DIR/${TEST_NAME}_output.log for details" | tee -a "$TEST_LOG"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    
    return $TEST_RESULT
}

# Run all tests
function run_all_tests() {
    echo "Running all tests in $TEST_DIR" | tee -a "$TEST_LOG"
    
    # Find and run all test files
    for TEST_FILE in "$TEST_DIR"/test_*.sh; do
        if [[ -f "$TEST_FILE" ]]; then
            run_test "$TEST_FILE"
        fi
    done
    
    # Print summary
    echo "---------------------------------" | tee -a "$TEST_LOG"
    echo "Test run completed at $(date -Iseconds)" | tee -a "$TEST_LOG"
    echo "Total tests: $TOTAL_TESTS" | tee -a "$TEST_LOG"
    echo "Passed: $PASSED_TESTS" | tee -a "$TEST_LOG"
    echo "Failed: $FAILED_TESTS" | tee -a "$TEST_LOG"
    
    if [[ $FAILED_TESTS -eq 0 ]]; then
        echo "All tests passed!" | tee -a "$TEST_LOG"
        return 0
    else
        echo "Some tests failed." | tee -a "$TEST_LOG"
        return 1
    fi
}

# Main function
function main() {
    init_test_env
    run_all_tests
    return $?
}

# Run main function
main
exit $?
#!/bin/bash
# Validation script to check that all fixes are properly implemented

set -euo pipefail

echo "=== Meowcoin Docker Fixes Validation ==="
echo "Date: $(date)"
echo ""

ISSUES_FOUND=0

# Function to report issues
report_issue() {
    echo "❌ ISSUE: $1"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
}

# Function to report success
report_success() {
    echo "✅ OK: $1"
}

echo "=== Checking File Structure ==="

# Check if all required files exist
required_files=(
    "docker-compose.yml"
    "meowcoin-core/Dockerfile"
    "meowcoin-core/entrypoint.sh"
    "meowcoin-core/download-and-verify.sh"
    "meowcoin-monitor/Dockerfile"
    "meowcoin-monitor/entrypoint.sh"
    "config/meowcoin.conf.template"
    ".env.example"
    "TROUBLESHOOTING.md"
    "FIXES_SUMMARY.md"
    "check-status.sh"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        report_success "File exists: $file"
    else
        report_issue "Missing file: $file"
    fi
done

echo ""
echo "=== Checking Docker Compose Configuration ==="

# Check for volume mount conflicts
if grep -q "meowcoin_logs:/tmp" docker-compose.yml; then
    report_issue "Volume mount conflict still exists (meowcoin_logs:/tmp)"
else
    report_success "Volume mount conflict fixed"
fi

# Check for proper log volume mount
if grep -q "meowcoin_logs:/var/log/meowcoin" docker-compose.yml; then
    report_success "Log volume properly mounted to /var/log/meowcoin"
else
    report_issue "Log volume not properly mounted"
fi

# Check for service dependency fix
if grep -A2 "depends_on:" docker-compose.yml | grep -q "condition: service_healthy"; then
    report_success "Service dependency uses service_healthy"
else
    report_issue "Service dependency not using service_healthy"
fi

echo ""
echo "=== Checking Security Improvements ==="

# Check for RPC binding security in template
if grep -q "rpcbind=127.0.0.1" config/meowcoin.conf.template && grep -q "rpcbind=0.0.0.0" config/meowcoin.conf.template; then
    report_success "RPC binding security implemented in template"
else
    report_issue "RPC binding security not implemented in template"
fi

# Check for RPC binding security in entrypoint
if grep -q "rpcbind=127.0.0.1" meowcoin-core/entrypoint.sh && grep -q "rpcbind=0.0.0.0" meowcoin-core/entrypoint.sh; then
    report_success "RPC binding security implemented in entrypoint"
else
    report_issue "RPC binding security not implemented in entrypoint"
fi

echo ""
echo "=== Checking Error Handling and Validation ==="

# Check for binary validation function
if grep -q "validate_binaries()" meowcoin-core/entrypoint.sh; then
    report_success "Binary validation function exists"
else
    report_issue "Binary validation function missing"
fi

# Check for signal handling
if grep -q "trap cleanup SIGTERM SIGINT" meowcoin-core/entrypoint.sh; then
    report_success "Signal handling implemented"
else
    report_issue "Signal handling not implemented"
fi

# Check for improved logging
if grep -q "LOG_DIR=" meowcoin-core/entrypoint.sh && grep -q "LOG_FILE=" meowcoin-core/entrypoint.sh; then
    report_success "Improved logging implemented in core"
else
    report_issue "Improved logging not implemented in core"
fi

if grep -q "LOG_DIR=" meowcoin-monitor/entrypoint.sh && grep -q "LOG_FILE=" meowcoin-monitor/entrypoint.sh; then
    report_success "Improved logging implemented in monitor"
else
    report_issue "Improved logging not implemented in monitor"
fi

echo ""
echo "=== Checking Download Script Improvements ==="

# Check for fallback URL pattern
if grep -q "alternative URL pattern" meowcoin-core/download-and-verify.sh; then
    report_success "Download script has fallback URL patterns"
else
    report_issue "Download script missing fallback URL patterns"
fi

echo ""
echo "=== Checking Dockerfile Improvements ==="

# Check for log directory creation in core Dockerfile
if grep -q "mkdir -p /var/log/meowcoin" meowcoin-core/Dockerfile; then
    report_success "Log directory creation in core Dockerfile"
else
    report_issue "Log directory creation missing in core Dockerfile"
fi

# Check for log directory creation in monitor Dockerfile
if grep -q "mkdir -p /var/log/meowcoin" meowcoin-monitor/Dockerfile; then
    report_success "Log directory creation in monitor Dockerfile"
else
    report_issue "Log directory creation missing in monitor Dockerfile"
fi

echo ""
echo "=== Checking Script Permissions ==="

# Check if scripts are executable
scripts=("check-status.sh" "meowcoin-core/entrypoint.sh" "meowcoin-monitor/entrypoint.sh" "meowcoin-core/download-and-verify.sh")

for script in "${scripts[@]}"; do
    if [ -x "$script" ]; then
        report_success "Script is executable: $script"
    else
        report_issue "Script is not executable: $script"
    fi
done

echo ""
echo "=== Checking Environment Configuration ==="

# Check if .env.example has required variables
required_vars=(
    "MEOWCOIN_VERSION"
    "MEOWCOIN_RPC_PORT"
    "MEOWCOIN_P2P_PORT"
    "RESOURCES_LIMIT_MEMORY"
    "MONITOR_INTERVAL"
)

for var in "${required_vars[@]}"; do
    if grep -q "^$var=" .env.example; then
        report_success "Environment variable in .env.example: $var"
    else
        report_issue "Missing environment variable in .env.example: $var"
    fi
done

echo ""
echo "=== Validation Summary ==="

if [ $ISSUES_FOUND -eq 0 ]; then
    echo "🎉 ALL CHECKS PASSED! All fixes have been properly implemented."
    echo ""
    echo "The repository is ready for use with the following improvements:"
    echo "- Fixed volume mount conflicts"
    echo "- Enhanced security with proper RPC binding"
    echo "- Improved error handling and validation"
    echo "- Better logging and troubleshooting"
    echo "- Robust download and build process"
    echo "- Comprehensive documentation"
    exit 0
else
    echo "⚠️  VALIDATION FAILED: $ISSUES_FOUND issues found."
    echo ""
    echo "Please review the issues above and fix them before proceeding."
    exit 1
fi
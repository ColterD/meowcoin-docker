#!/bin/bash
set -e

# Test harness for fetch-secrets.sh
# Mocks bws CLI and tests secret fetching, mapping, and error handling

TEST_DIR=$(mktemp -d)
export PATH="$TEST_DIR:$PATH"
export VAULT_TYPE="vaultwarden"
export VAULT_URL="http://localhost:8222"
export VAULT_ADMIN_TOKEN="dummy-token"
export SECRET_NAME_MAP="db_password:db_pw,jwt_secret:jwt"

# Mock bws CLI
cat > "$TEST_DIR/bws" <<'EOF'
#!/bin/bash
if [[ "$1" == "secret" && "$2" == "list" ]]; then
  echo 'db_pw="test_db_pw"'
  echo 'jwt="test_jwt_secret"'
fi
EOF
chmod +x "$TEST_DIR/bws"

# Set up /run/secrets
SECRETS_DIR="$TEST_DIR/run_secrets"
mkdir -p "$SECRETS_DIR"
export RUN_SECRETS="$SECRETS_DIR"

# Patch fetch-secrets.sh to use $RUN_SECRETS if set
FETCH_SCRIPT="$(dirname "$0")/fetch-secrets.sh"
sed "s|/run/secrets|\${RUN_SECRETS:-/run/secrets}|g" "$FETCH_SCRIPT" > "$TEST_DIR/fetch-secrets-test.sh"
chmod +x "$TEST_DIR/fetch-secrets-test.sh"

cd "$TEST_DIR"

# Test: fetch both secrets
./fetch-secrets-test.sh db_password jwt_secret
if [[ $(cat "$SECRETS_DIR/db_password") != "test_db_pw" ]]; then
  echo "FAIL: db_password not fetched correctly"
  exit 1
fi
if [[ $(cat "$SECRETS_DIR/jwt_secret") != "test_jwt_secret" ]]; then
  echo "FAIL: jwt_secret not fetched correctly"
  exit 1
fi

# Test: missing secret
set +e
./fetch-secrets-test.sh missing_secret > missing.log 2>&1
if ! grep -q "missing_secret" missing.log; then
  echo "FAIL: missing secret not reported"
  exit 1
fi
set -e

echo "All fetch-secrets.sh tests passed."
rm -rf "$TEST_DIR" 
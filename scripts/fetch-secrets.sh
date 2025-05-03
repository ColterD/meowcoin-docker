#!/bin/bash
set -e

# Fetch secrets from Vaultwarden or third-party vaults using CLI
# Usage: fetch-secrets.sh <secret_name1> <secret_name2> ...
# Expects VAULT_TYPE (optional), VAULT_URL, VAULT_ADMIN_TOKEN, etc.
# Supports secret name mapping via secrets/secret-mapping.json or SECRET_NAME_MAP env var

VAULT_TYPE=${VAULT_TYPE:-"vaultwarden"}
MAPPING_FILE="/secrets/secret-mapping.json"

# Ensure /run/secrets is secure
if [ -d /run/secrets ]; then
  chmod 700 /run/secrets
  chown $(id -u):$(id -g) /run/secrets
fi

# Load secret name mapping if present
declare -A SECRET_MAP
if [ -f "$MAPPING_FILE" ]; then
  while IFS= read -r line; do
    key=$(echo "$line" | grep -o '"[^"]*"' | head -1 | tr -d '"')
    value=$(echo "$line" | grep -o ': *"[^"]*"' | cut -d'"' -f2)
    if [ -n "$key" ] && [ -n "$value" ]; then
      SECRET_MAP[$key]="$value"
    fi
  done < <(grep ':' "$MAPPING_FILE")
elif [ -n "$SECRET_NAME_MAP" ]; then
  # Format: SECRET_NAME_MAP="db_password:db_pw,jwt_secret:jwt"
  IFS=',' read -ra PAIRS <<< "$SECRET_NAME_MAP"
  for pair in "${PAIRS[@]}"; do
    key="${pair%%:*}"
    value="${pair#*:}"
    SECRET_MAP[$key]="$value"
  done
fi

MISSING_SECRETS=()

if [ "$VAULT_TYPE" = "vaultwarden" ]; then
  VAULT_URL=${VAULT_URL:-"http://localhost:8222"}
  VAULT_ADMIN_TOKEN=${VAULT_ADMIN_TOKEN:-""}
  if ! command -v bws &> /dev/null; then
    echo "Bitwarden CLI (bws) is not installed. Exiting."
    exit 1
  fi
  if [ -z "$VAULT_ADMIN_TOKEN" ]; then
    echo "VAULT_ADMIN_TOKEN is not set. Exiting."
    exit 1
  fi
  bws config server-base "$VAULT_URL"
  export BWS_ACCESS_TOKEN="$VAULT_ADMIN_TOKEN"
  for SECRET_NAME in "$@"; do
    # Map secret name if mapping exists
    VAULT_KEY=${SECRET_MAP[$SECRET_NAME]:-$SECRET_NAME}
    echo "Fetching secret: $VAULT_KEY (for $SECRET_NAME)"
    SECRET_VALUE=$(bws secret list --output env | grep "^${VAULT_KEY}=" | cut -d'=' -f2- | tr -d '"')
    if [ -z "$SECRET_VALUE" ]; then
      echo "ERROR: Secret $VAULT_KEY (for $SECRET_NAME) not found in Vaultwarden."
      MISSING_SECRETS+=("$SECRET_NAME")
      continue
    fi
    echo -n "$SECRET_VALUE" > "/run/secrets/$SECRET_NAME"
    chmod 600 "/run/secrets/$SECRET_NAME"
    echo "Secret $SECRET_NAME written to /run/secrets/$SECRET_NAME"
  done
  if [ ${#MISSING_SECRETS[@]} -ne 0 ]; then
    echo "The following secrets were missing: ${MISSING_SECRETS[*]}"
    exit 2
  fi
elif [ "$VAULT_TYPE" = "hashicorp" ]; then
  # TODO: Implement HashiCorp Vault integration
  # Required environment variables:
  #   VAULT_ADDR: URL of the Vault server
  #   VAULT_TOKEN: Authentication token
  #   SECRET_PATH: Path to the secret (e.g., secret/data/myapp)
  # Required CLI tool: vault (https://developer.hashicorp.com/vault/docs/commands)
  # Example usage:
  #   vault kv get -field=<field> $SECRET_PATH
  #   vault kv get -format=json $SECRET_PATH | jq -r '.data.data.<field>'
  echo "TODO: HashiCorp Vault integration not yet implemented."
  echo "Required env: VAULT_ADDR, VAULT_TOKEN, SECRET_PATH, etc."
  exit 2
elif [ "$VAULT_TYPE" = "aws" ]; then
  # TODO: Implement AWS Secrets Manager integration
  # Required environment variables:
  #   AWS_ACCESS_KEY_ID
  #   AWS_SECRET_ACCESS_KEY
  #   AWS_REGION
  # Required CLI tool: aws (https://docs.aws.amazon.com/cli/latest/reference/secretsmanager/)
  # Example usage:
  #   aws secretsmanager get-secret-value --secret-id <secret_id> --query SecretString --output text
  echo "TODO: AWS Secrets Manager integration not yet implemented."
  echo "Required env: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION, etc."
  exit 2
else
  echo "Unknown VAULT_TYPE: $VAULT_TYPE. Supported: vaultwarden, hashicorp, aws."
  exit 2
fi 
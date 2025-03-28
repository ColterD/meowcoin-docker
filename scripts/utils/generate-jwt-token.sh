#!/bin/bash
# Generate a JWT token for API access

source /usr/local/bin/core/utils.sh

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
JWT_EXPIRY=${1:-3600}  # Default token expiry: 1 hour
JWT_SCOPE=${2:-"read,write"}  # Default scope: full access
JWT_SUBJECT=${3:-"meowcoin-api"}  # Default subject

if [[ ! -f "$JWT_SECRET_FILE" ]]; then
  log_error "JWT secret file not found. JWT authentication may not be enabled."
  exit 1
fi

# Generate header with algorithm from key type
if grep -q "BEGIN EC PRIVATE KEY" "$JWT_SECRET_FILE"; then
  # Determine algorithm from key size
  KEY_SIZE=$(openssl ec -in "$JWT_SECRET_FILE" -text -noout 2>/dev/null | grep "ASN1 OID" | awk '{print $3}')
  case "$KEY_SIZE" in
    prime256v1) ALGORITHM="ES256" ;;
    secp384r1) ALGORITHM="ES384" ;;
    secp521r1) ALGORITHM="ES512" ;;
    *) ALGORITHM="ES256" ;;  # Default
  esac
else
  ALGORITHM="HS256"  # Fallback to HMAC
fi

HEADER="{\"alg\":\"$ALGORITHM\",\"typ\":\"JWT\"}"
HEADER_B64=$(echo -n $HEADER | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Current timestamp for iat (issued at)
NOW=$(date +%s)
# Expiry timestamp
EXPIRY=$((NOW + JWT_EXPIRY))

# Generate payload with more claims
PAYLOAD="{\"iat\":$NOW,\"exp\":$EXPIRY,\"sub\":\"$JWT_SUBJECT\",\"scope\":\"$JWT_SCOPE\",\"iss\":\"meowcoin-node\",\"jti\":\"$(uuidgen || echo $RANDOM-$RANDOM-$RANDOM)\"}"
PAYLOAD_B64=$(echo -n $PAYLOAD | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')

# Combine header and payload
UNSIGNED_TOKEN="$HEADER_B64.$PAYLOAD_B64"

# Sign the token
if [[ "$ALGORITHM" == "ES256" || "$ALGORITHM" == "ES384" || "$ALGORITHM" == "ES512" ]]; then
  # For ECDSA, we need to use the right signature format
  SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha${ALGORITHM#ES} -sign "$JWT_SECRET_FILE" | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
else
  # For HMAC, we use the key directly
  SIGNATURE=$(echo -n "$UNSIGNED_TOKEN" | openssl dgst -sha256 -hmac "$(cat $JWT_SECRET_FILE)" -binary | openssl base64 -e -A | tr '+/' '-_' | tr -d '=')
fi

# Complete token
JWT_TOKEN="$UNSIGNED_TOKEN.$SIGNATURE"

echo "JWT Token: $JWT_TOKEN"
echo
echo "Token details:"
echo "  Algorithm: $ALGORITHM"
echo "  Subject: $JWT_SUBJECT"
echo "  Scope: $JWT_SCOPE"
echo "  Issued at: $(date -d @$NOW)"
echo "  Expires at: $(date -d @$EXPIRY)"
echo "  Valid for: $JWT_EXPIRY seconds"
echo
echo "Example usage:"
echo "curl -s -H \"Authorization: Bearer $JWT_TOKEN\" -H \"Content-Type: application/json\" -d '{\"method\":\"getblockchaininfo\",\"params\":[],\"id\":1}' http://localhost:8332/"
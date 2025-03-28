#!/bin/bash
# Script to rotate JWT keys

source /usr/local/bin/core/utils.sh

JWT_SECRET_FILE="/home/meowcoin/.meowcoin/.jwtsecret"
BACKUP_DIR="/home/meowcoin/.meowcoin/key-backups"
JWT_ALGORITHM=${1:-ES256}  # Default algorithm or pass as parameter

mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
chown meowcoin:meowcoin "$BACKUP_DIR"

# Backup existing key
if [[ -f "$JWT_SECRET_FILE" ]]; then
  BACKUP_FILE="$BACKUP_DIR/jwt_key_$(date +%Y%m%d_%H%M%S).bak"
  cp "$JWT_SECRET_FILE" "$BACKUP_FILE"
  chmod 600 "$BACKUP_FILE"
  chown meowcoin:meowcoin "$BACKUP_FILE"
  log_info "JWT key backed up to $BACKUP_FILE"
fi

# Generate new key based on algorithm
case "$JWT_ALGORITHM" in
  ES384) 
    log_info "Generating ES384 key (P-384 curve)"
    openssl ecparam -name secp384r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
  ES512)
    log_info "Generating ES512 key (P-521 curve)"
    openssl ecparam -name secp521r1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
  *)
    log_info "Generating ES256 key (P-256 curve)"
    openssl ecparam -name prime256v1 -genkey | openssl pkcs8 -topk8 -nocrypt -out "$JWT_SECRET_FILE"
    ;;
esac

chmod 600 "$JWT_SECRET_FILE"
chown meowcoin:meowcoin "$JWT_SECRET_FILE"

# Create public key for verification
openssl ec -in "$JWT_SECRET_FILE" -pubout -out "${JWT_SECRET_FILE}.pub" 2>/dev/null
chmod 640 "${JWT_SECRET_FILE}.pub"
chown meowcoin:meowcoin "${JWT_SECRET_FILE}.pub"

log_info "JWT key rotated successfully at $(date -Iseconds)"
log_info "You may need to restart the Meowcoin service for changes to take effect"
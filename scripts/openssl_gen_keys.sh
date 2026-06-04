#!/bin/bash
# ============================================
# OpenSRL Generate RSA Key Pair for QuickSight
# ============================================
# Generates 4096-bit RSA key pair for QuickSight
# RSA key-pair authentication in Snowflake.
#
# Usage: bash openssl_gen_keys.sh
#
# Output:
#   - quicksight_private_key.pem (private key, keep secure)
#   - quicksight_public_key.pem (public key, upload to Snowflake)
# ============================================

set -e

# Settings
KEY_SIZE=4096
KEY_DIR="snowflake"
PRIV_KEY="${KEY_DIR}/quicksight_priv_key.pem"
PUB_KEY="${KEY_DIR}/quicksight_pub_key.pem"

echo "=== QuickSight RSA Key Pair Generator ==="
echo ""

# Create the directory if it doesn't exist
mkdir -p "${KEY_DIR}"

# Step 1: Generate private key
echo "[1/3] Generating ${KEY_SIZE}-bit RSA private key..."
openssl genrsa -out "${PRIV_KEY}" ${KEY_SIZE}

# Step 2: Extract public key from private key
echo "[2/3] Extracting public key..."
openssl rsa -in "${PRIV_KEY}" -pubout -out "${PUB_KEY}"

# Step 3: Verify key pair
echo "[3/3] Verifying key pair..."
openssl rsa -in "${PRIV_KEY}" -pubout -text | openssl rsa -pubin -in /dev/stdin -text | head -1

echo ""
echo "=== Key Pair Generated Successfully ==="
echo ""
echo "Private key: ${PRIV_KEY}"
echo "Public key:  ${PUB_KEY}"
echo ""
echo "Next steps:"
echo "  1. Secure: chmod 600 ${PRIV_KEY}  (restrict ownership)"
echo "  2. Upload public key content to Snowflake via: 09_user_quicksight.sql"
echo "  3. Set 'RSA_PUBLIC_KEY' variable in SQL with the content of ${PUB_KEY}"
echo ""
echo "=== DONE ==="
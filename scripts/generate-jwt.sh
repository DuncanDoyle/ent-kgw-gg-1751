#!/bin/sh
# Generates a signed RS256 JWT using the local test RSA private key.
# Requires only openssl (available on macOS/Linux by default).
#
# Usage:
#   ./scripts/generate-jwt.sh                      # uses default private key
#   ./scripts/generate-jwt.sh path/to/private.pem  # uses specified private key
#
# Output: a JWT token on stdout, suitable for use as a Bearer token.

set -e

# Resolve the repo root relative to this script's location, so the script
# works regardless of the working directory it is called from.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

PRIVATE_KEY="${1:-${REPO_ROOT}/secrets/jwt-private.pem}"

if [ ! -f "$PRIVATE_KEY" ]; then
  echo "Error: Private key not found at $PRIVATE_KEY" >&2
  echo "Run: ./scripts/generate-keys.sh  (or ./install/setup.sh) first." >&2
  exit 1
fi

ISSUER="https://dev.example.com"
SUBJECT="test-user"
EXP=$(($(date +%s) + 3600))  # valid for 1 hour

# Base64url encode: standard base64 with no padding and URL-safe characters
b64url() {
  openssl base64 -e -A | tr '+/' '-_' | tr -d '='
}

HEADER=$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | b64url)
PAYLOAD=$(printf '%s' "{\"iss\":\"${ISSUER}\",\"sub\":\"${SUBJECT}\",\"exp\":${EXP},\"email\":\"user@example.com\"}" | b64url)

# Sign the header.payload with RSA-SHA256 (= RS256)
SIG=$(printf '%s' "${HEADER}.${PAYLOAD}" | openssl dgst -sha256 -sign "${PRIVATE_KEY}" -binary | b64url)

echo "${HEADER}.${PAYLOAD}.${SIG}"

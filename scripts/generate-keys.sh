#!/bin/sh
# Generates an RSA-2048 key pair for JWT signing/verification.
# The private key is used to sign test JWTs; the public key is embedded
# inline in the EnterpriseKgatewayTrafficPolicy JWKS.
#
# Run this before install/setup.sh, or let setup.sh call it automatically.

set -e

mkdir -p secrets

if [ -f secrets/jwt-private.pem ] && [ -f secrets/jwt-public.pem ]; then
  echo "Key pair already exists in secrets/ — skipping generation."
  echo "Delete secrets/jwt-private.pem and secrets/jwt-public.pem to regenerate."
  exit 0
fi

echo "Generating RSA-2048 key pair..."
openssl genrsa -out secrets/jwt-private.pem 2048 2>/dev/null
openssl rsa -in secrets/jwt-private.pem -pubout -out secrets/jwt-public.pem 2>/dev/null

echo "Done:"
echo "  Private key: secrets/jwt-private.pem"
echo "  Public key:  secrets/jwt-public.pem"

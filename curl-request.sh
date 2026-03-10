#!/bin/sh
# Test script for GG-1751: TransformationPolicy response transformations on
# locally-generated responses (e.g. JWT 401).
#
# The early staged transformation is configured to:
#   - Add header:  x-debug-transformation-early: applied
#   - Change 401 → 418
#
# Expected results if early transformation CAN intercept JWT local replies:
#   - No JWT:      418 + x-debug-transformation-early: applied
#   - Invalid JWT: 418 + x-debug-transformation-early: applied
#   - Valid JWT:   200 + x-debug-transformation-early: applied
#
# Actual results if early transformation CANNOT intercept JWT local replies (bug):
#   - No JWT:      401 (no x-debug-transformation-early header)
#   - Invalid JWT: 401 (no x-debug-transformation-early header)
#   - Valid JWT:   200 + x-debug-transformation-early: applied  (upstream responses work)

printf "\n=== Test 1: No JWT (missing token) ===\n"
printf "Expected if early transformation works: 418 + x-debug-transformation-early: applied\n"
printf "Actual (bug):                           401, no x-debug header\n\n"
curl -v http://api.example.com/get

printf "\n\n=== Test 2: Invalid JWT ===\n"
printf "Expected if early transformation works: 418 + x-debug-transformation-early: applied\n"
printf "Actual (bug):                           401, no x-debug header\n\n"
curl -v -H "Authorization: Bearer invalid.jwt.token" http://api.example.com/get

printf "\n\n=== Test 3: Valid JWT (upstream 200) ===\n"
printf "Expected: 200 + x-debug-transformation-early: applied (confirms early stage runs for upstream responses)\n\n"
VALID_TOKEN=$(sh scripts/generate-jwt.sh)
printf "Token: %s\n\n" "$VALID_TOKEN"
curl -v -H "Authorization: Bearer $VALID_TOKEN" http://api.example.com/get

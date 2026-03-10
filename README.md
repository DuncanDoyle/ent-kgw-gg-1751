# GG-1751: Staged transformation `early` stage cannot intercept JWT-generated 401 responses

**Issue:** https://github.com/solo-io/gloo-gateway/issues/1751

## Summary

`EnterpriseKgatewayTrafficPolicy` `entTransformation.stages.early` response transformations
cannot modify headers or status codes on **locally-generated responses** from the JWT filter
(`entJWT.beforeExtAuth`). This reproducer tests whether the same limitation exists in
Solo Enterprise for kgateway as was reported in GME (Gloo Mesh Enterprise + Istio).

The root cause in GME is that the Envoy `io.solo.transformation` filter is inserted **after**
the JWT filter in the HTTP filter chain. When JWT rejects a request and generates a local
reply, the response only traverses the encode path of filters that already processed the
request on the decode path — so the transformation filter never runs.

## Expected vs. Actual

| Scenario | Expected (if `early` stage works) | Actual (if bug present) |
|---|---|---|
| Missing JWT | `418` + `x-debug-transformation-early: applied` | `401`, no debug header |
| Invalid JWT | `418` + `x-debug-transformation-early: applied` | `401`, no debug header |
| Valid JWT (upstream 200) | `200` + `x-debug-transformation-early: applied` | `200` + `x-debug-transformation-early: applied` |

The valid-JWT case confirms the `early` stage DOES fire for upstream (non-local) responses.
If the JWT 401 cases don't show the header or 418, the bug is confirmed in Enterprise kgateway.

## Installation

Set your Solo Enterprise for kgateway license key:

```sh
export ENT_KGATEWAY_LICENSE_KEY=<your-license-key>
```

Then install Solo Enterprise for kgateway:

```sh
cd install
./install-ent-kgateway-with-helm.sh
```

## Setup

Run `install/setup.sh` to:
- Generate an RSA-2048 key pair (`secrets/jwt-private.pem`, `secrets/jwt-public.pem`)
- Deploy the Gateway, HTTPBin app, ReferenceGrant, and HTTPRoute
- Deploy the `EnterpriseKgatewayTrafficPolicy` with:
  - `entJWT.beforeExtAuth` using the generated inline JWKS (RSA public key)
  - `entTransformation.stages.early.responses` that transforms 401 → 418 and adds `x-debug-transformation-early: applied`

```sh
cd install
./setup.sh
```

## Generate a JWT

```sh
./scripts/generate-jwt.sh
```

This generates a valid RS256 JWT (1h TTL) signed with `secrets/jwt-private.pem`, which
matches the inline JWKS in the policy.

## Run the tests

```sh
./curl-request.sh
```

This tests three scenarios:
1. No JWT → should be 418 if `early` transformation intercepts JWT local replies
2. Invalid JWT → should be 418 if `early` transformation intercepts JWT local replies
3. Valid JWT → should be 200 with `x-debug-transformation-early: applied`

You can also test manually:

```sh
# No JWT
curl -v http://api.example.com/get

# Invalid JWT
curl -v -H "Authorization: Bearer invalid.jwt.token" http://api.example.com/get

# Valid JWT
TOKEN=$(./scripts/generate-jwt.sh)
curl -v -H "Authorization: Bearer $TOKEN" http://api.example.com/get
```

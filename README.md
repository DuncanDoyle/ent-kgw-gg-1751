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

Two setups are provided, differing in how JWT auth is configured:

| Setup | JWT resource | Transformation resource |
|---|---|---|
| `install/setup.sh` | `EnterpriseKgatewayTrafficPolicy.entJWT` | `EnterpriseKgatewayTrafficPolicy.entTransformation` |
| `install/setup-oss-jwt.sh` | `TrafficPolicy.jwtAuth` + `GatewayExtension` | `EnterpriseKgatewayTrafficPolicy.entTransformation` |

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

## Setup 1: `entJWT` in EnterpriseKgatewayTrafficPolicy

Deploys a single `EnterpriseKgatewayTrafficPolicy` combining `entJWT.beforeExtAuth` (JWT auth)
and `entTransformation.stages.early` (staged transformation) on the same resource.

```sh
cd install
./setup.sh
```

## Setup 2: `jwtAuth` in TrafficPolicy (OSS)

Deploys JWT auth using the OSS `TrafficPolicy.jwtAuth` referencing a `GatewayExtension` that
holds the JWT provider config (inline JWKS). The staged transformation is applied via a separate
`EnterpriseKgatewayTrafficPolicy` targeting the same HTTPRoute.

Resources deployed:
- `GatewayExtension/jwt-providers` — JWT provider with inline RSA public key
- `TrafficPolicy/jwt-auth` — references the `GatewayExtension` via `jwtAuth.extensionRef`
- `EnterpriseKgatewayTrafficPolicy/staged-transformation` — `entTransformation.stages.early` only

```sh
cd install
./setup-oss-jwt.sh
```

The two setup scripts are mutually exclusive and clean up after each other: running `setup.sh`
removes the OSS policies, and running `setup-oss-jwt.sh` removes the enterprise JWT policy.

## Generate a JWT

```sh
./scripts/generate-jwt.sh
```

This generates a valid RS256 JWT (1h TTL) signed with `secrets/jwt-private.pem`, which
matches the inline JWKS in the deployed policy.

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

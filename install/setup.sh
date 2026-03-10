#!/bin/sh

pushd ..

# Generate RSA key pair for JWT signing/verification (idempotent)
printf "\nGenerating JWT key pair...\n"
sh scripts/generate-keys.sh

# Deploy the Gateways
printf "\nDeploy Gateway...\n"
kubectl create namespace ingress-gw --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f gateways/gw-parameters.yaml
kubectl apply -f gateways/gw.yaml

# Create namespaces
kubectl create namespace httpbin --dry-run=client -o yaml | kubectl apply -f -

# Label default namespace so the Gateway accepts HTTPRoutes from it
printf "\nLabel default namespace...\n"
kubectl label namespaces default --overwrite shared-gateway-access="true"

# Deploy the HTTPBin application
printf "\nDeploy HTTPBin application...\n"
kubectl apply -f apis/httpbin.yaml

# Reference Grants
printf "\nDeploy Reference Grants...\n"
kubectl apply -f referencegrants/httpbin-ns/default-ns-httproute-service-rg.yaml

# HTTPRoute
printf "\nDeploy HTTPRoute...\n"
kubectl apply -f routes/api-example-com-httproute.yaml

# Remove OSS JWT policies if present (allows switching from setup-oss-jwt.sh)
printf "\nRemoving OSS JWT policies (if present)...\n"
kubectl delete trafficpolicy jwt-auth -n default --ignore-not-found
kubectl delete gatewayextension jwt-providers -n default --ignore-not-found
kubectl delete enterprisekgatewaytrafficpolicy staged-transformation -n default --ignore-not-found

# JWT + Staged Transformation policy
# The RSA public key is read from secrets/jwt-public.pem (generated above),
# indented to match the YAML structure, and injected inline into the policy.
printf "\nDeploy JWT + Staged Transformation policy...\n"
INDENTED_PUB_KEY=$(awk '{print "                " $0}' secrets/jwt-public.pem)
kubectl apply -f - <<EOF
apiVersion: enterprisekgateway.solo.io/v1alpha1
kind: EnterpriseKgatewayTrafficPolicy
metadata:
  name: jwt-staged-transformation
  namespace: default
spec:
  targetRefs:
    - name: api-example-com
      group: gateway.networking.k8s.io
      kind: HTTPRoute
  # JWT authentication — beforeExtAuth stage, so JWT runs before ExtAuth.
  #
  # ISSUE UNDER TEST (GG-1751):
  # When the JWT filter rejects a request and generates a local 401 reply,
  # does the 'early' staged transformation below intercept it?
  # If the 'early' transformation filter is placed AFTER the JWT filter in
  # the Envoy filter chain, it will never see the JWT-generated 401.
  entJWT:
    beforeExtAuth:
      providers:
        test-issuer:
          issuer: https://dev.example.com
          jwks:
            local:
              key: |
${INDENTED_PUB_KEY}
  # Staged transformation — 'early' stage runs before ExtAuth and other filters.
  entTransformation:
    stages:
      early:
        responses:
          - transformation:
              template:
                # Don't try to parse the response body as JSON — the JWT 401
                # body is plain text ("Jwt verification fails"), which would
                # cause a parse error and abort the transformation.
                parseBodyBehavior: DontParse
                headers:
                  # Debug header: present on response = early transformation fired.
                  # If absent on a JWT 401, the filter is not intercepting local replies.
                  "x-debug-transformation-early": "applied"
                  # Transform 401 -> 418 to make it visually obvious.
                  # Expected: 418  |  Actual (if bug): 401
                  ":status": '{% if header(":status") == "401" %}418{% else %}{{ header(":status") }}{% endif %}'
EOF

popd

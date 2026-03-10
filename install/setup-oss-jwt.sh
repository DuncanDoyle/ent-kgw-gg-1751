#!/bin/sh
# Second setup variant: uses OSS TrafficPolicy + GatewayExtension for JWT auth
# (instead of EnterpriseKgatewayTrafficPolicy.entJWT), combined with a separate
# EnterpriseKgatewayTrafficPolicy for the early staged transformation.

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

# Remove Enterprise JWT policy if present (allows switching from setup.sh)
printf "\nRemoving Enterprise JWT policy (if present)...\n"
kubectl delete enterprisekgatewaytrafficpolicy jwt-staged-transformation -n default --ignore-not-found

# GatewayExtension — holds the JWT provider config (OSS resource)
# The RSA public key is read from secrets/jwt-public.pem (generated above),
# indented to match the YAML structure, and injected inline.
printf "\nDeploy GatewayExtension (JWT providers)...\n"
INDENTED_PUB_KEY=$(awk '{print "              " $0}' secrets/jwt-public.pem)
kubectl apply -f - <<EOF
apiVersion: gateway.kgateway.dev/v1alpha1
kind: GatewayExtension
metadata:
  name: jwt-providers
  namespace: default
spec:
  jwt:
    providers:
      - name: test-issuer
        issuer: https://dev.example.com
        jwks:
          local:
            inline: |
${INDENTED_PUB_KEY}
EOF

# TrafficPolicy — references the GatewayExtension for JWT auth (OSS resource)
printf "\nDeploy TrafficPolicy (jwtAuth)...\n"
kubectl apply -f policies/oss-jwt/jwt-traffic-policy.yaml

# EnterpriseKgatewayTrafficPolicy — early staged transformation only
printf "\nDeploy EnterpriseKgatewayTrafficPolicy (staged transformation)...\n"
kubectl apply -f policies/oss-jwt/staged-transformation-policy.yaml

popd

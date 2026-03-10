
#!/bin/sh

export ENT_KGATEWAY_VERSION="2.1.2"
export ENT_KGATEWAY_HELM_VALUES_FILE="ent-kgateway-helm-values.yaml"
export K8S_GW_API_VERSION="v1.4.0"
export ENT_KGATEWAY_SYSTEM_NAMESPACE="kgateway-system"

if [ -z "$ENT_KGATEWAY_LICENSE_KEY" ]
then
   echo "Solo Enterprise for Kgateway License Key not specified. Please configure the environment variable 'SEFK_LICENSE_KEY' with your Solo Enterprise for Kgateway License Key."
   exit 1
fi

export ENT_KGATEWAY_CRDS_URL="oci://us-docker.pkg.dev/solo-public/enterprise-kgateway/charts/enterprise-kgateway-crds"
export ENT_KGATEWAY_URL="oci://us-docker.pkg.dev/solo-public/enterprise-kgateway/charts/enterprise-kgateway"

#----------------------------------------- Install Gloo Gateway with K8S Gateway API support -----------------------------------------

printf "\nApply K8S Gateway CRDs ....\n"
# kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$K8S_GW_API_VERSION/standard-install.yaml
# Note: --server-side is a workaround. If not applied, the HTTPRoute CRD will not install.
kubectl apply --server-side -f https://github.com/kubernetes-sigs/gateway-api/releases/download/$K8S_GW_API_VERSION/experimental-install.yaml


printf "\nInstall Solo Enterprise for Kgateway CRDs ....\n"
helm upgrade --install enterprise-kgateway-crds $ENT_KGATEWAY_CRDS_URL \
    --version $ENT_KGATEWAY_VERSION \
    --namespace $ENT_KGATEWAY_SYSTEM_NAMESPACE \
    --create-namespace \
    --set installExtAuthCRDs=true \
    --set installRateLimitCRDs=true \
    --set installEnterpriseListenerSetCRD=true

printf "\nInstall Solo Enterprise for Kgateway ...\n"
helm upgrade --install enterprise-kgateway $ENT_KGATEWAY_URL \
    --version $ENT_KGATEWAY_VERSION \
    --namespace $ENT_KGATEWAY_SYSTEM_NAMESPACE \
    --create-namespace \
    --set-string licensing.licenseKey=$ENT_KGATEWAY_LICENSE_KEY \
    -f $ENT_KGATEWAY_HELM_VALUES_FILE
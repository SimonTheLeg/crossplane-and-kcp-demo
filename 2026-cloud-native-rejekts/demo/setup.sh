#!/usr/bin/env bash
#
# Idempotent setup script for the crossplane-and-kcp demo.
#
set -euo pipefail

KCP_CHART_VERSION="0.14.0"
API_SYNCAGENT_CHART_VERSION="0.5.1"
CROSSPLANE_CHART_VERSION="2.2.0"
CERT_MANAGER_CHART_VERSION="v1.20.0"
KIND_NODE_IMAGE="kindest/node:v1.35.1"
PROVIDER_SQL_VERSION="v0.12.0"

export API_SYNCAGENT_CHART_VERSION CROSSPLANE_CHART_VERSION CERT_MANAGER_CHART_VERSION KCP_CHART_VERSION KIND_NODE_IMAGE PROVIDER_SQL_VERSION

cd "$(dirname "$0")"

# Redirect all command output through sed to indent it by 4 spaces.
# step() bypass this and write to the original stdout.
exec 3>&1
exec 1> >(sed 's/^/    /') 2>&1

# make the output of steps blue and bold
step() { printf '\033[1;34m%s\033[0m\n' "$*" >&3; }

# Setting Up kcp Cluster and kcp
step "Setting up kcp cluster and kcp..."
./1_kcp_setup/kind-setup.sh

# Wait until the kcp API server is ready to accept requests
step "Waiting for kcp API server to be reachable..."
export KUBECONFIG="kcp-admin.kubeconfig"
SECONDS=0
until kubectl get --raw "/readyz" &>/dev/null; do
  if (( SECONDS >= 180 )); then
    echo "Timed out waiting for kcp API server after 3 minutes."
    exit 1
  fi
  echo "kcp API server is not ready yet. Retrying in 10 seconds..."
  sleep 10
done
echo "kcp API server is ready!"

# Create the Provider workspace and kubeconfig
step "Creating Provider workspace..."
export KUBECONFIG="kcp-admin.kubeconfig"

if ! kubectl get workspace provider &>/dev/null; then
  kubectl create workspace provider
else
  echo "Workspace 'provider' already exists."
fi

yq '.clusters[0].cluster.server += ":provider"' kcp-admin.kubeconfig \
  | sed 's/admin-kcp/provider-kcp/g' > provider-kcp.kubeconfig
echo "Created provider kubeconfig at provider-kcp.kubeconfig"

# Create the Consumer workspace and kubeconfig
step "Creating Consumer workspace..."
export KUBECONFIG="kcp-admin.kubeconfig"

if ! kubectl get workspace consumer &>/dev/null; then
  kubectl create workspace consumer
else
  echo "Workspace 'consumer' already exists."
fi

yq '.clusters[0].cluster.server += ":consumer"' kcp-admin.kubeconfig \
  | sed 's/admin-kcp/consumer-kcp/g' > consumer-kcp.kubeconfig
echo "Created consumer kubeconfig at consumer-kcp.kubeconfig"

# Create the provider's APIExport
step "Applying APIExport..."
export KUBECONFIG="provider-kcp.kubeconfig"
kubectl apply -f 2_provider_setup/kcp/apiexport.yaml

# Setting Up Provider kind Cluster
step "Setting up Provider kind cluster..."
export KUBECONFIG="provider-kind.kubeconfig"

if ! kind get clusters 2>/dev/null | grep -w -q provider; then
  kind create cluster --name provider --image "${KIND_NODE_IMAGE}" --config ./2_provider_setup/kind/config.yaml
else
  echo "Kind cluster 'provider' already exists."
fi

# Patch CoreDNS to rewrite kcp.dev.local -> host.docker.internal
step "Patching CoreDNS for kcp.dev.local rewrite..."
export KUBECONFIG="provider-kind.kubeconfig"

CURRENT_COREFILE=$(kubectl get configmap coredns -n kube-system -o jsonpath='{.data.Corefile}')

if echo "$CURRENT_COREFILE" | grep -q "rewrite name kcp.dev.local"; then
  echo "CoreDNS rewrite already present."
else
  # Insert rewrite rule after the "ready" line in the existing server block
  PATCHED_COREFILE=$(echo "$CURRENT_COREFILE" | sed '/^[[:space:]]*ready$/a\
    rewrite name kcp.dev.local host.docker.internal
')

  kubectl create configmap coredns -n kube-system \
    --from-literal=Corefile="$PATCHED_COREFILE" \
    --dry-run=client -o yaml | kubectl replace -f -

  kubectl rollout restart -n kube-system deployment/coredns
  kubectl rollout status  -n kube-system deployment/coredns --timeout=60s
fi

# Install and setup kcp api-syncagent
step "Installing kcp api-syncagent..."
export KUBECONFIG="provider-kind.kubeconfig"

kubectl create namespace kcp-sync-agent --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic kcp-kubeconfig -n kcp-sync-agent \
  --from-file=kubeconfig=provider-kcp.kubeconfig \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 2_provider_setup/api-syncagent/additional-rbac

helm repo add kcp https://kcp-dev.github.io/helm-charts 2>/dev/null
helm repo update

helm upgrade \
  --install \
  --values ./2_provider_setup/api-syncagent/values.yaml \
  --namespace kcp-sync-agent \
  --create-namespace \
  --version "${API_SYNCAGENT_CHART_VERSION}" \
  kcp-api-syncagent kcp/api-syncagent

# Install Crossplane
step "Installing Crossplane..."
export KUBECONFIG="provider-kind.kubeconfig"

helm repo add crossplane-stable https://charts.crossplane.io/stable 2>/dev/null
helm repo update

helm upgrade \
  --install \
  --namespace crossplane-system \
  --create-namespace \
  --version "${CROSSPLANE_CHART_VERSION}" \
  crossplane crossplane-stable/crossplane

# wait for crossplane to be ready before applying any crossplane resources
step "Waiting for Crossplane to be ready..."
kubectl wait --for=condition=available deployment/crossplane -n crossplane-system --timeout=300s

# Setup the Database
step "Deploying MySQL database..."
export KUBECONFIG="provider-kind.kubeconfig"
kubectl apply -f 2_provider_setup/database/

# Setup provider-sql
step "Setting up provider-sql..."
export KUBECONFIG="provider-kind.kubeconfig"

envsubst < 2_provider_setup/provider/provider.yaml | kubectl apply -f -
kubectl wait --for condition=healthy -f 2_provider_setup/provider/provider.yaml --timeout=300s

kubectl create secret generic db-conn \
  --from-literal endpoint=mysql.default.svc.cluster.local \
  --from-literal port=3306 \
  --from-literal username=root \
  --from-literal password=password \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f 2_provider_setup/provider/config.yaml

# Setup The Crossplane Composite Resource
step "Applying Crossplane composite resources..."
export KUBECONFIG="provider-kind.kubeconfig"
kubectl apply -f 2_provider_setup/crossplane/

step "Setup complete!"

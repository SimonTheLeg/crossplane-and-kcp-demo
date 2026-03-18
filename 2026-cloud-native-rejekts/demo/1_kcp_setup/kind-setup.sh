#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

: "${CERT_MANAGER_CHART_VERSION:?must be set}"
: "${KCP_CHART_VERSION:?must be set}"
: "${KIND_NODE_IMAGE:?must be set}"

kind=kind
if ! [ -x "$(command -v kind)" ]; then
  echo "kind is not installed. Please install kind"
  exit 1
fi

CLUSTER_NAME="${CLUSTER_NAME:-kcp}"
KUBECONFIG="$(realpath ..)/${CLUSTER_NAME}-kind.kubeconfig"
export KUBECONFIG
export KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-}"
  
if ! $kind get clusters | grep -w -q "$CLUSTER_NAME"; then
  $kind create cluster \
    --name "$CLUSTER_NAME" \
    --image "${KIND_NODE_IMAGE}" \
    --config ./kind/config.yaml
else
  echo "Cluster $CLUSTER_NAME already exists."
fi

echo "Installing cert-manager..."

helm repo add jetstack https://charts.jetstack.io
helm repo update

kubectl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_CHART_VERSION}/cert-manager.crds.yaml"
helm upgrade \
  --install \
  --wait \
  --namespace cert-manager \
  --create-namespace \
  --version "${CERT_MANAGER_CHART_VERSION}" \
  cert-manager jetstack/cert-manager

# Installing cert-manager will end with a message saying that the next step
# is to create some Issuers and/or ClusterIssuers.  That is indeed
# among the things that the kcp helm chart will do.

echo "Installing KCP..."

helm repo add kcp https://kcp-dev.github.io/helm-charts
helm repo update
helm upgrade \
  --install \
  --values ./values.yaml \
  --namespace kcp \
  --create-namespace \
  --version "${KCP_CHART_VERSION}" \
  kcp kcp/kcp

echo "Generating KCP admin kubeconfig..."
./generate-admin-kubeconfig.sh

hostname="$(yq '.externalHostname' values.yaml)"

echo "Checking /etc/hosts for ${hostname}..."
if ! grep -q "$hostname" /etc/hosts; then
  echo "127.0.0.1 $hostname" | sudo tee -a /etc/hosts
  echo "::1 $hostname" | sudo tee -a /etc/hosts
else
  echo "$hostname already exists in /etc/hosts."
fi

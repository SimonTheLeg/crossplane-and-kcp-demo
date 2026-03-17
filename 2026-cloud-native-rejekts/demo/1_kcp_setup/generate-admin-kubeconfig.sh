#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")"

hostname="$(yq '.externalHostname' values.yaml)"

cat << EOF > ../kcp-admin.kubeconfig
apiVersion: v1
kind: Config
clusters:
  - cluster:
      insecure-skip-tls-verify: true
      server: "https://${hostname}:8443/clusters/root"
    name: admin-kcp
contexts:
  - context:
      cluster: admin-kcp
      user: admin-kcp
    name: admin-kcp
current-context: admin-kcp
users:
  - name: admin-kcp
    user:
      token: admin-token
EOF

echo "Kubeconfig file created at kcp-admin.kubeconfig"
echo ""
echo "export KUBECONFIG=kcp-admin.kubeconfig"
echo ""

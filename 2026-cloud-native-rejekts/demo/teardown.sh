#!/usr/bin/env bash
#
# Idempotent teardown script for the crossplane-and-kcp demo.
#
set -euo pipefail

cd "$(dirname "$0")"

# Redirect all command output through sed to indent it by 4 spaces.
# step() bypasses this and writes to the original stdout.
exec 3>&1 4>&2
exec 1> >(sed 's/^/    /') 2>&1

step() { printf '\033[1;34m%s\033[0m\n' "$*" >&3; }

step "Deleting kind clusters..."

if kind get clusters 2>/dev/null | grep -w -q provider; then
  kind delete cluster --name provider
else
  echo "Kind cluster 'provider' does not exist. Skipping."
fi

if kind get clusters 2>/dev/null | grep -w -q kcp; then
  kind delete cluster --name kcp
else
  echo "Kind cluster 'kcp' does not exist. Skipping."
fi

# Remove kubeconfig files
step "Removing kubeconfig files..."
for f in kcp-kind.kubeconfig kcp-admin.kubeconfig provider-kcp.kubeconfig consumer-kcp.kubeconfig provider-kind.kubeconfig; do
  if [ -f "$f" ]; then
    rm "$f"
    echo "Removed $f"
  else
    echo "$f does not exist."
  fi
done

step "Teardown complete!"


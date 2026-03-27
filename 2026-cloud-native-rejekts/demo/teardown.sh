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

source "$(dirname "$0")/lib.sh"

ENABLE_CACHE=${ENABLE_CACHE:-false}

if [ "$ENABLE_CACHE" = "true" ]; then
# Cache container images from kind nodes before deleting clusters.
# This saves all images so they can be preloaded on next setup.
step "Caching container images..."
CACHE_DIR=".image-cache"
mkdir -p "$CACHE_DIR"

for cluster in kcp provider; do
  container="${cluster}-control-plane"
  if docker inspect "$container" &>/dev/null; then
    # get all tagged images
    images=$(docker exec "$container" ctr -n k8s.io images list -q \
      | grep -v '^sha256:' | sort -u || true)
    if [ -n "$images" ]; then
      # Re-pull each image with all platforms so export won't fail on missing blobs
      # see https://github.com/containerd/containerd/issues/5895
      echo "Fetching all platforms for images in ${cluster} cluster..."
      while IFS= read -r img; do
        echo "Pulling all platforms for ${img}..."
        docker exec "$container" ctr -n k8s.io images pull --all-platforms "$img" 2>&1 \
          | tr '\r' '\n' | grep --line-buffered 'elapsed' || \
          echo "Warning: failed to pull all platforms for ${img}. Continuing."
      done <<< "$images"

      echo "Exporting images from ${cluster} cluster..."
      if docker exec "$container" ctr -n k8s.io images export --all-platforms - $images \
        > "${CACHE_DIR}/${cluster}-images.tar"; then
        echo "Cached $(echo "$images" | wc -l | tr -d ' ') images for ${cluster}."
      else
        echo "Warning: failed to export images for ${cluster}. Continuing."
        rm -f "${CACHE_DIR}/${cluster}-images.tar"
      fi
    else
      echo "No images to cache for ${cluster}."
    fi
  else
    echo "Container '${container}' is not running. Skipping cache for ${cluster}."
  fi
done

fi

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


#!/usr/bin/env bash

# make the output of steps blue and bold
step() { printf '\033[1;34m%s\033[0m\n' "$*" >&3; }

# Check if a kind node already has non-default images loaded.
# Returns 0 (true) if only default kind images are present.
needs_image_preload() {
  local container="$1"
  local non_default
  non_default=$(docker exec "$container" ctr -n k8s.io images list -q \
    | grep -v '^sha256:' \
    | grep -v 'registry.k8s.io' \
    | grep -v 'docker.io/kindest/' \
    | head -1 || true)
  if [ -n "$non_default" ]; then
    return 1
  fi
}

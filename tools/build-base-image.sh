#!/usr/bin/env bash
# =============================================================================
# tools/build-base-image.sh — Pre-baked base image builder.
#
# Launches a temporary Ubuntu Minimal VM, installs the full shared node stack
# (system config, container runtime, Kubernetes tools, shared images), exports
# the disk image, and registers it in versions.json.
#
# The resulting image is used by main.sh to skip provisioning on every cluster
# spin-up, significantly reducing cold-start time.
#
# Installed into the image:
#   System:   swap-off, ipv4-forward, iptables-bridge
#   Runtime:  containerd, runc, cni-plugins
#   K8s:      kubeadm, kubelet, kubectl, crictl config (shared by all nodes)
#   Images:   pause, kube-proxy (shared node images — CP-specific pulled later)
#
# Usage:
#   tools/build-base-image.sh [K8S_VERSION_KEY]   (default: 1.35_base)
#
# After building, versions.json is updated with the image path automatically.
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"

require_cmd multipass
require_cmd jq

K8S_VERSION="${1:-1.35_base}"
BUILDER_NAME="base-image-builder"
OUTPUT_DIR="$SCRIPT_DIR/images"

# find_vault_image
# Search known Multipass vault paths for the builder VM disk image.
# Tries a set of candidate paths first, then falls back to a broad filesystem
# search. Prints the first matching .img path and returns.
find_vault_image() {
  local candidates=(
    "/var/snap/multipass/common/data/multipassd/vault/instances/$BUILDER_NAME"
    "/home/$USER/snap/multipass/common/data/multipassd/vault/instances/$BUILDER_NAME"
    "/root/snap/multipass/common/data/multipassd/vault/instances/$BUILDER_NAME"
  )
  for dir in "${candidates[@]}"; do
    local f
    f=$(sudo find "$dir" -maxdepth 1 -name "*.img" 2>/dev/null | head -1)
    [[ -n "$f" ]] && echo "$f" && return
  done
  sudo find / -maxdepth 10 -path "*multipass*/$BUILDER_NAME/*.img" 2>/dev/null | head -1
}

# Ubuntu Minimal 24.04 — no snapd, no Python, no man pages (~40% smaller than noble)
MINIMAL_IMAGE="https://cloud-images.ubuntu.com/minimal/releases/noble/release/ubuntu-24.04-minimal-cloudimg-amd64.img"

export LOG_SESSION_DIR
LOG_SESSION_DIR="$SCRIPT_DIR/logs/build_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$LOG_SESSION_DIR" "$OUTPUT_DIR"

get_version_info "$K8S_VERSION"

OUTPUT_IMAGE="$OUTPUT_DIR/base-node-${K8S_VERSION}.img"

[[ ! -f "$OUTPUT_IMAGE" ]] || die "Image already exists: $OUTPUT_IMAGE — delete it first to rebuild."

# On error: purge the builder VM to avoid leaving orphaned instances
trap 'multipass delete "$BUILDER_NAME" --purge 2>/dev/null || true' ERR

section "Launching base builder VM (Ubuntu Minimal 24.04)"
multipass info "$BUILDER_NAME" &>/dev/null && die "VM $BUILDER_NAME already exists — delete it first."
multipass launch "$MINIMAL_IMAGE" \
  --name "$BUILDER_NAME" \
  --cpus 2 \
  --memory 2G \
  --disk 15G

section "Configuring kernel / system settings"
# Run system config scripts in parallel — they are independent of each other
for script in disable-swap ipv4-forward iptables; do
  run_on_node "$BUILDER_NAME" "$SCRIPT_DIR/lib/virtual-infrastructure/injections/$script.sh" &
done
wait

section "Pre-installing apt prerequisites"
multipass exec "$BUILDER_NAME" -- sudo bash -c '
  apt-get update -qq
  apt-get install -y --no-install-recommends apt-transport-https ca-certificates curl gpg
  apt-get clean
  rm -rf /var/lib/apt/lists/*
'

section "Installing container runtime stack"
run_on_node_env "$BUILDER_NAME" \
  "$SCRIPT_DIR/lib/kube-bootstrap/injections/containerd.sh" \
  "VERSION=$CONTAINERD_VERSION CHECK_SUM_URL=$CONTAINERD_URL SERVICE_URL=$CONTAINERD_SERVICE_URL"

run_on_node_env "$BUILDER_NAME" \
  "$SCRIPT_DIR/lib/kube-bootstrap/injections/runc.sh" \
  "VERSION=$RUNC_VERSION URL=$RUNC_URL"

run_on_node_env "$BUILDER_NAME" \
  "$SCRIPT_DIR/lib/kube-bootstrap/injections/cni.sh" \
  "VERSION=$CNI_VERSION URL=$CNI_URL"

section "Installing Kubernetes tools (all nodes: kubeadm, kubelet, kubectl)"
run_on_node_env "$BUILDER_NAME" \
  "$SCRIPT_DIR/lib/kube-bootstrap/injections/kube.sh" \
  "VERSION=$K8S_PATCH URL=$K8S_REPO RELEASE_KEY=$K8S_RELEASE_KEY"

run_on_node "$BUILDER_NAME" \
  "$SCRIPT_DIR/lib/kube-bootstrap/injections/crictl-containerd.sh"

section "Pre-pulling shared node images (pause + kube-proxy)"
# Only pull images shared by all nodes — CP-specific images (apiserver, etcd,
# scheduler, etc.) are pulled at kubeadm init time on the control-plane only.
multipass exec "$BUILDER_NAME" -- sudo bash -c "
  kubeadm config images list --kubernetes-version ${K8S_PATCH} \
    | grep -E 'pause|kube-proxy' \
    | while read -r img; do
        echo \"Pulling \$img\"
        ctr -n k8s.io images pull \"\$img\"
      done
"

section "Cleaning up image before export"
# Zero-fill free space so the copy compresses well
multipass exec "$BUILDER_NAME" -- sudo bash -c '
  apt-get autoremove --purge -y -qq
  apt-get clean
  rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
  dd if=/dev/zero of=/zero bs=4M 2>/dev/null || true
  rm -f /zero
  sync
'

section "Stopping builder VM"
multipass stop "$BUILDER_NAME"

section "Exporting disk image (requires sudo)"
IMAGE_FILE=$(find_vault_image)
[[ -n "$IMAGE_FILE" ]] || die "Could not locate disk image for $BUILDER_NAME in known Multipass vault paths"

sudo cp "$IMAGE_FILE" "$OUTPUT_IMAGE"
sudo chown "$(id -u):$(id -g)" "$OUTPUT_IMAGE"

section "Cleaning up builder VM"
multipass delete "$BUILDER_NAME" --purge

trap - ERR

section "Registering image in versions.json"
jq --arg v "$K8S_VERSION" --arg path "$OUTPUT_IMAGE" \
  '.[$v]["virtual-layer"]["base_image"] = $path' \
  "$SCRIPT_DIR/versions.json" > "$SCRIPT_DIR/versions.json.tmp" \
  && mv "$SCRIPT_DIR/versions.json.tmp" "$SCRIPT_DIR/versions.json"

echo ""
echo "Base image built and registered: $OUTPUT_IMAGE"
echo "versions.json updated — main.sh will use this image on the next run."

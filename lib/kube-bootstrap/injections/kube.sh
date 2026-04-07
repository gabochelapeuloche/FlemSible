#!/usr/bin/env bash
# =============================================================================
# lib/kube-bootstrap/injections/kube.sh — kubeadm / kubelet / kubectl install.
#
# Adds the Kubernetes apt repository and installs pinned versions of kubeadm,
# kubelet, and kubectl. Marks them as held to prevent unintended upgrades.
# Baked into the base image — skipped at provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes (both control-plane and workers need these binaries)
# Injected: VERSION (patch version e.g. 1.35.0), URL (apt repo URL),
#           RELEASE_KEY (GPG key URL)
# =============================================================================
set -Eeuo pipefail

VERSION="${VERSION:-}"
URL="${URL:-}"
RELEASE_KEY="${RELEASE_KEY:-}"

COMPONENT="kubernetes"
APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"
PACKAGE="${VERSION}-1.1"

# is_installed
# Return 0 if kubeadm, kubelet, and kubectl are all present at the expected
# version, 1 otherwise.
is_installed() {
  command -v kubeadm >/dev/null 2>&1 &&
  command -v kubelet >/dev/null 2>&1 &&
  command -v kubectl >/dev/null 2>&1 &&
  kubeadm version -o short | grep -q "v${VERSION}"
}

# install
# Add the Kubernetes apt repo, install the pinned package versions, and
# mark them as held so apt upgrade does not update them unintentionally.
install() {
  echo "[$COMPONENT] installing Kubernetes $VERSION"

  # apt prerequisites for HTTPS repos and GPG verification
  sudo apt-get update -qq
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg

  sudo mkdir -p /etc/apt/keyrings
  if [[ ! -f "$APT_KEYRING" ]]; then
    curl -fsSL "$RELEASE_KEY" | sudo gpg --dearmor -o "$APT_KEYRING"
  fi

  if [[ ! -f "$APT_SOURCE" ]]; then
    echo "deb [signed-by=$APT_KEYRING] $URL /" | sudo tee "$APT_SOURCE" >/dev/null
  fi

  sudo apt-get update -qq
  sudo apt-get install -y \
    kubelet="$PACKAGE" \
    kubeadm="$PACKAGE" \
    kubectl="$PACKAGE" \
    --allow-downgrades --allow-change-held-packages

  sudo apt-mark hold kubelet kubeadm kubectl
}

main() {
  is_installed || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

#!/usr/bin/env bash
# Performing kube (kubeadm, kubelet, kubectl) installation on the control-plane node
# This script will need to be executed directly on workers and cp
set -Eeuo pipefail

COMPONENT="kubernetes"
APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

# Arguments to feed before injecting script into the nodes
VERSION="${VERSION:-}"
URL="${URL:-}"
RELEASE_KEY="${RELEASE_KEY:-}"


PACKAGE="${VERSION}-1.1"

is_installed() {
  command -v kubeadm >/dev/null 2>&1 &&
  command -v kubelet >/dev/null 2>&1 &&
  command -v kubectl >/dev/null 2>&1 &&
  kubeadm version -o short | grep -q "v${VERSION}"
}

install() {
  echo "[$COMPONENT] installing Kubernetes $VERSION"

  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg

  sudo mkdir -p /etc/apt/keyrings
  if [[ ! -f "$APT_KEYRING" ]]; then
    curl -fsSL "$RELEASE_KEY" \
      | sudo gpg --dearmor -o "$APT_KEYRING"
  fi

  if [[ ! -f "$APT_SOURCE" ]]; then
    echo "deb [signed-by=$APT_KEYRING] $URL /" \
      | sudo tee "$APT_SOURCE" >/dev/null
  fi

  sudo apt-get update
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
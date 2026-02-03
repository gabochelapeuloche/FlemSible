#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="kubernetes"
K8S_VERSION="1.29.6"
K8S_MINOR="${K8S_VERSION%.*}"
PKG_VERSION="${K8S_VERSION}-1.1"

APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

is_installed() {
  command -v kubeadm >/dev/null 2>&1 &&
  command -v kubelet >/dev/null 2>&1 &&
  command -v kubectl >/dev/null 2>&1 &&
  kubeadm version -o short | grep -q "v${K8S_VERSION}"
}

install() {
  echo "[$COMPONENT] installing Kubernetes $K8S_VERSION"

  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gpg

  sudo mkdir -p /etc/apt/keyrings
  if [[ ! -f "$APT_KEYRING" ]]; then
    curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/Release.key" \
      | sudo gpg --dearmor -o "$APT_KEYRING"
  fi

  if [[ ! -f "$APT_SOURCE" ]]; then
    echo "deb [signed-by=$APT_KEYRING] https://pkgs.k8s.io/core:/stable:/v${K8S_MINOR}/deb/ /" \
      | sudo tee "$APT_SOURCE" >/dev/null
  fi

  sudo apt-get update
  sudo apt-get install -y \
    kubelet="$PKG_VERSION" \
    kubeadm="$PKG_VERSION" \
    kubectl="$PKG_VERSION" \
    --allow-downgrades --allow-change-held-packages

  sudo apt-mark hold kubelet kubeadm kubectl
}

verify() {
  kubeadm version -o short | grep -q "v${K8S_VERSION}" \
    || { echo "❌ kubeadm wrong version"; exit 1; }

  kubelet --version | grep -q "v${K8S_VERSION}" \
    || { echo "❌ kubelet wrong version"; exit 1; }

  kubectl version --client --short | grep -q "v${K8S_VERSION}" \
    || { echo "❌ kubectl wrong version"; exit 1; }

  systemctl is-enabled kubelet >/dev/null \
    || { echo "❌ kubelet is not enabled"; exit 1; }

  apt-mark showhold | grep -q kubelet \
    || { echo "❌ kubelet not held"; exit 1; }
}

main() {
  is_installed || install
  # verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
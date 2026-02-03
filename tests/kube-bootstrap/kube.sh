#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="kubernetes"
K8S_VERSION="1.29.6"
K8S_MINOR="${K8S_VERSION%.*}"
PKG_VERSION="${K8S_VERSION}-1.1"

APT_KEYRING="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
APT_SOURCE="/etc/apt/sources.list.d/kubernetes.list"

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
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
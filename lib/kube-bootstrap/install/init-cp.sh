#!/usr/bin/env bash
set -Eeuo pipefail

export KUBECONFIG=/etc/kubernetes/admin.conf
export PAGER=cat
export KUBECTL_PAGER=cat

COMPONENT="init-cp"
NODE_NAME="$CP_PREFIX-1"
CP_IP=$(multipass exec "$NODE_NAME" -- hostname -I | awk '{print $1}')
POD_CIDR="$POD_CIDR"

KUBECONFIG="/etc/kubernetes/admin.conf"

is_installed() {
  kubectl get pods -n kube-system \
    | grep kube-apiserver | grep -q Running
}

install() {
  echo "[$COMPONENT] initializing Kubernetes control-plane"

  [[ -n "$CP_IP" ]] || { echo "❌ CP_IP is not set"; exit 1; }

  sudo kubeadm init \
    --apiserver-advertise-address="$CP_IP" \
    --pod-network-cidr="$POD_CIDR" \
    --node-name "$NODE_NAME" \
    --ignore-preflight-errors=all
}

verify() {
  echo "[$COMPONENT] verifying control-plane"

  [[ -f "$KUBECONFIG" ]] || { echo "❌ $KUBECONFIG not found"; exit 1; }

  kubectl get pods -n kube-system \
    | grep kube-apiserver | grep -q Running \
    || { echo "❌ kube-apiserver not running"; exit 1; }

  local failed
  failed=$(kubectl get pods -n kube-system \
    --field-selector=status.phase!=Running,status.phase!=Succeeded \
    --no-headers | wc -l)
  [[ "$failed" -eq 0 ]] || { echo "❌ some kube-system pods are not healthy"; exit 1; }

  local ready
  ready=$(kubectl get nodes --no-headers | awk '{print $2}' | grep -c Ready)
  [[ "$ready" -ge 1 ]] || { echo "❌ control-plane node not Ready"; exit 1; }
}

main() {
  is_installed || install
#   verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
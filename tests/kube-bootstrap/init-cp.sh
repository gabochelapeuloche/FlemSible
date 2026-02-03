#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="init-control-plane"
CP_IP="${CP_IP:-}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
NODE_NAME="${NODE_NAME:-master}"

KUBECONFIG="/etc/kubernetes/admin.conf"

verify() {
  echo "[$COMPONENT] verifying control-plane"

  # kubeconfig existe
  [[ -f "$KUBECONFIG" ]] || { echo "❌ $KUBECONFIG not found"; exit 1; }

  # kube-apiserver running
  kubectl get pods -n kube-system \
    | grep kube-apiserver | grep -q Running \
    || { echo "❌ kube-apiserver not running"; exit 1; }

  # tous les pods kube-system running/completed
  local failed
  failed=$(kubectl get pods -n kube-system \
    --field-selector=status.phase!=Running,status.phase!=Succeeded \
    --no-headers | wc -l)
  [[ "$failed" -eq 0 ]] || { echo "❌ some kube-system pods are not healthy"; exit 1; }

  # noeud Ready
  local ready
  ready=$(kubectl get nodes --no-headers | awk '{print $2}' | grep -c Ready)
  [[ "$ready" -ge 1 ]] || { echo "❌ control-plane node not Ready"; exit 1; }
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
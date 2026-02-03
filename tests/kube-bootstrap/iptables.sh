#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="iptables-bridge"
MODULES_CONF="/etc/modules-load.d/k8s-netfilter.conf"
SYSCTL_CONF="/etc/sysctl.d/99-k8s-iptables.conf"

MODULES=(br_netfilter overlay)

SYSCTLS=(
  net.bridge.bridge-nf-call-iptables=1
  net.bridge.bridge-nf-call-ip6tables=1
)

is_installed() {
  for mod in "${MODULES[@]}"; do
    lsmod | grep -q "^$mod" || return 1
  done

  for kv in "${SYSCTLS[@]}"; do
    key="${kv%%=*}"
    val="${kv##*=}"
    [[ "$(sysctl -n "$key" 2>/dev/null)" == "$val" ]] || return 1
  done
}

verify() {
  is_installed || { echo "❌ netfilter / iptables bridge not configured"; exit 1; }
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
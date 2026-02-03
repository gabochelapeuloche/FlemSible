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

install() {
  echo "[network] configuring netfilter and iptables bridge"

  for mod in "${MODULES[@]}"; do
    if ! grep -qx "$mod" "$MODULES_CONF" 2>/dev/null; then
      echo "$mod" | sudo tee -a "$MODULES_CONF" >/dev/null
    fi
    sudo modprobe "$mod"
  done

  for kv in "${SYSCTLS[@]}"; do
    key="${kv%%=*}"
    val="${kv##*=}"
    if ! grep -Eq "^\s*$key\s*=" "$SYSCTL_CONF" 2>/dev/null; then
      echo "$key = $val" | sudo tee -a "$SYSCTL_CONF" >/dev/null
    fi
  done

  sudo sysctl --system >/dev/null
}

verify() {
  is_installed || { echo "❌ netfilter / iptables bridge not configured"; exit 1; }
}

main() {
  is_installed || install
  # verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
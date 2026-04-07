#!/usr/bin/env bash
# =============================================================================
# lib/virtual-infrastructure/injections/iptables.sh — Kernel netfilter setup.
#
# Loads br_netfilter and overlay kernel modules and configures sysctl so that
# iptables can see bridged traffic. Required by Kubernetes networking (Calico
# and the CNI bridge plugin both depend on this).
# Baked into the base image — skipped at provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: (none)
# =============================================================================
set -Eeuo pipefail

COMPONENT="iptables-bridge"
MODULES_CONF="/etc/modules-load.d/k8s-netfilter.conf"
SYSCTL_CONF="/etc/sysctl.d/99-k8s-iptables.conf"
MODULES=(br_netfilter overlay)
SYSCTLS=(
  net.bridge.bridge-nf-call-iptables=1
  net.bridge.bridge-nf-call-ip6tables=1
)

# is_applied
# Return 0 if all required modules are loaded and sysctl values are set.
is_applied() {
  for mod in "${MODULES[@]}"; do
    lsmod | grep -q "^$mod" || return 1
  done

  for kv in "${SYSCTLS[@]}"; do
    local key="${kv%%=*}" val="${kv##*=}"
    [[ "$(sysctl -n "$key" 2>/dev/null)" == "$val" ]] || return 1
  done
}

# apply
# Write module load config, load modules immediately, write sysctl config,
# and reload all sysctl settings.
apply() {
  echo "[network] configuring netfilter and iptables bridge"

  for mod in "${MODULES[@]}"; do
    if ! grep -qx "$mod" "$MODULES_CONF" 2>/dev/null; then
      echo "$mod" | sudo tee -a "$MODULES_CONF" >/dev/null
    fi
    sudo modprobe "$mod"
  done

  for kv in "${SYSCTLS[@]}"; do
    local key="${kv%%=*}" val="${kv##*=}"
    if ! grep -Eq "^\s*$key\s*=" "$SYSCTL_CONF" 2>/dev/null; then
      echo "$key = $val" | sudo tee -a "$SYSCTL_CONF" >/dev/null
    fi
  done

  sudo sysctl --system >/dev/null
}

main() {
  is_applied || apply
  echo "[$COMPONENT] applied"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

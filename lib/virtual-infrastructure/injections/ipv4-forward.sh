#!/usr/bin/env bash
# =============================================================================
# lib/virtual-infrastructure/injections/ipv4-forward.sh — Enable IPv4 forwarding.
#
# Required by Kubernetes so that pod traffic can be routed between nodes.
# Writes a persistent sysctl config file and applies it immediately.
# Baked into the base image — skipped at provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: (none)
# =============================================================================
set -Eeuo pipefail

COMPONENT="ipv4-forwarding"
SYSCTL_CONF="/etc/sysctl.d/99-ipv4-forwarding.conf"

# is_applied
# Return 0 if IPv4 forwarding is already enabled, 1 otherwise.
is_applied() {
  [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]
}

# apply
# Write the sysctl config file and activate forwarding immediately.
apply() {
  echo "[network] enabling IPv4 forwarding"

  if ! grep -Eq '^net.ipv4.ip_forward\s*=\s*1' "$SYSCTL_CONF" 2>/dev/null; then
    echo "net.ipv4.ip_forward = 1" | sudo tee "$SYSCTL_CONF" >/dev/null
  fi

  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

main() {
  is_applied || apply
  echo "[$COMPONENT] applied"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

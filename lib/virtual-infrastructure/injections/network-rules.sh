#!/usr/bin/env bash
# =============================================================================
# lib/virtual-infrastructure/injections/network-rules.sh — UFW firewall setup.
#
# Configures UFW on a node with role-specific port rules. Called once per VM
# during configure_vm with NODE_PORTS_ARRAY and CNI_PORTS_ARRAY injected as
# JSON arrays by the host. Runs on every node but with different port lists
# depending on whether the node is a control-plane or worker.
#
# Runs on:  all nodes (with different injected port lists per role)
# Injected: NODE_PORTS_ARRAY (JSON array), CNI_PORTS_ARRAY (JSON array)
# =============================================================================
set -Eeuo pipefail

NODE_PORTS_RAW="${NODE_PORTS_ARRAY:-[]}"
CNI_PORTS_RAW="${CNI_PORTS_ARRAY:-[]}"

# apply
# Reset UFW, set default policies, open DNS, then allow all ports declared
# in the injected NODE_PORTS_ARRAY and CNI_PORTS_ARRAY.
apply() {
  sudo apt-get update >/dev/null
  sudo apt-get install -y ufw jq >/dev/null

  sudo ufw --force reset >/dev/null
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  # DNS is required for image pulls and package downloads
  sudo ufw allow 53/udp >/dev/null
  sudo ufw allow 53/tcp >/dev/null

  local NODE_PORTS_LIST CNI_PORTS_LIST
  NODE_PORTS_LIST=$(echo "$NODE_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")
  CNI_PORTS_LIST=$(echo "$CNI_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")

  for port in $NODE_PORTS_LIST $CNI_PORTS_LIST; do
    [[ -n "$port" ]] && sudo ufw allow "$port" >/dev/null
  done

  sudo ufw --force enable >/dev/null
  echo "[firewall] configured: role ports open, outgoing allowed"
}

main() {
  apply
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

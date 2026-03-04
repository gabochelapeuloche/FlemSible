#!/usr/bin/env bash
set -Eeuo pipefail

# Récupération sécurisée
NODE_PORTS_RAW="${NODE_PORTS_ARRAY:-[]}"
CNI_PORTS_RAW="${CNI_PORTS_ARRAY:-[]}"

apply() {
  sudo apt-get update >/dev/null
  sudo apt-get install -y ufw jq >/dev/null

  # Conversion JSON
  local NODE_PORTS_LIST=$(echo "$NODE_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")
  local CNI_PORTS_LIST=$(echo "$CNI_PORTS_RAW" | jq -r '.[]' 2>/dev/null || echo "")

  sudo ufw --force reset >/dev/null
  sudo ufw default deny incoming
  sudo ufw default allow outgoing

  for port in $NODE_PORTS_LIST $CNI_PORTS_LIST; do
    if [[ -n "$port" ]]; then
      sudo ufw allow "$port" >/dev/null
    fi
  done

  sudo ufw --force enable >/dev/null
  echo "[firewall] configured with ports: ${NODE_PORTS_LIST//$'\n'/ }"
}

main() {
  apply
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
#!/usr/bin/env bash

: '
  Managing ipv4 forwarding for kubernetes
'
set -Eeuo pipefail

COMPONENT="ipv4-forwarding"
SYSCTL_CONF="/etc/sysctl.d/99-ipv4-forwarding.conf"

is_applied() {
  [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]
}

apply() {
  echo "[network] enabling IPv4 forwarding"

  if ! grep -Eq '^net.ipv4.ip_forward\s*=\s*1' "$SYSCTL_CONF" 2>/dev/null; then
    echo "net.ipv4.ip_forward = 1" | sudo tee "$SYSCTL_CONF" >/dev/null
  fi

  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

main() {
  is_applied || apply
  echo "[$COMPONENT] applied and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
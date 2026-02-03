#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="ipv4-forwarding"
SYSCTL_CONF="/etc/sysctl.d/99-ipv4-forwarding.conf"

is_installed() {
  [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]]
}

install() {
  echo "[network] enabling IPv4 forwarding"

  if ! grep -Eq '^net.ipv4.ip_forward\s*=\s*1' "$SYSCTL_CONF" 2>/dev/null; then
    echo "net.ipv4.ip_forward = 1" | sudo tee "$SYSCTL_CONF" >/dev/null
  fi

  sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
}

verify() {
  [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] \
    || { echo "❌ IPv4 forwarding is disabled"; exit 1; }
}

main() {
  is_installed || install
  # verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
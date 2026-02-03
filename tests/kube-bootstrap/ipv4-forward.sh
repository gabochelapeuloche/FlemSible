#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="ipv4-forwarding"
SYSCTL_CONF="/etc/sysctl.d/99-ipv4-forwarding.conf"

verify() {
  [[ "$(sysctl -n net.ipv4.ip_forward)" == "1" ]] \
    || { echo "❌ IPv4 forwarding is disabled"; exit 1; }
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
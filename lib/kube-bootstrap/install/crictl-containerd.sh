#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="crictl"
RUNTIME_ENDPOINT="unix:///var/run/containerd/containerd.sock"
CONFIG_FILE="/etc/crictl.yaml"

is_installed() {
  command -v crictl >/dev/null 2>&1
}

is_configured() {
  [[ -f "$CONFIG_FILE" ]] &&
  grep -Eq "^runtime-endpoint:\s*$RUNTIME_ENDPOINT" "$CONFIG_FILE"
}

install() {
  echo "[$COMPONENT] configuring runtime endpoint"
  sudo crictl config runtime-endpoint "$RUNTIME_ENDPOINT"
}

main() {
  is_configured || install
  echo "[$COMPONENT] installed and configured"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
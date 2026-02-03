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

verify() {
  is_installed || { echo "crictl not installed"; exit 1; }

  is_configured || { echo "crictl misconfigured"; exit 1; }

  crictl info >/dev/null
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
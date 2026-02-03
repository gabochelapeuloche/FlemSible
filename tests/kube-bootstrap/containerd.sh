#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="containerd"
VERSION="1.7.14"

verify() {
  systemctl is-active --quiet containerd
  containerd --version | grep -q "$VERSION"
}

main() {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main
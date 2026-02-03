#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="swapoff"

verify () {
  if swapon --summary | grep -q .; then
    echo "❌ swap is still enabled"
    exit 1
  fi
}

main () {
  verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
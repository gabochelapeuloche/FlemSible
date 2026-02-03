#!/usr/bin/env bash
set -Eeuo pipefail

COMPONENT="swapoff"

is_applied () {
  swapon --summary | grep -q .
}

apply () {
  if swapon --summary | grep -q .; then
    sudo swapoff -a
  fi
  if grep -Eq '^[^#].*\sswap\s' /etc/fstab; then
    sudo sed -i.bak '/^[^#].*\sswap\s/s/^/#/' /etc/fstab
  fi
}

verify () {
  if swapon --summary | grep -q .; then
    echo "❌ swap is still enabled"
    exit 1
  fi
}

main () {
  is_applied || apply
  # verify
  echo "[$COMPONENT] OK"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"
#!/usr/bin/env bash
# =============================================================================
# lib/virtual-infrastructure/injections/disable-swap.sh — Disable swap.
#
# Kubernetes requires swap to be off on every node. Disables swap immediately
# and comments out any swap entries in /etc/fstab to survive reboots.
# Baked into the base image — skipped at provision time when BASE_IMAGE is set.
#
# Runs on:  all nodes
# Injected: (none)
# =============================================================================
set -Eeuo pipefail

COMPONENT="swapoff"

# is_applied
# Return 0 if swap is already fully disabled, 1 otherwise.
is_applied() {
  [[ -z "$(swapon --summary | grep /)" ]]
}

# apply
# Disable active swap and comment out swap entries in /etc/fstab.
apply() {
  if swapon --summary | grep -q .; then
    sudo swapoff -a
  fi
  if grep -Eq '^[^#].*\sswap\s' /etc/fstab; then
    sudo sed -i.bak '/^[^#].*\sswap\s/s/^/#/' /etc/fstab
  fi
}

main() {
  is_applied || apply
  echo "[$COMPONENT] applied"
}

[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"

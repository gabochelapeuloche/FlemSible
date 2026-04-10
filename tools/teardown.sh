#!/usr/bin/env bash
# =============================================================================
# tools/teardown.sh — Delete all cluster VMs for a given profile.
#
# Reads VM names and counts from versions.json via get_version_info and
# purges each VM. Safe to run on a partially-created cluster — VMs that
# don't exist are skipped without error.
#
# Usage:
#   bash tools/teardown.sh [--profile <key>]
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
require_cmd multipass

user_inputs "$@"
get_version_info "${PROFILE:-1.35_base}"

KUBECONFIG_FILE="$SCRIPT_DIR/../kubeconfig/k8s-cluster.conf"

echo "Profile: ${PROFILE:-1.35_base}"
echo "Deleting ${CP_NUMBER} control-plane VM(s) [${CP_PREFIX}] and ${W_NUMBER} worker VM(s) [${W_PREFIX}]"
echo ""

deleted=0
skipped=0

delete_vm() {
  local VM="$1"
  if multipass info "$VM" &>/dev/null; then
    printf "  %-20s " "$VM"
    multipass delete "$VM" --purge
    echo -e "\e[32m[deleted]\e[0m"
    deleted=$((deleted + 1))
  else
    printf "  %-20s \e[33m[not found, skipping]\e[0m\n" "$VM"
    skipped=$((skipped + 1))
  fi
}

for ((i=1; i<=CP_NUMBER; i++)); do delete_vm "${CP_PREFIX}-$i"; done
for ((i=1; i<=W_NUMBER; i++)); do delete_vm "${W_PREFIX}-$i"; done

if [[ -f "$KUBECONFIG_FILE" ]]; then
  rm -f "$KUBECONFIG_FILE"
  echo ""
  echo "Removed kubeconfig: $KUBECONFIG_FILE"
fi

echo ""
echo "Done — ${deleted} VM(s) deleted, ${skipped} skipped."

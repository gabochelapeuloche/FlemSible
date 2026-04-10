#!/usr/bin/env bash
# =============================================================================
# tools/teardown.sh — Delete all VMs belonging to a cluster.
#
# Reads the cluster-name from versions.json and deletes every Multipass VM
# whose name starts with that prefix. No count needed — handles partial
# clusters (e.g. after a failed run) automatically.
#
# Usage:
#   bash tools/teardown.sh [--profile <key>]
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/utils.sh"
require_cmd multipass
require_cmd jq

user_inputs "$@"
get_version_info "${PROFILE:-1.35_base}"

KUBECONFIG_FILE="$SCRIPT_DIR/kubeconfig/k8s-cluster.conf"

# Find all VMs belonging to this cluster by prefix
VMS_TO_DELETE=$(multipass list --format json 2>/dev/null \
  | jq -r --arg p "${CLUSTER_NAME}-" '.list[].name | select(startswith($p))')

echo "Cluster: ${CLUSTER_NAME}  (prefix: ${CLUSTER_NAME}-)"
echo ""

if [[ -z "$VMS_TO_DELETE" ]]; then
  echo "No VMs found for cluster '${CLUSTER_NAME}' — nothing to do."
else
  deleted=0
  while IFS= read -r VM; do
    printf "  %-25s " "$VM"
    if multipass delete "$VM" --purge; then
      echo -e "\e[32m[deleted]\e[0m"
      deleted=$((deleted + 1))
    else
      echo -e "\e[31m[failed]\e[0m"
    fi
  done <<< "$VMS_TO_DELETE"
  echo ""
  echo "${deleted} VM(s) deleted."
fi

if [[ -f "$KUBECONFIG_FILE" ]]; then
  rm -f "$KUBECONFIG_FILE"
  echo "Removed kubeconfig: $KUBECONFIG_FILE"
fi

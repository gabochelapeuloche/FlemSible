#!/usr/bin/env bash
# =============================================================================
# tools/check-cluster.sh — Smoke test: verify cluster health after install.
#
# Checks node readiness, system pod health, and each enabled service namespace.
# Reads the profile from versions.json to know which services to check.
#
# Usage:
#   bash tools/check-cluster.sh [--profile <key>]
# =============================================================================
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/../lib/utils.sh"
require_cmd kubectl

user_inputs "$@"
get_version_info "${PROFILE:-1.35_base}"

KUBECONFIG="${KUBECONFIG:-$SCRIPT_DIR/../kubeconfig/k8s-cluster.conf}"
export KUBECONFIG

[[ -f "$KUBECONFIG" ]] || die "Kubeconfig not found: $KUBECONFIG — run main.sh first"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

PASS=0
FAIL=0

check_ok()   { printf "  %-50s \e[32m[OK]\e[0m\n"   "$1"; PASS=$((PASS + 1)); }
check_fail() { printf "  %-50s \e[31m[FAIL]\e[0m\n" "$1"; FAIL=$((FAIL + 1)); }

# namespace_healthy [namespace]
# Returns 0 if every pod in the namespace is Running/Completed/Succeeded
# and there is at least one pod.
namespace_healthy() {
  local ns="$1"
  local statuses bad
  statuses=$(kubectl get pods -n "$ns" --no-headers 2>/dev/null | awk '{print $3}')
  [[ -z "$statuses" ]] && return 1
  bad=$(echo "$statuses" | grep -vE "^(Running|Completed|Succeeded)$" || true)
  [[ -z "$bad" ]]
}

# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------

section "Connectivity"

if kubectl cluster-info &>/dev/null; then
  check_ok "API server reachable"
else
  check_fail "API server reachable"
  echo ""
  echo "Cannot reach the API server — aborting remaining checks."
  echo "Total: 1 failed, 0 passed"
  exit 1
fi

section "Nodes"

EXPECTED_NODES=$(( CP_NUMBER + W_NUMBER ))
READY_NODES=$(kubectl get nodes --no-headers 2>/dev/null | awk '$2=="Ready"' | wc -l)

if [[ "$READY_NODES" -eq "$EXPECTED_NODES" ]]; then
  check_ok "All ${EXPECTED_NODES} nodes Ready"
else
  check_fail "Nodes Ready (${READY_NODES}/${EXPECTED_NODES})"
fi

# Worker role labels
LABELED=$(kubectl get nodes --no-headers 2>/dev/null | grep -v "control-plane" | awk '{print $3}' | grep -c "worker" || true)
EXPECTED_WORKERS=$W_NUMBER
if [[ "$W_NUMBER" -eq 0 || "$LABELED" -eq "$EXPECTED_WORKERS" ]]; then
  check_ok "Worker role labels set"
else
  check_fail "Worker role labels (${LABELED}/${EXPECTED_WORKERS} labeled)"
fi

section "System pods"

if namespace_healthy "kube-system"; then
  check_ok "kube-system"
else
  check_fail "kube-system"
fi

if namespace_healthy "calico-system"; then
  check_ok "calico-system"
else
  check_fail "calico-system"
fi

if namespace_healthy "tigera-operator"; then
  check_ok "tigera-operator"
else
  check_fail "tigera-operator"
fi

section "Services"

if [[ "$TOOL_HELM" == "true" ]]; then
  if kubectl -n default get pods &>/dev/null && \
     multipass exec "${CP_PREFIX}-1" -- helm version &>/dev/null 2>&1; then
    check_ok "Helm CLI"
  else
    check_fail "Helm CLI"
  fi
fi

if [[ "$TOOL_HARBOR" == "true" ]]; then
  if namespace_healthy "$HARBOR_NAMESPACE"; then
    check_ok "Harbor ($HARBOR_NAMESPACE)"
  else
    check_fail "Harbor ($HARBOR_NAMESPACE)"
  fi
fi

if [[ "$TOOL_PROMETHEUS" == "true" ]]; then
  if namespace_healthy "$PROMETHEUS_NAMESPACE"; then
    check_ok "Prometheus ($PROMETHEUS_NAMESPACE)"
  else
    check_fail "Prometheus ($PROMETHEUS_NAMESPACE)"
  fi
fi

if [[ "$TOOL_ARGOCD" == "true" ]]; then
  if namespace_healthy "$ARGOCD_NAMESPACE"; then
    check_ok "ArgoCD ($ARGOCD_NAMESPACE)"
  else
    check_fail "ArgoCD ($ARGOCD_NAMESPACE)"
  fi
fi

if [[ "$TOOL_ISTIO" == "true" ]]; then
  if namespace_healthy "$ISTIO_NAMESPACE"; then
    check_ok "Istio ($ISTIO_NAMESPACE)"
  else
    check_fail "Istio ($ISTIO_NAMESPACE)"
  fi
fi

if [[ "$TOOL_ENVOY" == "true" ]]; then
  if namespace_healthy "$ENVOY_NAMESPACE"; then
    check_ok "Envoy Gateway ($ENVOY_NAMESPACE)"
  else
    check_fail "Envoy Gateway ($ENVOY_NAMESPACE)"
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

print_total_time
echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "\e[32mAll ${PASS} checks passed.\e[0m"
else
  echo -e "\e[31m${FAIL} check(s) failed, ${PASS} passed.\e[0m"
  exit 1
fi

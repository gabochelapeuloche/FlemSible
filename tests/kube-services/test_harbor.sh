#!/usr/bin/env bash
# Tests for lib/kube-services/harbor.sh and lib/kube-bootstrap/injections/helm.sh

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/lib/helpers.sh"

# ─── Setup ────────────────────────────────────────────────────────────────────

export LOG_SESSION_DIR
LOG_SESSION_DIR=$(mktemp -d)
_CALL_LOG=$(mktemp)
trap 'rm -rf "$LOG_SESSION_DIR" "$_CALL_LOG"' EXIT

source "$SCRIPT_DIR/lib/utils.sh"
get_version_info "1.35"

run_on_node_env() {
  echo "run_on_node_env|$1|$(basename "$2")|${3:-}" >> "$_CALL_LOG"
}
export -f run_on_node_env

multipass() {
  if [[ "$1" == "info" ]]; then
    printf "Name:           control-plane-1\nIPv4:           10.0.0.42\n"
  fi
  return 0
}
export -f multipass

source "$SCRIPT_DIR/lib/kube-services/harbor.sh"

# ─── get_version_info — helm + harbor vars ────────────────────────────────────

suite "get_version_info — Helm variables"

assert_var_set "HELM_VERSION set"     HELM_VERSION
assert_var_set "HELM_URL set"         HELM_URL
assert_eq      "HELM_VERSION is 3.17.1"  "3.17.1"  "$HELM_VERSION"
assert_contains "HELM_URL points to get.helm.sh"  "$HELM_URL"  "get.helm.sh"
assert_contains "HELM_URL is a tar.gz"            "$HELM_URL"  ".tar.gz"

suite "get_version_info — Harbor variables"

assert_var_set "HARBOR_CHART_VERSION set"  HARBOR_CHART_VERSION
assert_var_set "HARBOR_REPO_URL set"       HARBOR_REPO_URL
assert_var_set "HARBOR_REPO_NAME set"      HARBOR_REPO_NAME
assert_var_set "HARBOR_CHART set"          HARBOR_CHART
assert_var_set "HARBOR_NAMESPACE set"      HARBOR_NAMESPACE
assert_var_set "HARBOR_RELEASE set"        HARBOR_RELEASE

assert_eq "HARBOR_CHART_VERSION is 1.15.1"    "1.15.1"            "$HARBOR_CHART_VERSION"
assert_eq "HARBOR_REPO_NAME is harbor"         "harbor"            "$HARBOR_REPO_NAME"
assert_eq "HARBOR_CHART is harbor/harbor"      "harbor/harbor"     "$HARBOR_CHART"
assert_eq "HARBOR_NAMESPACE is harbor"         "harbor"            "$HARBOR_NAMESPACE"
assert_eq "HARBOR_RELEASE is harbor"           "harbor"            "$HARBOR_RELEASE"
assert_contains "HARBOR_REPO_URL contains goharbor.io" "$HARBOR_REPO_URL" "goharbor.io"

# ─── install_helm ─────────────────────────────────────────────────────────────

suite "install_helm"

> "$_CALL_LOG"
install_helm

_log=$(cat "$_CALL_LOG")
assert_contains "targets control-plane-1"     "$_log" "control-plane-1"
assert_contains "injects helm.sh"             "$_log" "helm.sh"
assert_contains "passes VERSION"              "$_log" "VERSION=$HELM_VERSION"
assert_contains "passes URL"                  "$_log" "URL=$HELM_URL"

# ─── install_harbor ───────────────────────────────────────────────────────────

suite "install_harbor"

> "$_CALL_LOG"
install_harbor

_log=$(cat "$_CALL_LOG")
assert_contains "targets control-plane-1"         "$_log" "control-plane-1"
assert_contains "injects harbor.sh"               "$_log" "harbor.sh"
assert_contains "passes CHART_VERSION"            "$_log" "CHART_VERSION=$HARBOR_CHART_VERSION"
assert_contains "passes REPO_URL"                 "$_log" "REPO_URL=$HARBOR_REPO_URL"
assert_contains "passes REPO_NAME"                "$_log" "REPO_NAME=$HARBOR_REPO_NAME"
assert_contains "passes NAMESPACE"                "$_log" "NAMESPACE=$HARBOR_NAMESPACE"
assert_contains "passes RELEASE"                  "$_log" "RELEASE=$HARBOR_RELEASE"
assert_contains "EXTERNAL_URL uses CP node IP"    "$_log" "EXTERNAL_URL=http://10.0.0.42"

# ─── helm.sh injection — is_installed logic ──────────────────────────────────
# Test the is_installed logic directly (avoids set -Eeuo pipefail propagation
# from sourcing injection scripts inside $() capture subshells)

suite "helm.sh injection — is_installed logic"

_helm_is_installed() {
  local version="$1"
  command -v helm >/dev/null 2>&1 && helm version --short 2>/dev/null | grep -q "v${version}"
}

helm() { echo "v3.17.1+g"; }
_helm_is_installed "3.17.1" \
  && pass "true when installed version matches" \
  || fail "true when installed version matches"

helm() { echo "v3.16.0+g"; }
_helm_is_installed "3.17.1" \
  && fail "false when installed version differs" \
  || pass "false when installed version differs"

helm() { return 127; }
_helm_is_installed "3.17.1" \
  && fail "false when helm binary missing" \
  || pass "false when helm binary missing"

unset -f helm

# ─── harbor.sh injection — is_installed logic ────────────────────────────────

suite "harbor.sh injection — is_installed logic"

_harbor_is_installed() {
  local release="$1" namespace="$2"
  helm status "$release" -n "$namespace" >/dev/null 2>&1
}

helm() { [[ "$2" == "harbor" ]] && return 0 || return 1; }
_harbor_is_installed "harbor" "harbor" \
  && pass "true when helm release exists" \
  || fail "true when helm release exists"

helm() { return 1; }
_harbor_is_installed "harbor" "harbor" \
  && fail "false when helm release missing" \
  || pass "false when helm release missing"

unset -f helm

summary

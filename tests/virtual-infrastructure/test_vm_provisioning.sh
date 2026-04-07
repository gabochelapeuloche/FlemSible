#!/usr/bin/env bash
# Tests for lib/virtual-infrastructure/vm-provisionning.sh

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/lib/helpers.sh"

# ─── Setup ────────────────────────────────────────────────────────────────────

export LOG_SESSION_DIR
LOG_SESSION_DIR=$(mktemp -d)
_CALL_LOG=$(mktemp)
trap 'rm -rf "$LOG_SESSION_DIR" "$_CALL_LOG"' EXIT

# Source utils first (defines run_on_node*), then override with mocks
source "$SCRIPT_DIR/lib/utils.sh"
get_version_info "1.35"

# Mock run_on_node and run_on_node_env — record calls to shared log file
# (log file is needed so calls from & subprocesses are captured)
run_on_node() {
  echo "run_on_node|$1|$2" >> "$_CALL_LOG"
}
run_on_node_env() {
  echo "run_on_node_env|$1|$2|${3:-}" >> "$_CALL_LOG"
}
export -f run_on_node run_on_node_env

# Mock multipass
multipass() {
  case "$1" in
    info)   return 1 ;;   # VM doesn't exist yet
    launch) echo "launch|$*" >> "$_CALL_LOG"; return 0 ;;
    *)      return 0 ;;
  esac
}
export -f multipass

source "$SCRIPT_DIR/lib/virtual-infrastructure/vm-provisionning.sh"

# ─── configure_vm — control-plane routing ─────────────────────────────────────

suite "configure_vm — control-plane node"

> "$_CALL_LOG"
configure_vm "control-plane-1"

_log=$(cat "$_CALL_LOG")
assert_contains "runs network-rules on CP node"   "$_log" "network-rules.sh"
assert_contains "passes CP open ports"            "$_log" "$CP_OPEN_PORTS"
assert_contains "passes Calico ports"             "$_log" "$CALICO_OPEN_PORTS"
assert_contains "runs disable-swap"               "$_log" "disable-swap.sh"
assert_contains "runs ipv4-forward"               "$_log" "ipv4-forward.sh"
assert_contains "runs iptables"                   "$_log" "iptables.sh"

suite "configure_vm — worker node"

> "$_CALL_LOG"
configure_vm "worker-1"

_log=$(cat "$_CALL_LOG")
assert_contains "runs network-rules on worker"    "$_log" "network-rules.sh"
assert_contains "passes worker open ports"        "$_log" "$W_OPEN_PORTS"
assert_contains "runs disable-swap"               "$_log" "disable-swap.sh"
assert_contains "runs ipv4-forward"               "$_log" "ipv4-forward.sh"
assert_contains "runs iptables"                   "$_log" "iptables.sh"

suite "configure_vm — CP and Worker use different ports"

_cp_ports=$(grep "control-plane-1" "$_CALL_LOG" | grep "network-rules" || true)
# CP and worker ports differ — verify they don't share the same port string
[[ "$CP_OPEN_PORTS" != "$W_OPEN_PORTS" ]] \
  && pass "CP and worker port configs are distinct" \
  || fail "CP and worker port configs are distinct" "ports are identical — check versions.json"

# ─── create_vms — VMS array population ────────────────────────────────────────

suite "create_vms — VMS array"

# Mock configure_vm to avoid running scripts
configure_vm() { echo "configure_vm|$1" >> "$_CALL_LOG"; }
export -f configure_vm

> "$_CALL_LOG"
VMS=()
create_vms

_expected_total=$(( CP_NUMBER + W_NUMBER ))
assert_eq "VMS array has correct length" \
  "$_expected_total" "${#VMS[@]}"

suite "create_vms — multipass launch calls"

_launches=$(grep "^launch|" "$_CALL_LOG" | wc -l | tr -d ' ')
assert_eq "multipass launch called for each VM" \
  "$_expected_total" "$_launches"

suite "create_vms — configure_vm called for each VM"

_configure_calls=$(grep "^configure_vm|" "$_CALL_LOG" | wc -l | tr -d ' ')
assert_eq "configure_vm called for each VM" \
  "$_expected_total" "$_configure_calls"

suite "create_vms — VM names follow prefix-N pattern"

for vm in "${VMS[@]}"; do
  assert_true "VM '$vm' matches prefix-N pattern" \
    "[[ '$vm' =~ ^(control-plane|worker)-[0-9]+$ ]]"
done

summary

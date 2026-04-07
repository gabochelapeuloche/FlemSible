#!/usr/bin/env bash
# Tests for lib/kube-bootstrap/node-bootstrap.sh

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

# Mock run_on_node_env — records script basename + node to shared log file
run_on_node_env() {
  local node="$1" script="$2"
  echo "$(basename "$script")|$node" >> "$_CALL_LOG"
}
export -f run_on_node_env

# Mock multipass
multipass() {
  case "$1" in
    exec)
      # Simulate kubeadm token create returning a join command
      if [[ "$*" == *"print-join-command"* ]]; then
        echo "kubeadm join 10.0.0.1:6443 --token abc.123 --discovery-token-ca-cert-hash sha256:abc"
      fi
      ;;
    info)
      # Return fake IP for hostname -I simulation
      echo "IPv4: 10.0.0.1"
      ;;
  esac
  return 0
}
export -f multipass

source "$SCRIPT_DIR/lib/kube-bootstrap/node-bootstrap.sh"

# ─── prepare_node — all component scripts injected ────────────────────────────

suite "prepare_node — component scripts"

> "$_CALL_LOG"
prepare_node "control-plane-1"

_log=$(cat "$_CALL_LOG")
assert_contains "containerd.sh injected"           "$_log" "containerd.sh"
assert_contains "runc.sh injected"                 "$_log" "runc.sh"
assert_contains "cni.sh injected"                  "$_log" "cni.sh"
assert_contains "kube.sh injected"                 "$_log" "kube.sh"
assert_contains "crictl-containerd.sh injected"    "$_log" "crictl-containerd.sh"

suite "prepare_node — all scripts target the correct node"

while IFS='|' read -r script node; do
  assert_eq "$script targets correct node" "control-plane-1" "$node"
done < "$_CALL_LOG"

suite "prepare_node — crictl runs after parallel batch"

# crictl-containerd.sh must appear after containerd/runc/cni/kube in log
_crictl_line=$(grep -n "crictl-containerd.sh" "$_CALL_LOG" | cut -d: -f1)
_kube_line=$(grep -n "kube.sh"               "$_CALL_LOG" | cut -d: -f1)

if [[ -n "$_crictl_line" && -n "$_kube_line" ]]; then
  [[ "$_crictl_line" -gt "$_kube_line" ]] \
    && pass "crictl-containerd.sh runs after kube.sh" \
    || fail "crictl-containerd.sh runs after kube.sh" \
            "crictl at line $_crictl_line, kube at line $_kube_line"
else
  fail "crictl-containerd.sh runs after kube.sh" "one of the scripts not found in log"
fi

suite "prepare_node — worker node"

> "$_CALL_LOG"
prepare_node "worker-1"

_log=$(cat "$_CALL_LOG")
assert_contains "containerd.sh injected on worker" "$_log" "containerd.sh"
assert_contains "kube.sh injected on worker"       "$_log" "kube.sh"

# ─── join_workers — skips control-plane, joins workers ────────────────────────

suite "join_workers"

VMS=("control-plane-1" "worker-1" "worker-2")
CP_PREFIX="control-plane"

_EXEC_LOG=$(mktemp)
multipass() {
  case "$1" in
    exec)
      shift        # drop "exec"
      local node="$1"
      shift        # drop node name
      shift        # drop "--"
      echo "exec|$node|$*" >> "$_EXEC_LOG"
      if [[ "$*" == *"print-join-command"* ]]; then
        echo "kubeadm join 10.0.0.1:6443 --token abc --discovery-token-ca-cert-hash sha256:abc"
      fi
      ;;
  esac
  return 0
}
export -f multipass

join_workers

_exec_log=$(cat "$_EXEC_LOG")
assert_contains  "worker-1 joins cluster"         "$_exec_log" "exec|worker-1"
assert_contains  "worker-2 joins cluster"         "$_exec_log" "exec|worker-2"
assert_false     "control-plane does not re-join" \
  "grep -q 'exec|control-plane-1|sudo bash' '$_EXEC_LOG'"

rm -f "$_EXEC_LOG"

summary

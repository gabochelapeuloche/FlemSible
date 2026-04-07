#!/usr/bin/env bash
# Tests for lib/utils.sh — input validation, config parsing, node runners

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$TESTS_DIR/.." && pwd)"
source "$TESTS_DIR/lib/helpers.sh"

# Disable die's exit so we can test it in subshells cleanly
source "$SCRIPT_DIR/lib/utils.sh"

# ─── Setup ────────────────────────────────────────────────────────────────────

export LOG_SESSION_DIR
LOG_SESSION_DIR=$(mktemp -d)
trap 'rm -rf "$LOG_SESSION_DIR"' EXIT

# ─── is_number ────────────────────────────────────────────────────────────────

suite "is_number"

assert_true  "accepts 0"         "is_number 0"
assert_true  "accepts 1"         "is_number 1"
assert_true  "accepts 42"        "is_number 42"
assert_false "rejects letters"   "is_number abc"
assert_false "rejects mixed"     "is_number 12a"
assert_false "rejects negative"  "is_number -1"
assert_false "rejects empty"     "is_number ''"
assert_false "rejects float"     "is_number 1.5"

# ─── is_storage ───────────────────────────────────────────────────────────────

suite "is_storage"

assert_true  "accepts 10G"       "is_storage 10G"
assert_true  "accepts 512M"      "is_storage 512M"
assert_true  "accepts 1G"        "is_storage 1G"
assert_false "rejects bare int"  "is_storage 10"
assert_false "rejects wrong unit" "is_storage 10K"
assert_false "rejects letters"   "is_storage GG"
assert_false "rejects empty"     "is_storage ''"

# ─── validate_config ──────────────────────────────────────────────────────────

suite "validate_config"

_run_validate() {
  local cp="$1" w="$2"
  ( CP_NUMBER="$cp"; W_NUMBER="$w"; validate_config ) 2>/dev/null
}

assert_succeeds "passes with CP=1 W=0"   _run_validate 1 0
assert_succeeds "passes with CP=1 W=3"   _run_validate 1 3
assert_fails    "fails with CP=0"        _run_validate 0 1
assert_fails    "fails with CP=-1"       _run_validate -1 1

# ─── get_version_info ─────────────────────────────────────────────────────────

suite "get_version_info — variable population"

get_version_info "1.35"

assert_var_set "CP_PREFIX set"              CP_PREFIX
assert_var_set "CP_NUMBER set"              CP_NUMBER
assert_var_set "CP_OS_VERSION set"          CP_OS_VERSION
assert_var_set "CP_CPUS set"               CP_CPUS
assert_var_set "CP_MEMORY set"             CP_MEMORY
assert_var_set "CP_DISK set"               CP_DISK
assert_var_set "CP_POD_CIDR set"           CP_POD_CIDR
assert_var_set "W_PREFIX set"              W_PREFIX
assert_var_set "W_NUMBER set"              W_NUMBER
assert_var_set "K8S_PATCH set"             K8S_PATCH
assert_var_set "K8S_REPO set"              K8S_REPO
assert_var_set "CONTAINERD_VERSION set"    CONTAINERD_VERSION
assert_var_set "CONTAINERD_URL set"        CONTAINERD_URL
assert_var_set "RUNC_VERSION set"          RUNC_VERSION
assert_var_set "RUNC_URL set"              RUNC_URL
assert_var_set "CNI_VERSION set"           CNI_VERSION
assert_var_set "CNI_URL set"               CNI_URL
assert_var_set "CALICO_VERSION set"        CALICO_VERSION
assert_var_set "CALICO_TIGERA_OPERATOR set" CALICO_TIGERA_OPERATOR
assert_var_set "CALICO_CRD_URL set"        CALICO_CRD_URL
assert_var_set "CALICO_OPEN_PORTS set"     CALICO_OPEN_PORTS

suite "get_version_info — correct values"

assert_eq "CP_PREFIX is 'control-plane'"  "control-plane"    "$CP_PREFIX"
assert_eq "W_PREFIX is 'worker'"          "worker"           "$W_PREFIX"
assert_eq "CP_NUMBER is 1"               "1"                "$CP_NUMBER"
assert_eq "W_NUMBER is 2"               "2"                "$W_NUMBER"
assert_eq "CNI is 'calico'"              "calico"           "$CNI"
assert_eq "CP_OS_VERSION is 'noble'"    "noble"            "$CP_OS_VERSION"
assert_contains "K8S_REPO contains k8s.io"  "$K8S_REPO"   "k8s.io"
assert_contains "CONTAINERD_URL is a tar.gz" "$CONTAINERD_URL" ".tar.gz"
assert_contains "RUNC_URL points to runc"   "$RUNC_URL"    "runc"

suite "get_version_info — fails on unknown version"

assert_fails "dies on unknown version" \
  bash -c "SCRIPT_DIR='$SCRIPT_DIR'; source '$SCRIPT_DIR/lib/utils.sh'; get_version_info '9.99'"

# ─── run_on_node (no chmod) ───────────────────────────────────────────────────

suite "run_on_node — multipass calls"

# Create a real temp script to transfer
_tmp_script=$(mktemp /tmp/test_script_XXXX.sh)
echo '#!/usr/bin/env bash' > "$_tmp_script"
trap 'rm -f "$_tmp_script"' EXIT

# Record every multipass subcommand
_CALL_LOG=$(mktemp)
multipass() {
  echo "$1" >> "$_CALL_LOG"
  return 0
}
export -f multipass

run_on_node "test-node" "$_tmp_script"

_calls=$(cat "$_CALL_LOG")
assert_contains  "calls 'transfer'"       "$_calls" "transfer"
assert_contains  "calls 'exec'"           "$_calls" "exec"
assert_false     "never calls 'chmod'"    "grep -q '^chmod$' '$_CALL_LOG'"
rm -f "$_CALL_LOG"

# ─── run_on_node_env — env vars forwarded ─────────────────────────────────────

suite "run_on_node_env — env vars forwarded to exec"

_EXEC_CMD_LOG=$(mktemp)
multipass() {
  if [[ "$1" == "exec" ]]; then
    # Capture the full command to check env injection
    echo "$*" >> "$_EXEC_CMD_LOG"
  fi
  return 0
}
export -f multipass

run_on_node_env "test-node" "$_tmp_script" "FOO=bar BAZ=qux"

_exec_line=$(cat "$_EXEC_CMD_LOG")
assert_contains "env vars appear in exec call" "$_exec_line" "FOO=bar"
rm -f "$_EXEC_CMD_LOG"

summary

#!/usr/bin/env bash
# Minimal test framework — no external dependencies

TESTS_PASS=0
TESTS_FAIL=0
_CURRENT_SUITE=""

suite() {
  _CURRENT_SUITE="$1"
  echo ""
  echo "--- $1 ---"
}

pass() {
  echo "  PASS  $1"
  ((TESTS_PASS++))
}

fail() {
  echo "  FAIL  $1"
  [[ -n "${2:-}" ]] && echo "        $2"
  ((TESTS_FAIL++))
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$desc"
  else
    fail "$desc" "expected='$expected'  got='$actual'"
  fi
}

assert_true() {
  local desc="$1"
  if eval "${2}"; then
    pass "$desc"
  else
    fail "$desc"
  fi
}

assert_false() {
  local desc="$1"
  if eval "${2}" 2>/dev/null; then
    fail "$desc" "(expected false, got true)"
  else
    pass "$desc"
  fi
}

# Run a command in a subshell; pass if it exits 0
assert_succeeds() {
  local desc="$1"; shift
  if ( "$@" ) 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc" "(command failed: $*)"
  fi
}

# Run a command in a subshell; pass if it exits non-zero
assert_fails() {
  local desc="$1"; shift
  if ( "$@" ) 2>/dev/null; then
    fail "$desc" "(expected failure, command succeeded: $*)"
  else
    pass "$desc"
  fi
}

assert_var_set() {
  local desc="$1" var="$2"
  if [[ -n "${!var:-}" ]]; then
    pass "$desc"
  else
    fail "$desc" "variable \$$var is empty or unset"
  fi
}

assert_contains() {
  local desc="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    pass "$desc"
  else
    fail "$desc" "'$needle' not found in output"
  fi
}

assert_file_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    pass "$desc"
  else
    fail "$desc" "'$needle' not found in $file"
  fi
}

assert_file_not_contains() {
  local desc="$1" file="$2" needle="$3"
  if grep -qF "$needle" "$file" 2>/dev/null; then
    fail "$desc" "'$needle' unexpectedly found in $file"
  else
    pass "$desc"
  fi
}

summary() {
  local total=$((TESTS_PASS + TESTS_FAIL))
  echo ""
  echo "======================================="
  echo "  $TESTS_PASS / $total tests passed"
  [[ $TESTS_FAIL -gt 0 ]] && echo "  $TESTS_FAIL FAILED"
  echo "======================================="
  [[ $TESTS_FAIL -eq 0 ]]
}

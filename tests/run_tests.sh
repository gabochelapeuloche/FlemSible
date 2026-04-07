#!/usr/bin/env bash
# Run all test suites and report overall result

set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SUITES=(
  "$TESTS_DIR/script-config/test_utils.sh"
  "$TESTS_DIR/virtual-infrastructure/test_vm_provisioning.sh"
  "$TESTS_DIR/kube-bootstrap/test_node_bootstrap.sh"
  "$TESTS_DIR/kube-services/test_harbor.sh"
)

TOTAL_PASS=0
TOTAL_FAIL=0

for suite in "${SUITES[@]}"; do
  name="$(basename "$(dirname "$suite")")/$(basename "$suite")"
  echo ""
  echo "======================================="
  echo "  Suite: $name"
  echo "======================================="

  output=$(bash "$suite" 2>&1)
  echo "$output"

  pass=$(echo "$output" | grep -c '  PASS ' || true)
  fail=$(echo "$output" | grep -c '  FAIL ' || true)
  TOTAL_PASS=$(( TOTAL_PASS + pass ))
  TOTAL_FAIL=$(( TOTAL_FAIL + fail ))
done

echo ""
echo "======================================="
echo "  TOTAL: $TOTAL_PASS passed, $TOTAL_FAIL failed"
echo "======================================="

[[ $TOTAL_FAIL -eq 0 ]]

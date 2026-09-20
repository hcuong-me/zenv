#!/usr/bin/env bash
# validate.sh — run all harness validation checks
# Exit 0 if all pass, exit 1 if any fail
set -euo pipefail

PASS=0
FAIL=0

run_check() {
  local name="$1"
  local cmd="$2"
  echo "Running: $name"
  if eval "$cmd"; then
    PASS=$((PASS + 1))
  else
    echo "  FAILED: $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== zenv Harness Validation ==="
echo ""

# Build checks
run_check "Go build" "go build ./..."
run_check "Go vet" "go vet ./..."

# Linter checks
run_check "lint (golangci-lint)" "golangci-lint run --timeout=5m ./..."
run_check "lint-arch (layer deps)" "bash scripts/lint-deps.sh"
run_check "lint-quality" "bash scripts/lint-quality.sh"
run_check "lint-md (markdown)" "bash scripts/lint-md.sh"

# Harness file checks
run_check "AGENTS.md size (80-120 lines)" "test \$(wc -l < AGENTS.md) -ge 80 && test \$(wc -l < AGENTS.md) -le 120"
run_check ".harness/config.yaml exists" "test -f .harness/config.yaml"
run_check ".harness/quality-gate.yml exists" "test -f .harness/quality-gate.yml"
run_check ".harness/constraints/ exists" "test -f .harness/constraints/architecture.yaml && test -f .harness/constraints/lint-rules.yaml && test -f .harness/constraints/test-policy.yaml"
run_check ".harness/scripts/ exists" "test -f .harness/scripts/work.sh && test -f .harness/scripts/entropy-scan.sh && test -f .harness/scripts/ralph-custom.sh && test -f .harness/scripts/ralph-worker.sh"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

[[ $FAIL -eq 0 ]] && exit 0 || exit 1

#!/usr/bin/env bash
# Verifica pack QA + DevSecOps AGL nos harnesses locais.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="${HOSTMAN_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

FAIL=0
pass() { echo "  OK   $1"; }
fail() { echo "  FAIL $1"; FAIL=$((FAIL + 1)); }

check_skill() {
  local label="$1" path="$2"
  if [[ -f "$path/SKILL.md" ]]; then
    pass "$label"
  else
    fail "$label ($path)"
  fi
}

echo "=== Verify AGL QA + DevSecOps Pack ==="
echo "hostman: $HOSTMAN_ROOT"
echo ""

echo "-- AGL-native (project) --"
for s in agl-testing-policy agl-stack-testing agl-devsecops agl-sast-gate agl-incident-response \
  agl-qa-regression code-review-and-quality security-and-hardening; do
  check_skill "$s" "$HOSTMAN_ROOT/.cursor/skills/$s"
done

echo ""
echo "-- ECC subset (project) --"
for s in tdd-workflow verification-loop e2e-testing ai-regression-testing production-audit skill-scout; do
  check_skill "$s" "$HOSTMAN_ROOT/.cursor/skills/$s"
done

echo ""
echo "-- Global cursor (opcional) --"
for s in agl-stack-testing agl-devsecops verification-loop review-security; do
  [[ -f "$HOME/.cursor/skills/$s/SKILL.md" ]] && pass "global:$s" || echo "  SKIP global:$s"
done

echo ""
echo "-- Regras --"
[[ -f "$HOSTMAN_ROOT/.cursor/rules/agl-testing-policy.mdc" ]] && pass "agl-testing-policy.mdc" \
  || fail "agl-testing-policy.mdc"

echo ""
echo "-- verification-loop AGL ref --"
[[ -f "$HOSTMAN_ROOT/.cursor/skills/verification-loop/references/AGL.md" ]] \
  && pass "verification-loop/references/AGL.md" || fail "AGL.md ref"

echo ""
echo "-- CI security-scan --"
[[ -f "$HOSTMAN_ROOT/.github/workflows/security-scan.yml" ]] && pass "security-scan.yml" \
  || fail "security-scan.yml"

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "RESULT: PASS"
else
  echo "RESULT: FAIL ($FAIL)"
fi
exit "$FAIL"

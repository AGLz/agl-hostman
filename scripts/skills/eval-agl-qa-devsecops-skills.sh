#!/usr/bin/env bash
# Eval harness — skills QA/DevSecOps AGL (Fase 4).
# Verifica que skills e scripts existem e que comandos de smoke não falham em dry-run.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
FAIL=0

assert_file() {
  local path="$1" label="$2"
  if [[ -f "$path" ]]; then
    echo "  PASS $label"
  else
    echo "  FAIL $label ($path)"
    FAIL=1
  fi
}

assert_skill_trigger() {
  local skill="$1" keyword="$2"
  local f="$HOSTMAN_ROOT/.cursor/skills/$skill/SKILL.md"
  if [[ -f "$f" ]] && grep -qi "$keyword" "$f"; then
    echo "  PASS trigger:$skill ($keyword)"
  else
    echo "  FAIL trigger:$skill missing $keyword"
    FAIL=1
  fi
}

echo "=== Eval AGL QA/DevSecOps Skills ==="

echo "-- capability: skills exist --"
for s in agl-stack-testing agl-devsecops agl-testing-policy agl-sast-gate agl-incident-response \
  agl-qa-regression code-review-and-quality security-and-hardening; do
  assert_file "$HOSTMAN_ROOT/.cursor/skills/$s/SKILL.md" "skill:$s"
done

echo "-- regression: description triggers --"
assert_skill_trigger agl-stack-testing "php artisan test"
assert_skill_trigger agl-devsecops "CT186"
assert_skill_trigger agl-sast-gate "composer audit"
assert_skill_trigger agl-testing-policy "strict-tdd"

echo "-- verify pack script --"
if bash "$SCRIPT_DIR/verify-agl-qa-devsecops-pack.sh" >/tmp/agl-qa-verify.out 2>&1; then
  echo "  PASS verify-agl-qa-devsecops-pack.sh"
else
  echo "  FAIL verify-agl-qa-devsecops-pack.sh"
  tail -5 /tmp/agl-qa-verify.out
  FAIL=1
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "EVAL: PASS (pass@1)"
  exit 0
fi
echo "EVAL: FAIL"
exit 1

#!/usr/bin/env bash
# Scan de segurança de skills (NVIDIA SkillSpector).
# Requer Python 3.12+ local OU Docker.
#
# Uso:
#   ./scripts/skills/scan-skill-security.sh .cursor/skills/improve
#   ./scripts/skills/scan-skill-security.sh https://github.com/user/skill-repo
#   SKILLSPECTOR_NO_LLM=1 ./scripts/skills/scan-skill-security.sh path
set -euo pipefail

TARGET="${1:-}"
FORMAT="${SKILLSPECTOR_FORMAT:-terminal}"
NO_LLM="${SKILLSPECTOR_NO_LLM:-1}"

if [[ -z "$TARGET" ]]; then
  echo "Uso: $(basename "$0") <path|url|SKILL.md>" >&2
  exit 2
fi

case "$FORMAT" in
  terminal|json|markdown|sarif) ;;
  *)
    echo "[ERROR] SKILLSPECTOR_FORMAT inválido: $FORMAT (terminal|json|markdown|sarif)" >&2
    exit 2
    ;;
esac

run_skillspector() {
  local cmd=("$@")
  if command -v skillspector >/dev/null 2>&1; then
    "${cmd[@]}"
    return
  fi
  if command -v python3.12 >/dev/null 2>&1; then
    python3.12 -m skillspector.cli.main "${cmd[@]:1}" && return
  fi
  if command -v docker >/dev/null 2>&1 && [[ -d "$TARGET" || -f "$TARGET" ]]; then
    local abs_target
    abs_target="$(cd "$(dirname "$TARGET")" && pwd)/$(basename "$TARGET")"
    docker run --rm \
      -e "SKILLSPECTOR_FORMAT=$FORMAT" \
      -v "${abs_target}:/scan:ro" \
      python:3.12-slim bash -lc '
        apt-get update -qq && apt-get install -y -qq git >/dev/null
        pip install -q "git+https://github.com/NVIDIA/skillspector.git"
        skillspector scan /scan --no-llm --format "${SKILLSPECTOR_FORMAT}"
      '
    return
  fi
  echo "[ERROR] SkillSpector indisponível: Python 3.12+ ou Docker com path local" >&2
  exit 1
}

args=(scan "$TARGET" --format "$FORMAT")
if [[ "$NO_LLM" == "1" ]]; then
  args+=(--no-llm)
fi

echo "[scan-skill-security] target=$TARGET format=$FORMAT no_llm=$NO_LLM"
run_skillspector skillspector "${args[@]}"

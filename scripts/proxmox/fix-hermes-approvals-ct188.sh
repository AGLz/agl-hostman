#!/usr/bin/env bash
# Aprovações Hermes CT188 — modos permissivos (Jarvis + quartet + curator).
#
# Hermes só reconhece approvals.mode: manual | smart | off
# (mode: auto é inválido e comporta-se como manual → bloqueia terminal no Telegram).
#
# Uso (root no CT188):
#   bash fix-hermes-approvals-ct188.sh
#   bash fix-hermes-approvals-ct188.sh --smart          # aux LLM aprova risco baixo
#   bash fix-hermes-approvals-ct188.sh --no-restart
#   HERMES_APPROVAL_MODE=smart bash fix-hermes-approvals-ct188.sh
#
# Variáveis:
#   HERMES_ROOT          default /opt/agl-hermes
#   HERMES_APPROVAL_MODE off (default) | smart

set -euo pipefail

APPROVAL_MODE="${HERMES_APPROVAL_MODE:-off}"
RESTART=1

for arg in "$@"; do
  case "${arg}" in
    --smart) APPROVAL_MODE="smart" ;;
    --off) APPROVAL_MODE="off" ;;
    --no-restart) RESTART=0 ;;
    -h|--help)
      sed -n '1,18p' "$0"
      exit 0
      ;;
  esac
done

if [[ "${APPROVAL_MODE}" != "off" && "${APPROVAL_MODE}" != "smart" ]]; then
  echo "ERRO: HERMES_APPROVAL_MODE deve ser off ou smart (recebido: ${APPROVAL_MODE})" >&2
  exit 1
fi

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATA="${HERMES_ROOT}/data"

CONFIGS=(
  "${DATA}/config.yaml"
  "${DATA}/profiles/elon/config.yaml"
  "${DATA}/profiles/satya/config.yaml"
  "${DATA}/profiles/werner/config.yaml"
  "${DATA}/profiles/curator/config.yaml"
  "${HERMES_ROOT}/profiles/curator/config.yaml"
)

echo "=== Hermes CT188 — approvals permissivos (mode=${APPROVAL_MODE}) ==="

python3 - "${APPROVAL_MODE}" "${CONFIGS[@]}" <<'PY'
import sys
from pathlib import Path
import yaml

mode = sys.argv[1]
paths = [Path(p) for p in sys.argv[2:]]

for path in paths:
    if not path.is_file():
        print(f"SKIP inexistente: {path}")
        continue
    cfg = yaml.safe_load(path.read_text()) or {}
    ap = cfg.setdefault("approvals", {})
    deleg = cfg.setdefault("delegation", {})

    # YAML 1.1: bare `off` → False; Hermes trata False como "off"
    ap["mode"] = mode
    ap["cron_mode"] = "approve"
    ap["timeout"] = max(int(ap.get("timeout") or 60), 300)
    ap["destructive_slash_confirm"] = False
    ap["mcp_reload_confirm"] = False

    deleg["subagent_auto_approve"] = True

    path.write_text(
        yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    print(f"OK {path.name} @ {path.parent.name if path.parent.name != 'data' else 'jarvis'}")
PY

if [[ "${RESTART}" -eq 1 ]]; then
  echo "=== Reiniciar gateways quartet ==="
  for c in agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner; do
    if docker ps -a --format '{{.Names}}' | grep -qx "${c}"; then
      docker restart "${c}" >/dev/null
      echo "OK restart ${c}"
    else
      echo "SKIP ${c} (não encontrado)"
    fi
  done
fi

echo ""
echo "Verificação:"
for f in "${CONFIGS[@]}"; do
  [[ -f "${f}" ]] || continue
  echo "--- ${f} ---"
  grep -A7 '^approvals:' "${f}" | head -8
  grep 'subagent_auto_approve' "${f}" || true
done

echo ""
echo "Concluído. mode=${APPROVAL_MODE} — enviar nova mensagem Telegram (/new se thread antiga)."

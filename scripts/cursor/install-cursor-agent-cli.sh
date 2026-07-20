#!/usr/bin/env bash
# Instala ou actualiza o Cursor Agent CLI (`agent`) via cursor.com/install.
#
# Uso:
#   bash scripts/cursor/install-cursor-agent-cli.sh
#   bash scripts/cursor/install-cursor-agent-cli.sh --dry-run
set -euo pipefail

DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help)
      sed -n '2,7p' "$0"
      exit 0
      ;;
    *) echo "Uso: $0 [--dry-run]" >&2; exit 2 ;;
  esac
done

AGENT_BIN="${HOME}/.local/bin/agent"

if [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] curl https://cursor.com/install -fsS | bash"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "[FAIL] curl em falta" >&2
  exit 1
fi

echo "[INFO] Instalar/atualizar Cursor Agent CLI..."
# ponytail: curl|bash — padrão oficial Cursor; sem checksum alternativo
bash -c 'curl https://cursor.com/install -fsS | bash'

if [[ ! -x "$AGENT_BIN" ]]; then
  echo "[FAIL] $AGENT_BIN não encontrado após install" >&2
  exit 1
fi

if ! "$AGENT_BIN" worker start --help >/dev/null 2>&1; then
  echo "[FAIL] CLI instalado mas sem 'agent worker start' — versão demasiado antiga" >&2
  exit 1
fi

echo "[OK] Cursor Agent CLI: $("$AGENT_BIN" --version 2>/dev/null || true)"

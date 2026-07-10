#!/usr/bin/env bash
# Instala ou actualiza o Cursor Agent CLI (`agent`) via cursor.com/install.
set -euo pipefail

DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) sed -n '2,5p' "$0"; exit 0 ;;
    *) echo "Uso: $0 [--dry-run]" >&2; exit 2 ;;
  esac
done

AGENT_BIN="${HOME}/.local/bin/agent"
[[ "$DRY_RUN" -eq 1 ]] && { echo "[dry-run] curl https://cursor.com/install | bash"; exit 0; }

command -v curl >/dev/null || { echo "[FAIL] curl em falta" >&2; exit 1; }
echo "[INFO] Instalar/atualizar Cursor Agent CLI..."
# ponytail: curl|bash — padrão oficial Cursor
bash -c 'curl https://cursor.com/install -fsS | bash'
[[ -x "$AGENT_BIN" ]] || { echo "[FAIL] $AGENT_BIN em falta" >&2; exit 1; }
"$AGENT_BIN" worker start --help >/dev/null 2>&1 || { echo "[FAIL] CLI sem worker start" >&2; exit 1; }
echo "[OK] Cursor Agent CLI: $("$AGENT_BIN" --version 2>/dev/null || true)"

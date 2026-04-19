#!/usr/bin/env bash
# Normaliza channels.telegram para OpenClaw ≥ 2026.3.x:
# - remove streamMode (legado v2026.2.x)
# - garante streaming ∈ true|false|"off"|"partial"|"block"|"progress" (senão → "partial")
#
# Uso: bash scripts/openclaw/fix-openclaw-telegram-streaming.sh [caminho/openclaw.json]
set -euo pipefail

CFG="${1:-$HOME/.openclaw/openclaw.json}"
if [[ ! -f "$CFG" ]]; then
  echo "Erro: ficheiro não encontrado: $CFG" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Erro: jq é necessário" >&2
  exit 1
fi

bak="${CFG}.bak.streaming-fix.$(date +%Y%m%d%H%M%S)"
cp -a "$CFG" "$bak"
echo "Backup: $bak"

jq '
  if (.channels | type) == "object" and (.channels.telegram | type) == "object" then
    .channels.telegram |= (
      del(.streamMode)
      | (.streaming as $s
        | .streaming = (
            if $s == true or $s == false then $s
            elif $s == "off" or $s == "partial" or $s == "block" or $s == "progress" then $s
            else "partial"
            end
          ))
    )
  else . end
' "$CFG" > "${CFG}.new"
mv "${CFG}.new" "$CFG"
echo "OK: $CFG — channels.telegram.streaming normalizado (tente: openclaw tui)"

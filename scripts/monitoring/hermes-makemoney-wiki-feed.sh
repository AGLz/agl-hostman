#!/usr/bin/env bash
# Alimenta llm-wiki via wiki-ingest a partir do pipeline makemoney01 (substitui cron LLM vazio).
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
DATE="$(date '+%Y-%m-%d')"
CURATOR_INGEST="${CURATOR_WIKI_INGEST:-${MAKEMONEY_DIR}/wiki-ingest}"

build_daily_summary() {
  local out="${MAKEMONEY_DIR}/wiki-ingest/${DATE}-makemoney-daily.md"
  local board="${MAKEMONEY_DIR}/data/pipeline/board.json"

  {
    echo "---"
    echo "title: makemoney01 Resumo Diário ${DATE}"
    echo "tags: [makemoney01, oportunidades, hermes]"
    echo "confidence: medium"
    echo "source: hermes-makemoney-wiki-feed"
    echo "date: ${DATE}"
    echo "---"
    echo ""
    echo "# makemoney01 — Resumo ${DATE}"
    echo ""
  } > "${out}"

  local research="${MAKEMONEY_DIR}/data/opportunities/${DATE}-research.json"
  if [[ -f "${research}" ]]; then
    echo "## Scan diário" >> "${out}"
    python3 -c "import json; print(json.load(open('${research}'))['content'])" >> "${out}" 2>/dev/null || true
    echo "" >> "${out}"
  fi

  local deep="${MAKEMONEY_DIR}/data/opportunities/${DATE}-deep-dive.json"
  if [[ -f "${deep}" ]]; then
    echo "## Deep dive" >> "${out}"
    python3 -c "import json; print(json.load(open('${deep}'))['content'])" >> "${out}" 2>/dev/null || true
    echo "" >> "${out}"
  fi

  if [[ -f "${board}" ]]; then
    echo "## Pipeline" >> "${out}"
    python3 - "${board}" <<'PY' >> "${out}"
import json, sys
b = json.load(open(sys.argv[1]))
for col in ("prospect", "qualify", "execute"):
    items = b.get("columns", {}).get(col, [])
    if items:
        print(f"### {col}")
        for i in items[:8]:
            print(f"- {i.get('title','?')} ({i.get('status','?')})")
        print()
if b.get("last_priority"):
    print(f"**Prioridade:** {b['last_priority']}")
PY
  fi

  echo "" >> "${out}"
  echo "Ver: [[makemoney01]]" >> "${out}"
  echo "OK wiki-ingest ${out}"
}

copy_to_curator() {
  local src="${MAKEMONEY_DIR}/wiki-ingest/${DATE}-makemoney-daily.md"
  [[ -f "${src}" ]] || return 0
  # wiki-ingest Hermes é symlink → makemoney01; Curator lê CURATOR_WIKI_INGEST ou /opt/data/wiki-ingest
  if [[ -d "${CURATOR_INGEST}" ]]; then
    echo "OK wiki-ingest canónico: ${CURATOR_INGEST}/$(basename "${src}")"
  fi
}

main() {
  [[ -d "${MAKEMONEY_DIR}" ]] || { echo "ERRO: ${MAKEMONEY_DIR}" >&2; exit 1; }
  mkdir -p "${MAKEMONEY_DIR}/wiki-ingest"
  build_daily_summary
  copy_to_curator

  # Resumo curto para stdout (Telegram se deliver activo)
  local n_prospect n_qualify
  n_prospect="$(python3 -c "import json; b=json.load(open('${MAKEMONEY_DIR}/data/pipeline/board.json')); print(len(b.get('columns',{}).get('prospect',[])))" 2>/dev/null || echo 0)"
  n_qualify="$(python3 -c "import json; b=json.load(open('${MAKEMONEY_DIR}/data/pipeline/board.json')); print(len(b.get('columns',{}).get('qualify',[])))" 2>/dev/null || echo 0)"
  echo "📚 makemoney01→wiki ${DATE}: prospect=${n_prospect} qualify=${n_qualify} ingest OK"
}

main "$@"

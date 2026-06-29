#!/usr/bin/env bash
# Deep dive com contexto do scan — chama LiteLLM e grava em makemoney01 + wiki-ingest.
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
DATE="$(date '+%Y-%m-%d')"
HERMES_ENV="${HERMES_ENV:-/opt/data/.env}"
LITELLM_URL="${LITELLM_URL:-}"
MODEL="${MAKEMONEY_LLM_MODEL:-agl-primary}"
MAX_CHARS="${MAKEMONEY_MAX_CHARS:-2500}"

load_api_key() {
  local key=""
  if [[ -f "${HERMES_ENV}" ]]; then
    # shellcheck disable=SC1090
    set -a
    source <(grep -E '^(LITELLM_API_KEY|OPENAI_API_KEY|API_KEY)=' "${HERMES_ENV}" 2>/dev/null || true)
    set +a
    key="${LITELLM_API_KEY:-${OPENAI_API_KEY:-${API_KEY:-}}}"
  fi
  if [[ -z "${key}" && -f /opt/data/config.yaml ]]; then
    key="$(python3 -c "import yaml; c=yaml.safe_load(open('/opt/data/config.yaml')); print((c.get('model') or {}).get('api_key',''))" 2>/dev/null || true)"
  fi
  echo "${key}"
}

read_research() {
  local f="${MAKEMONEY_DIR}/data/opportunities/${DATE}-research.json"
  if [[ ! -f "${f}" ]]; then
    f="${MAKEMONEY_DIR}/data/cron-sync/${DATE}-research.md"
  fi
  [[ -f "${f}" ]] || return 1
  if [[ "${f}" == *.json ]]; then
    python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['content'])" "${f}"
  else
    python3 "${MAKEMONEY_DIR}/scripts/parse_cron_output.py" "${f}" 2>/dev/null || true
  fi
}

call_llm() {
  local context="$1"
  local api_key litellm_url
  api_key="$(load_api_key)"
  if [[ -z "${api_key}" ]]; then
    echo "ERRO: sem API key LiteLLM (config.yaml ou .env)" >&2
    return 1
  fi
  litellm_url="${LITELLM_URL}"
  if [[ -z "${litellm_url}" && -f /opt/data/config.yaml ]]; then
    litellm_url="$(python3 -c "import yaml; c=yaml.safe_load(open('/opt/data/config.yaml')); print((c.get('model') or {}).get('base_url',''))" 2>/dev/null || true)"
  fi
  litellm_url="${litellm_url:-http://192.168.0.186:4000}"

  python3 - "${litellm_url}" "${MODEL}" "${api_key}" "${MAX_CHARS}" "${context}" <<'PY'
import json, sys, urllib.request

base, model, key, max_chars, context = sys.argv[1:6]
prompt = f"""Deep dive makemoney01 — oportunidade prioritária AGLz (pt-BR, máx {max_chars} chars).

CONTEXTO DO SCAN DE HOJE:
{context}

Entrega:
1. Proposta de valor (2 frases)
2. Roadmap 2 semanas (5 bullets acionáveis)
3. KPIs de validação (3 métricas)
4. Riscos e mitigação
5. Sinergia com stack AGL (LiteLLM, Hermes, llm-wiki, agl-hostman)
6. Próximo passo concreto (1 frase)

Sem inventar dados de mercado — marcar [VALIDAR] onde necessário."""

body = json.dumps({
    "model": model,
    "messages": [{"role": "user", "content": prompt}],
    "max_tokens": 1200,
    "temperature": 0.4,
}).encode()

req = urllib.request.Request(
    f"{base.rstrip('/')}/v1/chat/completions",
    data=body,
    headers={"Authorization": f"Bearer {key}", "Content-Type": "application/json"},
    method="POST",
)
with urllib.request.urlopen(req, timeout=180) as resp:
    data = json.loads(resp.read().decode())
print(data["choices"][0]["message"]["content"].strip())
PY
}

save_outputs() {
  local content="$1"
  local json_out="${MAKEMONEY_DIR}/data/opportunities/${DATE}-deep-dive.json"
  local md_out="${MAKEMONEY_DIR}/data/cron-sync/${DATE}-deep-dive-generated.md"
  local wiki_out="${MAKEMONEY_DIR}/wiki-ingest/${DATE}-makemoney-deep-dive.md"

  python3 - "${json_out}" "${DATE}" "${content}" <<'PY'
import json, sys
from datetime import datetime, timezone
out, date, content = sys.argv[1:4]
from pathlib import Path
Path(out).write_text(json.dumps({
    "date": date, "type": "deep-dive", "generated_at": datetime.now(timezone.utc).isoformat(),
    "content": content, "source": "hermes-makemoney-deep-dive.sh",
}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
PY

  {
    echo "# makemoney01 Deep Dive — ${DATE}"
    echo ""
    echo "${content}"
  } > "${md_out}"

  {
    echo "---"
    echo "title: makemoney01 Deep Dive ${DATE}"
    echo "tags: [makemoney01, oportunidade, hermes]"
    echo "confidence: medium"
    echo "source: hermes-cron"
    echo "date: ${DATE}"
    echo "---"
    echo ""
    echo "${content}"
    echo ""
    echo "Ver também: [[makemoney01]]"
  } > "${wiki_out}"

  echo "${content}"
}

main() {
  [[ -d "${MAKEMONEY_DIR}" ]] || { echo "ERRO: ${MAKEMONEY_DIR}" >&2; exit 1; }
  local context
  context="$(read_research)" || { echo "[SILENT]"; exit 0; }
  [[ -n "${context}" && "${context}" != "SILENT" ]] || { echo "[SILENT]"; exit 0; }

  local result
  result="$(call_llm "${context}")" || exit 1
  [[ -n "${result}" ]] || { echo "[SILENT]"; exit 0; }
  save_outputs "${result}"
}

main "$@"

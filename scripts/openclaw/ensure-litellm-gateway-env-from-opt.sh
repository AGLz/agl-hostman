#!/usr/bin/env bash
# Garante ~/.openclaw/litellm-gateway.env com LITELLM_MASTER_KEY alinhada a /opt/litellm/.env.
# Reason: sem master key o sync-systemd-openclaw-env.sh não preenche Bearer; LiteLLM devolve 401.
# Também: LITELLM_API_KEY (= master) e correção de apiKey em models.json + openclaw.json para o marcador
# LITELLM_API_KEY (OpenClaw não expande "${LITELLM_MASTER_KEY}").
#
# Uso (no host com LiteLLM Docker, ex. fgsrv06 / agldv03):
#   bash scripts/openclaw/ensure-litellm-gateway-env-from-opt.sh
set -euo pipefail

OPT=/opt/litellm/.env
OC=/root/.openclaw/litellm-gateway.env

if [[ ! -f "$OPT" ]]; then
  echo "ERRO: falta $OPT (LiteLLM não instalado neste caminho?)" >&2
  exit 1
fi

MASTER="$(grep -m1 '^LITELLM_MASTER_KEY=' "$OPT" | cut -d= -f2-)"
MASTER="${MASTER%$'\r'}"
MASTER="${MASTER#\"}"
MASTER="${MASTER%\"}"
if [[ -z "${MASTER:-}" ]]; then
  echo "ERRO: LITELLM_MASTER_KEY vazia em $OPT" >&2
  exit 1
fi

URL="http://127.0.0.1:4000"
if [[ -f "$OC" ]]; then
  line="$(grep -m1 'LITELLM_GATEWAY_URL=' "$OC" || true)"
  if [[ -n "$line" ]]; then
    raw="${line#*=}"
    raw="${raw#export }"
    raw="${raw//\"/}"
    raw="${raw//\'/}"
    if [[ -n "$raw" ]]; then
      URL="$raw"
    fi
  fi
fi

mkdir -p "$(dirname "$OC")"
tmp="$(mktemp)"
{
  printf 'LITELLM_GATEWAY_URL="%s"\n' "$URL"
  printf 'LITELLM_MASTER_KEY="%s"\n' "$MASTER"
  printf 'LITELLM_API_KEY="%s"\n' "$MASTER"
  printf 'ANTHROPIC_BASE_URL="%s"\n' "$URL"
} >"$tmp"
mv "$tmp" "$OC"
chmod 600 "$OC" || true
echo "OK: $OC atualizado (URL + master key a partir de $OPT)"

# agents/main/agent/models.json costuma ter sk-your-secure-master-key literal → 401 no proxy.
MODELS_JSON="${OPENCLAW_AGENT_MODELS_JSON:-/root/.openclaw/agents/main/agent/models.json}"
if [[ -f "$MODELS_JSON" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$MODELS_JSON" <<'PY' || true
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
raw = p.read_text(encoding="utf-8")
data = json.loads(raw)
provs = data.get("providers")
if not isinstance(provs, dict):
    sys.exit(0)
changed = False
placeholders = frozenset({"sk-your-secure-master-key", "sk-litellm-default"})
# Reason: OpenClaw resolve só marcadores exactos (LITELLM_API_KEY em KNOWN_ENV_API_KEY_MARKERS), não "${LITELLM_MASTER_KEY}".
bad_markers = frozenset({"${LITELLM_MASTER_KEY}", "LITELLM_MASTER_KEY"})
for block in provs.values():
    if not isinstance(block, dict):
        continue
    k = block.get("apiKey")
    if k in placeholders or k in bad_markers:
        block["apiKey"] = "LITELLM_API_KEY"
        changed = True
if changed:
    bak = p.with_suffix(".json.bak.apikey-placeholder")
    bak.write_text(raw, encoding="utf-8")
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    try:
        p.chmod(0o600)
    except OSError:
        pass
    print("OK: apiKey → LITELLM_API_KEY (marcador OpenClaw) em", p, "(backup", str(bak) + ")")
PY
fi

# ~/.openclaw/openclaw.json — o gateway usa models.providers aqui; sem patch, fica ${LITELLM_MASTER_KEY} (inválido).
OC_JSON_PATCH="${OPENCLAW_JSON:-$HOME/.openclaw/openclaw.json}"
if [[ -f "$OC_JSON_PATCH" ]] && command -v python3 >/dev/null 2>&1; then
  python3 - "$OC_JSON_PATCH" <<'PY' || true
import json
import sys
from pathlib import Path

p = Path(sys.argv[1])
raw = p.read_text(encoding="utf-8")
data = json.loads(raw)
provs = data.get("models", {}).get("providers")
if not isinstance(provs, dict):
    sys.exit(0)
changed = False
placeholders = frozenset({"sk-your-secure-master-key", "sk-litellm-default"})
bad_markers = frozenset({"${LITELLM_MASTER_KEY}", "LITELLM_MASTER_KEY"})
for block in provs.values():
    if not isinstance(block, dict):
        continue
    k = block.get("apiKey")
    if k in placeholders or k in bad_markers:
        block["apiKey"] = "LITELLM_API_KEY"
        changed = True
if changed:
    bak = p.with_name(p.name + ".bak.apikey-marker")
    bak.write_text(raw, encoding="utf-8")
    p.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    try:
        p.chmod(0o600)
    except OSError:
        pass
    print("OK: openclaw.json models.providers.apiKey → LITELLM_API_KEY (backup", str(bak) + ")")
PY
fi

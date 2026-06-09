#!/usr/bin/env bash
# Corrige modelos Hermes Quartet no CT188 quando gpt-5.5 / zai-glm-flash falham.
#
# Política (2026-06): Z.AI quota maior → OpenAI → Anthropic; Ollama GPU (agl-primary) para contexto longo / burst sem limites.
#   primário Jarvis: zai-glm-5 | agentes: zai-coding-glm-4.7 | fallback: agl-primary | aux: glm-5
# Modo legado --quota: Groq free (só se Z.AI/OpenAI indisponíveis)
#
# Uso (root no CT188):
#   bash fix-hermes-quartet-models-ct188.sh
#   bash fix-hermes-quartet-models-ct188.sh --paid-tier
#   bash fix-hermes-quartet-models-ct188.sh --restore-openai   # após quota OpenAI repor

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
MODE="${1:-quota}"

case "${MODE}" in
  --paid-tier|"" )
    JARVIS_MODEL="zai-glm-5"
    AGENT_MODEL="zai-coding-glm-4.7"
    FALLBACK_MODEL="agl-primary"
    AUXILIARY_MODEL="glm-5"
    ;;
  --restore-openai)
    JARVIS_MODEL="gpt-5-mini"
    AGENT_MODEL="zai-coding-glm-4.7"
    FALLBACK_MODEL="agl-primary"
    AUXILIARY_MODEL="zai-glm-5"
    ;;
  quota|--quota)
    JARVIS_MODEL="groq-llama-31-8b"
    AGENT_MODEL="groq-llama-31-8b"
    FALLBACK_MODEL="or-nemotron-super-free"
    AUXILIARY_MODEL="groq-llama-31-8b"
    ;;
  *)
    echo "Uso: $0 [--restore-openai]" >&2
    exit 1
    ;;
esac

declare -A PRIMARY=(
  [jarvis]="${JARVIS_MODEL}"
  [elon]="${AGENT_MODEL}"
  [satya]="${AGENT_MODEL}"
  [werner]="${AGENT_MODEL}"
)

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

for agent in jarvis elon satya werner; do
  cfg="$(profile_cfg "${agent}")"
  primary="${PRIMARY[$agent]}"
  python3 - "${cfg}" "${primary}" "${FALLBACK_MODEL}" "${AUXILIARY_MODEL}" "${LITELLM_TS}" <<'PY'
import sys
from pathlib import Path
import yaml

path, primary, fallback_model, auxiliary_model, litellm = sys.argv[1:6]
cfg = yaml.safe_load(Path(path).read_text()) or {}

def patch_urls(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "base_url" and isinstance(v, str) and v.strip():
                if "localhost" in v or "127.0.0.1" in v:
                    obj[k] = litellm.rstrip("/")
            else:
                patch_urls(v)
    elif isinstance(obj, list):
        for item in obj:
            patch_urls(item)

patch_urls(cfg)

m = cfg.setdefault("model", {})
m["default"] = primary
m["fallback"] = fallback_model
m["provider"] = m.get("provider") or "custom"
m["base_url"] = litellm.rstrip("/")

fb = cfg.setdefault("fallback_model", {})
fb["provider"] = fb.get("provider") or "custom"
fb["model"] = fallback_model
fb["base_url"] = litellm.rstrip("/")
if m.get("api_key"):
    fb["api_key"] = m["api_key"]

for cp in cfg.get("custom_providers") or []:
    if isinstance(cp, dict):
        cp["base_url"] = litellm.rstrip("/")
        cp["fallback"] = fallback_model

deleg = cfg.get("delegation")
if isinstance(deleg, dict):
    deleg["provider"] = "custom"
    deleg["model"] = auxiliary_model
    deleg["base_url"] = litellm.rstrip("/")

aux = cfg.get("auxiliary")
if isinstance(aux, dict):
    for _name, block in aux.items():
        if isinstance(block, dict):
            block["provider"] = "custom"
            block["model"] = auxiliary_model
            block["base_url"] = litellm.rstrip("/")

prov = cfg.setdefault("providers", {})
custom = prov.setdefault("custom", {})
custom["base_url"] = litellm.rstrip("/")

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK {path} primary={primary} fallback={fallback_model} aux={auxiliary_model}")
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart

echo ""
echo "Modelos aplicados (modo ${MODE}):"
echo "  Jarvis: ${JARVIS_MODEL}"
echo "  Elon/Satya/Werner: ${AGENT_MODEL}"
echo "  Fallback: ${FALLBACK_MODEL} | Aux/Delegation: ${AUXILIARY_MODEL}"

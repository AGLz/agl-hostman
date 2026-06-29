#!/usr/bin/env bash
# Hermes CT188: swarm em free models NO-LOGGING (OpenRouter) + fallback local.
#
# Privacidade: estes aliases usam provider.data_collection=deny no LiteLLM → OpenRouter
# só roteia para providers que NAO treinam/retem prompts (ex. Venice ZDR). Logo é SEGURO
# para dados AGL (segundo cérebro, agência, leads), ao contrário dos stealth que logam.
# Bom para paralelismo: Qwen3 (parallel tool calling), Nous Hermes 3, Llama 3.3.
#
# Tiers:
#   default                    → free no-logging (qwen3-coder/next, hermes3, llama70b) + fallback local
#   HERMES_USE_LOGGING_FREE=1  → owl-alpha/nemotron (LOGAM prompts) — SO tarefas publicas, sem dados AGL
#
# Alternativa 100% on-prem (soberania máxima): hermes-secure-routing-ct188.sh
#
# Uso (root no CT188):
#   bash hermes-openrouter-free-ct188.sh
#   HERMES_USE_LOGGING_FREE=1 bash hermes-openrouter-free-ct188.sh   # publico apenas

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

CRITICAL_AGENTS=(jarvis curator)
OTHER_AGENTS=(elon satya werner orion)

if [[ "${HERMES_USE_LOGGING_FREE:-0}" == "1" ]]; then
  echo "AVISO: a usar free models que LOGAM (owl-alpha/nemotron). Só para tarefas públicas, sem dados AGL." >&2
  CRIT_PRIMARY="or-nemotron-ultra-free"; CRIT_FALLBACK="or-owl-alpha"
  CRIT_FP="or-owl-alpha,or-nemotron-super-free,groq-llama-31-8b,agl-primary-vm110"
  OTHER_PRIMARY="or-owl-alpha"; OTHER_FALLBACK="or-nemotron-super-free"
  OTHER_FP="or-nemotron-super-free,groq-llama-31-8b,agl-primary-vm110"
  AUX_MODEL="or-owl-alpha"
else
  # No-logging (data_collection=deny). Seguro p/ dados AGL.
  CRIT_PRIMARY="or-qwen3-coder-free"; CRIT_FALLBACK="or-hermes-free"
  CRIT_FP="or-hermes-free,or-qwen3-next-free,or-llama-3.3-70b-free,agl-sensitive"
  OTHER_PRIMARY="or-qwen3-next-free"; OTHER_FALLBACK="or-llama-3.3-70b-free"
  OTHER_FP="or-llama-3.3-70b-free,or-hermes-free,or-qwen3-coder-free,agl-sensitive"
  AUX_MODEL="or-qwen3-next-free"
fi

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

apply_cfg() {
  local cfg="$1" primary="$2" fallback="$3" fp_csv="$4"
  python3 - "${cfg}" "${primary}" "${fallback}" "${fp_csv}" "${AUX_MODEL}" "${LITELLM_TS}" <<'PY'
import sys
from pathlib import Path
import yaml

path, primary, fallback, fp_csv, aux_model, litellm = sys.argv[1:7]
base = litellm.rstrip("/")
cfg = yaml.safe_load(Path(path).read_text()) or {}

m = cfg.setdefault("model", {})
key = m.get("api_key")
m["default"] = primary
m["fallback"] = fallback
m["provider"] = m.get("provider") or "custom"
m["base_url"] = base
m["max_tokens"] = int(m.get("max_tokens") or 8192)

cfg["fallback_providers"] = []
for model in [x for x in fp_csv.split(",") if x]:
    entry = {"provider": "custom", "model": model, "base_url": base}
    if key:
        entry["api_key"] = key
    cfg["fallback_providers"].append(entry)

aux = cfg.get("auxiliary")
if isinstance(aux, dict):
    for block in aux.values():
        if isinstance(block, dict):
            block["provider"] = "custom"
            block["model"] = aux_model
            block["base_url"] = base
            if key:
                block["api_key"] = key

deleg = cfg.get("delegation")
if isinstance(deleg, dict):
    deleg["provider"] = "custom"
    deleg["model"] = aux_model
    deleg["base_url"] = base
    if key:
        deleg["api_key"] = key

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK {path} primary={primary} fallback={fallback} aux={aux_model}")
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
}

for agent in "${CRITICAL_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "${CRIT_PRIMARY}" "${CRIT_FALLBACK}" "${CRIT_FP}"
done

for agent in "${OTHER_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "${OTHER_PRIMARY}" "${OTHER_FALLBACK}" "${OTHER_FP}"
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart 2>/dev/null || true

echo ""
if [[ "${HERMES_USE_LOGGING_FREE:-0}" == "1" ]]; then
  echo "Free LOGGING aplicado (público apenas):"
else
  echo "Free NO-LOGGING aplicado (seguro p/ dados AGL, data_collection=deny):"
fi
echo "  Criticos (${CRIT_PRIMARY}): ${CRITICAL_AGENTS[*]}"
echo "  Restantes (${OTHER_PRIMARY}): ${OTHER_AGENTS[*]}"
echo "  Aux: ${AUX_MODEL} | Fallback final: agl-sensitive (local)"

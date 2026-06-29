#!/usr/bin/env bash
# Hermes CT188: primarios OpenRouter FREE (regime saldo < $15, politica AGL).
#
# Reparticao (agentsdirectory.dev + validacao AGL 2026-06-29):
#   Criticos (jarvis/curator): or-nemotron-ultra-free — reasoning/orquestracao, 1M ctx
#   Restantes (elon/satya/werner/orion): or-owl-alpha — all-round, ~19tps, 1M ctx
# Fallbacks (sem paid): or-owl-alpha / or-nemotron-super-free -> groq -> vm110
#
# AVISO: modelos free OpenRouter logam prompts (NVIDIA + stealth Owl Alpha).
# Dados sensiveis AGL -> agl-primary-vm110 (local, zero logging).
#
# Uso (root no CT188):
#   bash hermes-openrouter-free-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

CRITICAL_AGENTS=(jarvis curator)
OTHER_AGENTS=(elon satya werner orion)
AUX_MODEL="or-owl-alpha"

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
  apply_cfg "${cfg}" "or-nemotron-ultra-free" "or-owl-alpha" \
    "or-owl-alpha,or-nemotron-super-free,groq-llama-31-8b,agl-primary-vm110"
done

for agent in "${OTHER_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "or-owl-alpha" "or-nemotron-super-free" \
    "or-nemotron-super-free,groq-llama-31-8b,agl-primary-vm110"
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart

echo ""
echo "OpenRouter FREE aplicado:"
echo "  Criticos (or-nemotron-ultra-free): ${CRITICAL_AGENTS[*]}"
echo "  Restantes (or-owl-alpha):          ${OTHER_AGENTS[*]}"
echo "  Aux: ${AUX_MODEL} | Fallback final: agl-primary-vm110"

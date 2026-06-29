#!/usr/bin/env bash
# Hermes CT188: primarios GLM-4.5 (Z.AI balance, concurrency 10).
#
# Motivo (2026-06-29): GLM Coding Plan (/api/coding/paas/v4) tem concurrency baixa
# (GLM-4.7=2, GLM-4.7-Flash=1). Multi-agente Hermes esgota com 429/1302.
# GLM-4.5 via /api/openai/v1 (balance) tem concurrency 10 — validado 4/4 HTTP 200
# vs 4/4 HTTP 429 no coding plan com a mesma API key.
#
# Politica: todos os 6 agentes -> glm-4.5; aux/compressao -> glm-air (4.5-Air, conc 5).
# Fallbacks sem Coding Plan nem OpenAI quota: or-nemotron -> or-minimax -> groq -> vm110.
#
# Uso (root no CT188):
#   bash hermes-glm45-balance-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY="glm-4.5"
AUX_MODEL="glm-air"
FALLBACK="or-nemotron-super-free"
FP_CSV="or-nemotron-super-free,or-minimax-m2.5-free,groq-llama-31-8b,agl-primary-vm110"

AGENTS=(jarvis elon satya werner curator orion)

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

for agent in "${AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  python3 - "${cfg}" "${PRIMARY}" "${FALLBACK}" "${FP_CSV}" "${AUX_MODEL}" "${LITELLM_TS}" <<'PY'
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
m["max_tokens"] = int(m.get("max_tokens") or 16384)

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
print(f"OK {path} primary={primary} aux={aux_model} fp={len(cfg['fallback_providers'])}")
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart

echo ""
echo "GLM-4.5 balance aplicado (concurrency 10):"
echo "  Agentes: ${AGENTS[*]}"
echo "  Primario: ${PRIMARY} | Aux: ${AUX_MODEL}"

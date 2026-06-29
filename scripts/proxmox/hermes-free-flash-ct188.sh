#!/usr/bin/env bash
# Hermes CT188: stopgap GRATIS — primario glm-flash (GLM-4.5-Flash free /api/anthropic).
#
# Contexto (2026-06-29): TODOS os provedores premium esgotados:
#   - Z.AI Coding Plan (/api/coding/paas/v4): 1310 Weekly/Monthly exhausted, reset 2026-07-02
#   - Z.AI developer balance (/api/openai/v1, /api/paas/v4): 1113 Insufficient balance
#   - OpenAI: quota esgotada | OpenRouter: chave 401 User not found
#   - Groq free: TPM 8000 < contexto Hermes ~14k -> "Request too large"
# Unico modelo gratis que aguenta contexto 14k = glm-flash (GLM-4.5-Flash, free).
#
# Evita o anti-padrao anterior (primario glm-4.5 -> 404 -> fallback glm-flash):
# poe glm-flash como primario explicito. aux/compressao tambem glm-flash.
# Fallbacks: glm-flash -> groq-llama-31-8b -> agl-primary-vm110 (local).
#
# Reavaliar apos 2026-07-02 (reset Coding Plan) ou recarga de provedor.
#
# Uso (root no CT188):
#   bash hermes-free-flash-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY="glm-flash"
AUX_MODEL="glm-flash"
FALLBACK="groq-llama-31-8b"
FP_CSV="groq-llama-31-8b,agl-primary-vm110"

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
echo "Stopgap GRATIS aplicado (glm-flash primario):"
echo "  Agentes: ${AGENTS[*]}"
echo "  Primario/Aux: ${PRIMARY} | Fallback: ${FALLBACK} -> agl-primary-vm110"
echo "  Reavaliar apos 2026-07-02 (reset Coding Plan)."

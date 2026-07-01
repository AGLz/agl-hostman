#!/usr/bin/env bash
# Hermes CT188: ZERO OpenRouter (créditos esgotados — 402 mesmo em :free).
#
# Stack: Z.AI flash → Groq → Ollama CPU (agl-primary) / Z.AI vm110 alias.
# Aplica a todos os agentes (jarvis…composio) + crons.
#
# Uso (root no CT188 ou SSH):
#   bash fix-hermes-zero-openrouter-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ALL_AGENTS=(jarvis elon satya werner curator orion argus verifier composio)
PRIMARY="${HERMES_ZERO_OR_PRIMARY:-zai-glm-flash}"
FALLBACK="${HERMES_ZERO_OR_FALLBACK:-groq-llama-31-8b}"
FALLBACK_CSV="${HERMES_ZERO_OR_FALLBACK_CSV:-groq-llama-31-8b,agl-primary-zai-glm-flash,agl-primary}"
AUX_MODEL="${HERMES_ZERO_OR_AUX:-glm-4.7-flash}"

profile_cfg() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data/config.yaml"
  else
    echo "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  fi
}

apply_cfg() {
  local cfg="$1"
  python3 - "${cfg}" "${PRIMARY}" "${FALLBACK}" "${FALLBACK_CSV}" "${AUX_MODEL}" "${LITELLM_TS}" <<'PY'
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

fb = cfg.setdefault("fallback_model", {})
fb["provider"] = "custom"
fb["model"] = fallback
fb["base_url"] = base
if key:
    fb["api_key"] = key

cfg["fallback_providers"] = []
for model in [x for x in fp_csv.split(",") if x]:
    entry = {"provider": "custom", "model": model, "base_url": base}
    if key:
        entry["api_key"] = key
    cfg["fallback_providers"].append(entry)

for block in (cfg.get("auxiliary") or {}).values():
    if isinstance(block, dict):
        block.update(provider="custom", model=aux_model, base_url=base)
        if key:
            block["api_key"] = key

deleg = cfg.get("delegation")
if isinstance(deleg, dict):
    deleg.update(provider="custom", model=aux_model, base_url=base)
    if key:
        deleg["api_key"] = key

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK {path} primary={primary} fallback={fallback}")
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
}

for agent in "${ALL_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}"
done

# Crons: sem OpenRouter
CRON_MODEL="${CRON_MODEL:-agl-primary-zai-glm-flash}" \
CRON_FALLBACK="${CRON_FALLBACK:-groq-llama-31-8b}" \
  bash "${SCRIPT_DIR}/fix-hermes-cron-models-ct188.sh" 2>/dev/null || true

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart 2>/dev/null || true

echo ""
echo "Hermes ZERO OpenRouter aplicado:"
echo "  Primário: ${PRIMARY} | Fallback: ${FALLBACK_CSV}"
echo "  Crons: ${CRON_MODEL:-agl-primary-zai-glm-flash} → ${CRON_FALLBACK:-groq-llama-31-8b}"
echo "  Repor créditos OR antes de voltar a or-* / agl-sensitive ZDR."

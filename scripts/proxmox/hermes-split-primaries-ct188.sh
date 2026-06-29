#!/usr/bin/env bash
# Reparticao de primarios Hermes (CT188) para aliviar rate-limit 1302 do Z.AI.
#
# Politica (2026-06-29): com os 6 agentes em Z.AI (zai-coding-glm-4.7) o GLM Coding
# Plan satura sob carga (1302). Reparte:
#   - Z.AI (criticos):        jarvis, curator      -> zai-coding-glm-4.7
#   - non-Z.AI (restantes):   elon, satya, werner, orion -> or-nemotron-super-free
#
# Cadeias de fallback (todas sem OpenAI; ver fix-hermes-jarvis-curator-resilience):
#   Z.AI:     zai-coding-glm-4.7 -> or-nemotron-super-free -> or-minimax-m2.5-free -> agl-primary-vm110
#   non-Z.AI: or-nemotron-super-free -> or-minimax-m2.5-free -> groq-llama-31-8b -> agl-primary-vm110
#
# Uso (root no CT188):
#   bash hermes-split-primaries-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

ZAI_AGENTS=(jarvis curator)
NONZAI_AGENTS=(elon satya werner orion)

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
  python3 - "${cfg}" "${primary}" "${fallback}" "${fp_csv}" "${LITELLM_TS}" <<'PY'
import sys
from pathlib import Path
import yaml

path, primary, fallback, fp_csv, litellm = sys.argv[1:6]
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

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK {path} primary={primary} fp={len(cfg['fallback_providers'])}")
PY
  chown 10000:10000 "${cfg}" 2>/dev/null || true
}

for agent in "${ZAI_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"; [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "zai-coding-glm-4.7" "or-nemotron-super-free" \
    "or-nemotron-super-free,or-minimax-m2.5-free,agl-primary-vm110"
done

for agent in "${NONZAI_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"; [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "or-nemotron-super-free" "or-minimax-m2.5-free" \
    "or-minimax-m2.5-free,groq-llama-31-8b,agl-primary-vm110"
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart

echo ""
echo "Reparticao aplicada:"
echo "  Z.AI (zai-coding-glm-4.7):     ${ZAI_AGENTS[*]}"
echo "  non-Z.AI (or-nemotron-super):  ${NONZAI_AGENTS[*]}"

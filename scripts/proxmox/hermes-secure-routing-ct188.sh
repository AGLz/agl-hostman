#!/usr/bin/env bash
# Hermes CT188: routing SEGURO (zero-logging) — default para dados sensíveis.
#
# Porquê: TODOS os agentes leem o segundo cérebro (llm-wiki: infra + agência) e os
# crons leem makemoney/leads + emails/LinkedIn privados. Modelos cloud/free que
# LOGAM/TREINAM prompts (OpenRouter default, Owl Alpha, Nemotron) são fuga.
#
# !!! VMs GPU Ollama SUSPENSAS 2026-06-29 (VM110/VM310 em baixo). !!!
# O tier sensível NÃO pode usar local agora. Substituto temporário e reversível:
# cloud ZDR no-logging (provider.data_collection=deny + zdr=true) — só providers
# que NÃO treinam NEM retêm (Venice ZDR, Groq, Cerebras). O prompt passa por
# terceiros mas sem retenção/treino. REVERTER para 100% local (agl-primary-strong/
# vm110/fast) quando as GPUs voltarem (git revert deste commit).
#
# Routing (estado atual, VMs suspensas):
#   Todos os agentes  → primário agl-sensitive (ZDR cloud), fallback ZDR cloud.
#   Aux/delegation    → or-qwen3-next-free (ZDR cloud).
# Para tarefas EXPLICITAMENTE públicas (sem dados AGL no contexto) usar, em opt-in,
# scripts/proxmox/hermes-openrouter-free-ct188.sh — nunca para vault/agência/email.
#
# Uso (root no CT188):
#   bash hermes-secure-routing-ct188.sh

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"

ALL_AGENTS=(jarvis curator elon satya werner orion argus verifier)
# VMs GPU suspensas → fallback ZDR cloud no-logging. Reverter p/ cadeia local quando voltarem.
PRIMARY="${HERMES_SECURE_PRIMARY:-agl-sensitive}"
FALLBACK="${HERMES_SECURE_FALLBACK:-or-qwen3-next-free}"
FALLBACK_CSV="${HERMES_SECURE_FALLBACK_CSV:-or-qwen3-next-free,or-hermes-free,or-llama-3.3-70b-free,groq-llama-31-8b}"
AUX_MODEL="${HERMES_SECURE_AUX:-or-qwen3-next-free}"

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

for agent in "${ALL_AGENTS[@]}"; do
  cfg="$(profile_cfg "${agent}")"
  [[ -f "${cfg}" ]] || continue
  apply_cfg "${cfg}" "${PRIMARY}" "${FALLBACK}" "${FALLBACK_CSV}"
done

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart 2>/dev/null || true

echo ""
echo "Routing SEGURO (no-logging) aplicado:"
echo "  Todos os agentes → primário ${PRIMARY}"
echo "  Fallback ZDR cloud no-logging: ${FALLBACK_CSV}"
echo "  Aux/delegation: ${AUX_MODEL}"
echo "  VMs GPU SUSPENSAS → cloud ZDR (data_collection=deny + zdr): não treina nem retém."
echo "  Reverter p/ 100% local quando VM110/VM310 voltarem (git revert)."

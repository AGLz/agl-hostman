#!/usr/bin/env bash
# Corrige rate limits Hermes CT188: fallbacks agl-primary, compressão de contexto,
# delegação sem Groq (TPM 6k incompatível com sessões longas).
#
# Causa típica: zai-glm-5 falha (tool blocks Z.AI) → fallback groq com ~80k tokens → 429 TPM.
#
# Uso (root no CT188):
#   bash fix-hermes-rate-limits-ct188.sh
#   bash fix-hermes-rate-limits-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
OPT_SNIPPET="${AGL_HOSTMAN}/docker/hermes/config.aglz-optimization-snippet.yaml"

test -d "${SCRIPTS}" || { echo "ERRO: ${SCRIPTS} inexistente" >&2; exit 1; }

echo "=== 1/4 Modelos quartet (resilient: agl-primary fallback) ==="
bash "${SCRIPTS}/fix-hermes-quartet-models-ct188.sh" --resilient

echo "=== 2/4 Compressão de contexto (evitar payloads >6k TPM no Groq) ==="
python3 - "${HERMES_ROOT}" "${OPT_SNIPPET}" <<'PY'
import sys
from pathlib import Path
import yaml

hermes_root, snippet_path = sys.argv[1:3]
snippet = yaml.safe_load(Path(snippet_path).read_text()) or {}
compression = snippet.get("compression") or {}

profiles = [
    Path(hermes_root) / "data" / "config.yaml",
    *[Path(hermes_root) / "profiles" / a / "config.yaml" for a in ("elon", "satya", "werner")],
]

for path in profiles:
    if not path.is_file():
        continue
    cfg = yaml.safe_load(path.read_text()) or {}
    comp = cfg.setdefault("compression", {})
    comp.update(compression)
    comp["enabled"] = True
    comp.setdefault("abort_on_summary_failure", False)

    deleg = cfg.setdefault("delegation", {})
    deleg["model"] = "agl-primary"
    deleg["provider"] = "custom"

    aux = cfg.setdefault("auxiliary", {})
    for name, block in list(aux.items()):
        if isinstance(block, dict):
            block["model"] = "glm-4.7-flash"
            block["provider"] = "custom"

    m = cfg.setdefault("model", {})
    # Nunca Groq como fallback Hermes (TPM 6k vs sessões 50k+ tokens)
    if m.get("fallback") in ("groq-llama-31-8b", "or-nemotron-super-free"):
        m["fallback"] = "agl-primary"
    fb = cfg.setdefault("fallback_model", {})
    if fb.get("model") in ("groq-llama-31-8b", "or-nemotron-super-free"):
        fb["model"] = "agl-primary"

    path.write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
    print(f"OK compression+delegation {path}")
PY

for cfg in "${HERMES_ROOT}/data/config.yaml" "${HERMES_ROOT}/profiles/"*/config.yaml; do
  [[ -f "${cfg}" ]] && chown 10000:10000 "${cfg}" 2>/dev/null || true
done

echo "=== 3/4 Sync LiteLLM CT186 (fallback zai-glm-5 → agl-primary) ==="
if [[ -x "${AGL_HOSTMAN}/scripts/litellm/sync-config-all-hosts.sh" ]]; then
  bash "${AGL_HOSTMAN}/scripts/litellm/sync-config-all-hosts.sh" || echo "WARN: sync LiteLLM falhou — aplicar manualmente no CT186" >&2
else
  echo "WARN: sync-config-all-hosts.sh em falta" >&2
fi

echo "=== 4/4 Restart quartet ==="
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner
sleep 15

echo ""
echo "Concluído. Testar com NOVA mensagem Telegram (não thread antiga com 80k tokens)."
echo "Smoke: bash ${SCRIPTS}/smoke-hermes-aglz-quartet.sh"

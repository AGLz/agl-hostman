#!/usr/bin/env bash
# Aplica modelos auth2api só a Jarvis / Elon / Werner no CT188.
# Satya, Curator, Orion, Argus, etc. ficam inalterados.
#
# Uso (neste host com SSH Tailscale ao CT188):
#   bash scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh
#   bash scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh --dry-run
#
# Reverter estes 3 para free-tier:
#   bash scripts/proxmox/apply-hermes-auth2api-jew-ct188.sh --revert-free

set -euo pipefail

HERMES_SSH="${HERMES_SSH:-root@100.81.225.22}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
DRY=0
REVERT=0

for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --revert-free) REVERT=1 ;;
    *) echo "Arg desconhecido: $a" >&2; exit 1 ;;
  esac
done

# Primários auth2api (LiteLLM CT186 aliases). Fallback Z.AI flash para não morrer se OAuth falhar.
JARVIS_MODEL="${JARVIS_MODEL:-auth2api-claude-sonnet}"
ELON_MODEL="${ELON_MODEL:-auth2api-gpt-codex}"
WERNER_MODEL="${WERNER_MODEL:-auth2api-claude-sonnet}"
FALLBACK_MODEL="${FALLBACK_MODEL:-zai-glm-flash}"
AUXILIARY_MODEL="${AUXILIARY_MODEL:-glm-4.7-flash}"

if [[ "$REVERT" -eq 1 ]]; then
  JARVIS_MODEL="zai-glm-flash"
  ELON_MODEL="glm-4.7-flash"
  WERNER_MODEL="glm-4.7-flash"
  FALLBACK_MODEL="agl-primary-vm110"
  AUXILIARY_MODEL="glm-4.7-flash"
fi

echo "=== Hermes JEW → modelos ==="
echo "  SSH: $HERMES_SSH"
echo "  Jarvis: $JARVIS_MODEL | Elon: $ELON_MODEL | Werner: $WERNER_MODEL"
echo "  Fallback: $FALLBACK_MODEL | Aux: $AUXILIARY_MODEL"
echo "  LiteLLM: $LITELLM_TS"
[[ "$DRY" -eq 1 ]] && echo "(dry-run)" && exit 0

ssh -o StrictHostKeyChecking=accept-new "$HERMES_SSH" \
  HERMES_ROOT="$HERMES_ROOT" LITELLM_TS="$LITELLM_TS" \
  JARVIS_MODEL="$JARVIS_MODEL" ELON_MODEL="$ELON_MODEL" WERNER_MODEL="$WERNER_MODEL" \
  FALLBACK_MODEL="$FALLBACK_MODEL" AUXILIARY_MODEL="$AUXILIARY_MODEL" \
  bash -s <<'REMOTE'
set -euo pipefail
python3 - <<'PY'
import os
from pathlib import Path
import yaml

root = Path(os.environ["HERMES_ROOT"])
litellm = os.environ["LITELLM_TS"].rstrip("/")
fallback = os.environ["FALLBACK_MODEL"]
aux = os.environ["AUXILIARY_MODEL"]
agents = {
    "jarvis": (root / "data" / "config.yaml", os.environ["JARVIS_MODEL"]),
    "elon": (root / "profiles" / "elon" / "config.yaml", os.environ["ELON_MODEL"]),
    "werner": (root / "profiles" / "werner" / "config.yaml", os.environ["WERNER_MODEL"]),
}

def patch(path: Path, primary: str) -> None:
    cfg = yaml.safe_load(path.read_text()) or {}
    m = cfg.setdefault("model", {})
    m["default"] = primary
    m["fallback"] = fallback
    m["provider"] = m.get("provider") or "custom"
    m["base_url"] = litellm
    m["max_tokens"] = int(m.get("max_tokens") or 16384)

    fb = cfg.setdefault("fallback_model", {})
    fb["provider"] = fb.get("provider") or "custom"
    fb["model"] = fallback
    fb["base_url"] = litellm
    if m.get("api_key"):
        fb["api_key"] = m["api_key"]

    fp = [
        {"provider": "custom", "model": fallback, "base_url": litellm},
        {"provider": "custom", "model": "glm-4.7-flash", "base_url": litellm},
    ]
    if m.get("api_key"):
        for e in fp:
            e["api_key"] = m["api_key"]
    cfg["fallback_providers"] = fp

    for cp in cfg.get("custom_providers") or []:
        if isinstance(cp, dict):
            cp["base_url"] = litellm

    # Aux/delegation: NÃO gastar OAuth Plus — flash barato
    deleg = cfg.get("delegation")
    if isinstance(deleg, dict):
        deleg["provider"] = "custom"
        deleg["model"] = aux
        deleg["base_url"] = litellm

    aux_block = cfg.get("auxiliary")
    if isinstance(aux_block, dict):
        for _n, block in aux_block.items():
            if isinstance(block, dict):
                block["provider"] = "custom"
                block["model"] = aux
                block["base_url"] = litellm

    prov = cfg.setdefault("providers", {})
    custom = prov.setdefault("custom", {})
    custom["base_url"] = litellm
    if m.get("api_key"):
        custom["api_key"] = m["api_key"]

    path.write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
    try:
        os.chown(path, 10000, 10000)
    except OSError:
        pass
    print(f"OK {path} primary={primary}")

for name, (path, primary) in agents.items():
    if not path.is_file():
        raise SystemExit(f"missing {path}")
    patch(path, primary)
PY

cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart hermes-jarvis hermes-elon hermes-werner
echo "Restart JEW OK"
REMOTE

echo "Done. Smoke: ssh $HERMES_SSH 'docker ps --filter name=hermes-jarvis --format \"{{.Names}} {{.Status}}\"'"

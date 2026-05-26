#!/usr/bin/env bash
# Bootstrap AGLz Agency: Jarvis + Elon + Satya + Werner no CT188.
# Executar dentro do CT188 como root.
#
# Uso:
#   bash bootstrap-ct188-hermes-aglz.sh /caminho/agl-hostman [HONCHO_TAILSCALE_URL]
#
# Ex.: bash bootstrap-ct188-hermes-aglz.sh /mnt/.../agl-hostman http://100.x.x.x:8000

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/agl-hostman [HONCHO_URL]}"
HONCHO_URL="${2:-}"
HERMES_ROOT="/opt/agl-hermes"
DATA="${HERMES_ROOT}/data"
LITELLM_TS="http://100.125.249.8:4000"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: ${AGL_HOSTMAN} inexistente" >&2; exit 1; }

echo "=== Profiles SOUL (jarvis, elon, satya, werner) ==="
for agent in jarvis elon satya werner; do
  install -d -m 0700 "${DATA}/profiles/${agent}"
  install -m 0600 "${AGL_HOSTMAN}/docker/hermes/profiles/${agent}/SOUL.md" \
    "${DATA}/profiles/${agent}/SOUL.md"
done

if [[ -f "${AGL_HOSTMAN}/.claude/skills/agl-infra/SKILL.md" ]]; then
  echo "=== Skill agl-infra → profile werner ==="
  install -d -m 0755 "${DATA}/profiles/werner/skills/agl-infra"
  install -m 0644 "${AGL_HOSTMAN}/.claude/skills/agl-infra/SKILL.md" \
    "${DATA}/profiles/werner/skills/agl-infra/SKILL.md"
fi

if [[ -f "${AGL_HOSTMAN}/docker/hermes/.env.aglz.example" ]] && [[ -f "${DATA}/.env" ]]; then
  echo "=== Merge .env.aglz.example (chaves em falta) ==="
  while IFS= read -r line; do
    [[ "${line}" =~ ^# ]] && continue
    [[ -z "${line}" ]] && continue
    key="${line%%=*}"
    grep -q "^${key}=" "${DATA}/.env" 2>/dev/null || echo "${line}" >>"${DATA}/.env"
  done <"${AGL_HOSTMAN}/docker/hermes/.env.aglz.example"
fi

if [[ ! -f "${DATA}/honcho.json" ]]; then
  install -m 0600 "${AGL_HOSTMAN}/docker/hermes/honcho.aglz.json.example" "${DATA}/honcho.json"
fi

if [[ -n "${HONCHO_URL}" ]]; then
  python3 - "${DATA}/honcho.json" "${HONCHO_URL}" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
data = json.loads(p.read_text())
data["baseUrl"] = sys.argv[2].rstrip("/")
p.write_text(json.dumps(data, indent=2) + "\n")
print("OK honcho baseUrl =", sys.argv[2])
PY
fi

echo "=== Merge config multi-agent ==="
python3 - "${AGL_HOSTMAN}/docker/hermes/config.aglz-multi-agent.yaml.example" "${DATA}/config.yaml" "${LITELLM_TS}" <<'PY'
import sys
from pathlib import Path
import yaml

fragment_path, config_path, litellm = sys.argv[1:4]
frag = yaml.safe_load(Path(fragment_path).read_text())
cfg = yaml.safe_load(Path(config_path).read_text()) if Path(config_path).exists() else {}
existing_key = (cfg.get("model") or {}).get("api_key")

for key, val in frag.items():
    if key == "model" and isinstance(val, dict):
        m = cfg.setdefault("model", {})
        m.update(val)
        if existing_key:
            m["api_key"] = existing_key
        m["base_url"] = litellm
    elif key in ("auxiliary", "delegation", "fallback_model") and isinstance(val, dict):
        block = cfg.setdefault(key, {})
        for k2, v2 in val.items():
            if isinstance(v2, dict):
                sub = block.setdefault(k2, {})
                sub.update(v2)
                if "base_url" in sub:
                    sub["base_url"] = litellm
            else:
                block[k2] = v2
        if key in ("delegation", "fallback_model"):
            block["base_url"] = litellm
    else:
        cfg[key] = val

Path(config_path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK: merged into {config_path}")
PY

chown -R 10000:10000 "${DATA}/profiles" 2>/dev/null || true

WIKI_DIR="/opt/agl-llm-wiki"
bash "${AGL_HOSTMAN}/scripts/proxmox/ensure-llm-wiki-ct188.sh" || \
  echo "AVISO: llm-wiki — ver ensure-llm-wiki-ct188.sh (gh clone no NFS agldv03)" >&2

cd "${HERMES_ROOT}"
docker compose pull hermes-gateway
docker compose up -d hermes-gateway

echo ""
echo "Próximos passos:"
echo "  1. TELEGRAM_BOT_TOKEN + _ELON + _SATYA + _WERNER e LINEAR_API_KEY em ${DATA}/.env"
echo "  2. Honcho CT192: ver docs/HONCHO-CT192-DEDICATED-LXC.md"
echo "  3. llm-wiki: ${WIKI_DIR} → /opt/llm-wiki (ver docs/LLM-WIKI-AGENCY-INTEGRATION.md)"
echo "  4. hermes memory setup → honcho (URL Tailscale CT192)"
echo "  Doc: docs/AGLZ-HERMES-ONLY-AGENCY.md"

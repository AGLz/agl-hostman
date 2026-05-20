#!/usr/bin/env bash
# Migra estado Hermes CLI (CT179 ~/.hermes) → layout Docker CT188 (/opt/agl-hermes/data).
# Executar no AGLSRV1 como root. CT188 deve ter Docker; compose pode ainda não estar up.
set -euo pipefail

LITELLM_URL="${LITELLM_URL:-http://192.168.0.186:4000}"

command -v pct >/dev/null || { echo "ERRO: pct no Proxmox" >&2; exit 1; }

echo "=== Export ~/.hermes (CT179) ==="
pct exec 179 -- tar czf - -C /root .hermes | pct exec 188 -- tar xzf - -C /tmp

echo "=== Layout /opt/agl-hermes/data ==="
pct exec 188 -- bash -s <<'INNER'
set -euo pipefail
install -d -m 0700 /opt/agl-hermes/data
src=/tmp/.hermes
for item in config.yaml state.db sessions memories skills logs SOUL.md auth.json channel_directory.json; do
  if [[ -e "${src}/${item}" ]]; then
    cp -a "${src}/${item}" /opt/agl-hermes/data/ 2>/dev/null || true
  fi
done
if [[ -d "${src}/cron" ]]; then cp -a "${src}/cron" /opt/agl-hermes/data/; fi
if [[ -d "${src}/checkpoints" ]]; then cp -a "${src}/checkpoints" /opt/agl-hermes/data/; fi
chown -R 10000:10000 /opt/agl-hermes/data
rm -rf /tmp/.hermes
INNER

if [[ -n "${LITELLM_URL}" ]]; then
  echo "=== Patch LiteLLM base_url em config.yaml ==="
  pct exec 188 -- python3 - "${LITELLM_URL}" <<'PY'
import sys
from pathlib import Path
try:
    import yaml
except ImportError:
    sys.exit(0)
base = sys.argv[1].rstrip("/")
p = Path("/opt/agl-hermes/data/config.yaml")
if not p.is_file():
    sys.exit(0)
data = yaml.safe_load(p.read_text())
prov = data.setdefault("providers", {})
custom = prov.setdefault("custom", {})
custom["base_url"] = base
p.write_text(yaml.dump(data, default_flow_style=False, allow_unicode=True))
print(f"OK: base_url -> {base}")
PY
fi

echo "OK: Hermes data migrado para CT188:/opt/agl-hermes/data"

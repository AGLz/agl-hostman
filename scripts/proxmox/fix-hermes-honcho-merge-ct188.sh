#!/usr/bin/env bash
# Merge honcho.json → config.yaml em todos os perfis Hermes CT188.
set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
AGENTS=(jarvis elon satya werner curator orion argus verifier composio)

profile_dir() {
  local a="$1"
  [[ "${a}" == "jarvis" ]] && echo "${HERMES_ROOT}/data" || echo "${HERMES_ROOT}/profiles/${a}"
}

merge_one() {
  local cfg="$1" honcho="$2"
  [[ -f "${honcho}" ]] || return 0
  python3 - "${cfg}" "${honcho}" <<'PY'
import json, sys
from pathlib import Path
import yaml

cfg_path, honcho_path = sys.argv[1:3]
cfg = yaml.safe_load(Path(cfg_path).read_text()) or {}
data = json.loads(Path(honcho_path).read_text())
h = (data.get("hosts") or {}).get("hermes") or {}
if not h:
    sys.exit(0)
cfg["honcho"] = {
    "enabled": h.get("enabled", True),
    "recallMode": h.get("recallMode", "hybrid"),
    "writeFrequency": h.get("writeFrequency", "async"),
    "sessionStrategy": h.get("sessionStrategy", "per-directory"),
    "dialecticReasoningLevel": h.get("dialecticReasoningLevel", "low"),
}
Path(cfg_path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK honcho → {cfg_path}")
PY
}

for agent in "${AGENTS[@]}"; do
  pdir="$(profile_dir "${agent}")"
  merge_one "${pdir}/config.yaml" "${pdir}/honcho.json"
  chown 10000:10000 "${pdir}/config.yaml" 2>/dev/null || true
done

echo "Honcho merge concluído."

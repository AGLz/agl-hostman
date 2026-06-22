#!/usr/bin/env bash
# Define model.max_tokens nos configs Hermes CT188 (evita truncamento finish_reason=length).
set -euo pipefail

MAX_TOKENS="${HERMES_MAX_TOKENS:-16384}"
CT188="${CT188:-188}"
AGLSRV1="${AGLSRV1:-100.107.113.33}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"

log() { printf '[fix-max-tokens] %s\n' "$*"; }

run_python() {
  local path="$1"
  python3 - "$path" "$MAX_TOKENS" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
max_tokens = int(sys.argv[2])
if not path.exists():
    print(f"SKIP missing {path}")
    raise SystemExit(0)

data = yaml.safe_load(path.read_text()) or {}
model = data.setdefault("model", {})
old = model.get("max_tokens")
model["max_tokens"] = max_tokens
path.write_text(yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False))
print(f"OK {path}: max_tokens {old} -> {max_tokens}")
PY
}

patch_yaml() {
  local path="$1"
  if [[ -d "$HERMES_ROOT" && -f "$path" ]]; then
    run_python "$path"
    return
  fi
  ssh -o ConnectTimeout=20 "root@${AGLSRV1}" \
    "pct exec ${CT188} -- python3 -" <<PY
import sys
from pathlib import Path
import yaml

path = Path("${path}")
max_tokens = ${MAX_TOKENS}
if not path.exists():
    print(f"SKIP missing {path}")
    raise SystemExit(0)

data = yaml.safe_load(path.read_text()) or {}
model = data.setdefault("model", {})
old = model.get("max_tokens")
model["max_tokens"] = max_tokens
path.write_text(yaml.dump(data, default_flow_style=False, allow_unicode=True, sort_keys=False))
print(f"OK {path}: max_tokens {old} -> {max_tokens}")
PY
}

main() {
  log "max_tokens=${MAX_TOKENS} HERMES_ROOT=${HERMES_ROOT}"
  patch_yaml "${HERMES_ROOT}/data/config.yaml"
  for agent in elon satya werner curator orion; do
    patch_yaml "${HERMES_ROOT}/profiles/${agent}/config.yaml"
  done
  log "Concluído."
}

main "$@"

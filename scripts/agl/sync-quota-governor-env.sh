#!/usr/bin/env bash
# Sincroniza /etc/agl-hostman/quota-governor.env com master key CT186 (OpenClaw secret).
# Nunca imprime a chave. Uso: sudo bash scripts/agl/sync-quota-governor-env.sh
set -euo pipefail

ENV_FILE="${GOVERNOR_ENV_FILE:-/etc/agl-hostman/quota-governor.env}"
SECRET="${LITELLM_MASTER_SECRET:-${HOME}/.openclaw/litellm-master.secret.env}"
EXAMPLE="${REPO_ROOT:-}/config/monitoring/quota-governor.env.example"

if [[ ! -f "$ENV_FILE" && -f "$EXAMPLE" ]]; then
  install -m 0600 "$EXAMPLE" "$ENV_FILE"
fi

python3 - "$ENV_FILE" "$SECRET" <<'PY'
import re
import sys
from pathlib import Path

env_path = Path(sys.argv[1])
secret_path = Path(sys.argv[2])
key = None
if secret_path.exists():
    for ln in secret_path.read_text().splitlines():
        ln = ln.strip()
        for pat in (
            r'^export LITELLM_MASTER_KEY=["\']?(.+?)["\']?\s*$',
            r'^LITELLM_MASTER_KEY=(.+)$',
        ):
            m = re.match(pat, ln)
            if m:
                key = m.group(1).strip().strip('"\'')
                break
        if key:
            break
if not key:
    print(f"AVISO: sem LITELLM_MASTER_KEY em {secret_path}", file=sys.stderr)
else:
    lines = [ln for ln in env_path.read_text().splitlines() if not ln.startswith("LITELLM_MASTER_KEY=")]
    lines.append(f"LITELLM_MASTER_KEY={key}")
    env_path.write_text("\n".join(lines).rstrip() + "\n")
    env_path.chmod(0o600)
    print("OK LITELLM_MASTER_KEY sincronizada")

extras = {
    "LITELLM_GATEWAY_URL": "http://100.125.249.8:4000",
}
text = env_path.read_text()
lines = text.splitlines()
for k, v in extras.items():
    lines = [ln for ln in lines if not ln.startswith(f"{k}=")]
    lines.append(f"{k}={v}")
# Não forçar LITELLM_ENV_FILE local — evita override da chave CT186
lines = [ln for ln in lines if not ln.startswith("LITELLM_ENV_FILE=")]
env_path.write_text("\n".join(lines).rstrip() + "\n")
env_path.chmod(0o600)
print(f"OK {env_path} (600)")
PY

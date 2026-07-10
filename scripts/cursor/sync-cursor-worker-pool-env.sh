#!/usr/bin/env bash
# Sincroniza /etc/cursor/worker-pool.env com CURSOR_API_KEY (nunca imprime a chave).
#
# Uso:
#   CURSOR_API_KEY='key_...' sudo bash scripts/cursor/sync-cursor-worker-pool-env.sh
#   sudo bash scripts/cursor/sync-cursor-worker-pool-env.sh ~/.cursor/user-api-key
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}"
ENV_FILE="/etc/cursor/worker-pool.env"
EXAMPLE="$REPO/config/cursor/worker-pool.env.example"
SECRET_FILE="${1:-${CURSOR_WORKER_POOL_SECRET:-${HOME}/.cursor/user-api-key}}"

[[ "$(id -u)" -eq 0 ]] || { echo "[FAIL] correr com sudo" >&2; exit 1; }
mkdir -p /etc/cursor && chmod 700 /etc/cursor
[[ -f "$ENV_FILE" ]] || install -m 0600 -o root -g root "$EXAMPLE" "$ENV_FILE"

python3 - "$ENV_FILE" "$SECRET_FILE" <<'PY'
import os, re, sys
from pathlib import Path

env_path = Path(sys.argv[1])
secret_path = Path(sys.argv[2])
key = os.environ.get("CURSOR_API_KEY", "").strip()

if not key and secret_path.exists():
    for ln in secret_path.read_text().splitlines():
        ln = ln.strip()
        if not ln or ln.startswith("#"):
            continue
        for pat in (
            r'^export CURSOR_API_KEY=["\']?(.+?)["\']?\s*$',
            r'^CURSOR_API_KEY=(.+)$',
        ):
            m = re.match(pat, ln)
            if m and m.group(1).strip():
                key = m.group(1).strip().strip('"\'')
                break
        if key:
            break

if not key or len(key) < 20:
    print("AVISO: CURSOR_API_KEY ausente ou inválida", file=sys.stderr)
    sys.exit(1)

lines = [ln for ln in env_path.read_text().splitlines() if not ln.startswith("CURSOR_API_KEY=")]
lines.append(f"CURSOR_API_KEY={key}")
env_path.write_text("\n".join(lines).rstrip() + "\n")
env_path.chmod(0o600)
print("OK CURSOR_API_KEY sincronizada")
PY

#!/usr/bin/env bash
# Sincroniza GEMINI_API_KEY + VERTEXAI_* (Vertex Express) para CT186 e recria litellm-proxy.
set -euo pipefail
REPO="${REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
HOST="${LITELLM_SSH_HOST:-root@100.125.249.8}"
REMOTE_DIR="${LITELLM_REMOTE_DIR:-/opt/agl-litellm}"
ENV_LOCAL="${LITELLM_ENV_FILE:-$REPO/config/litellm/.env}"

if [[ ! -f "$ENV_LOCAL" ]]; then
  echo "Falta $ENV_LOCAL" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_LOCAL"
set +a

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "GEMINI_API_KEY vazia em $ENV_LOCAL" >&2
  exit 1
fi

VERTEXAI_PROJECT="${VERTEXAI_PROJECT:-aglznet}"
VERTEXAI_LOCATION="${VERTEXAI_LOCATION:-global}"

ssh "$HOST" "REMOTE_DIR='$REMOTE_DIR' GEMINI_API_KEY='$GEMINI_API_KEY' VERTEXAI_PROJECT='$VERTEXAI_PROJECT' VERTEXAI_LOCATION='$VERTEXAI_LOCATION' bash -s" <<'REMOTE'
set -euo pipefail
cd "$REMOTE_DIR"
touch .env
python3 <<'PY'
import os
import pathlib

path = pathlib.Path(".env")
lines = path.read_text(encoding="utf-8").splitlines() if path.is_file() else []
updates = {
    "GEMINI_API_KEY": os.environ["GEMINI_API_KEY"],
    "VERTEXAI_PROJECT": os.environ.get("VERTEXAI_PROJECT", "aglznet"),
    "VERTEXAI_LOCATION": os.environ.get("VERTEXAI_LOCATION", "global"),
}
out: list[str] = []
seen: set[str] = set()
for line in lines:
    key = line.split("=", 1)[0] if "=" in line else ""
    if key in updates:
        out.append(f"{key}={updates[key]}")
        seen.add(key)
    else:
        out.append(line)
for key, val in updates.items():
    if key not in seen:
        out.append(f"{key}={val}")
path.write_text("\n".join(out) + "\n", encoding="utf-8")
print(f"OK: GEMINI_API_KEY ({len(updates['GEMINI_API_KEY'])} chars), VERTEXAI_PROJECT={updates['VERTEXAI_PROJECT']}, VERTEXAI_LOCATION={updates['VERTEXAI_LOCATION']}")
PY
docker compose up -d --force-recreate litellm-proxy
REMOTE

echo "OK: Vertex Express env aplicada em $HOST:$REMOTE_DIR/.env"

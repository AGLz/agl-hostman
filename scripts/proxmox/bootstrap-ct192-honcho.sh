#!/usr/bin/env bash
# Bootstrap Honcho self-hosted no CT192 (Docker + elkimek/honcho-self-hosted).
# Executar dentro do CT192 como root.
#
# Uso:
#   bash bootstrap-ct192-honcho.sh [LITELLM_OPENAI_BASE_URL] [LITELLM_API_KEY_FILE]
#
# LITELLM default: http://100.125.249.8:4000/v1 (Tailscale CT186)

set -euo pipefail

LITELLM_BASE="${1:-http://100.125.249.8:4000/v1}"
KEY_FILE="${2:-}"
INSTALL_ROOT="/opt/agl-honcho"

export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git
  curl -fsSL https://get.docker.com | sh
fi

install -d -m 0755 "${INSTALL_ROOT}"
cd "${INSTALL_ROOT}"

if [[ ! -d honcho-self-hosted ]]; then
  git clone --depth 1 https://github.com/elkimek/honcho-self-hosted.git
fi
if [[ ! -d honcho ]]; then
  git clone --depth 1 https://github.com/plastic-labs/honcho.git
fi

cp -f honcho-self-hosted/docker-compose.yml honcho/
cp -f honcho-self-hosted/config.toml honcho/
if [[ ! -f honcho/.env ]]; then
  cp honcho-self-hosted/env.example honcho/.env
fi

LITELLM_KEY=""
if [[ -n "${KEY_FILE}" ]] && [[ -f "${KEY_FILE}" ]]; then
  LITELLM_KEY="$(tr -d '\n' <"${KEY_FILE}")"
elif [[ -n "${LITELLM_MASTER_KEY:-}" ]]; then
  LITELLM_KEY="${LITELLM_MASTER_KEY}"
else
  echo "AVISO: definir LITELLM_MASTER_KEY ou passar ficheiro com sk-litellm-*" >&2
  LITELLM_KEY="CHANGE_ME"
fi

python3 - "${LITELLM_BASE}" "${LITELLM_KEY}" <<'PY'
import sys
from pathlib import Path

base, key = sys.argv[1:3]
path = Path("/opt/agl-honcho/honcho/.env")
lines = path.read_text().splitlines()
out = []
seen = set()
updates = {
    "LLM_VLLM_BASE_URL": base.rstrip("/"),
    "LLM_VLLM_API_KEY": key,
    "LLM_OPENAI_API_KEY": key,
    "LLM_OPENAI_COMPATIBLE_API_KEY": key,
    "OPENAI_COMPATIBLE_BASE_URL": base.rstrip("/"),
    "LLM_EMBEDDING_BASE_URL": base.rstrip("/"),
    "LLM_EMBEDDING_API_KEY": key,
    "LLM_EMBEDDING_MODEL": "openai/text-embedding-3-small",
}
for line in lines:
    if "=" in line and not line.strip().startswith("#"):
        k = line.split("=", 1)[0].strip()
        if k in updates:
            out.append(f"{k}={updates[k]}")
            seen.add(k)
            continue
    out.append(line)
for k, v in updates.items():
    if k not in seen:
        out.append(f"{k}={v}")
path.write_text("\n".join(out) + "\n")
print("OK: honcho .env → LiteLLM", base)
PY

cd honcho
docker compose up -d --build

for _ in $(seq 1 30); do
  if curl -sf http://127.0.0.1:8000/openapi.json >/dev/null 2>&1; then
    echo "OK: Honcho API http://127.0.0.1:8000"
    exit 0
  fi
  sleep 5
done

echo "AVISO: API não respondeu — docker compose logs api deriver" >&2
exit 1

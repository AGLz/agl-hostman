#!/usr/bin/env bash
# Liga modelos auth2api (Claude+Codex) ao LiteLLM local /opt/litellm (lab).
# Não toca no CT186. Requer rede docker litellm_litellm-net.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
SNIPPET="$ROOT/config/litellm/auth2api-lab-snippet.yaml"
LITELLM_DIR="${LITELLM_OPT_DIR:-/opt/litellm}"
CONFIG="${LITELLM_DIR}/config.yaml"
ENVF="${LITELLM_DIR}/.env"
BEGIN="# >>> AUTH2API_LAB_BEGIN"
END="# <<< AUTH2API_LAB_END"
BASE_URL="${AUTH2API_BASE_URL:-http://agl-auth2api:8317/v1}"

if [[ ! -f "$CONFIG" || ! -f "$ENVF" ]]; then
  echo "LiteLLM lab espera ${LITELLM_DIR}/{config.yaml,.env}" >&2
  exit 1
fi
if [[ ! -f "$AUTH_DIR/.env" ]]; then
  echo "Falta $AUTH_DIR/.env — bootstrap + login auth2api primeiro." >&2
  exit 1
fi
# shellcheck disable=SC1091
set -a
source "$AUTH_DIR/.env"
set +a
if [[ -z "${AUTH2API_API_KEY:-}" ]]; then
  echo "AUTH2API_API_KEY vazio em $AUTH_DIR/.env" >&2
  exit 1
fi

if ! docker network inspect litellm_litellm-net >/dev/null 2>&1; then
  echo "Rede litellm_litellm-net inexistente — LiteLLM local a correr?" >&2
  exit 1
fi

docker compose -f "$AUTH_DIR/docker-compose.yml" up -d

# Env LiteLLM
touch "$ENVF"
if grep -q '^AUTH2API_API_KEY=' "$ENVF"; then
  sed -i "s|^AUTH2API_API_KEY=.*|AUTH2API_API_KEY=${AUTH2API_API_KEY}|" "$ENVF"
else
  printf '\n# auth2api lab\nAUTH2API_API_KEY=%s\n' "$AUTH2API_API_KEY" >>"$ENVF"
fi
if grep -q '^AUTH2API_BASE_URL=' "$ENVF"; then
  sed -i "s|^AUTH2API_BASE_URL=.*|AUTH2API_BASE_URL=${BASE_URL}|" "$ENVF"
else
  printf 'AUTH2API_BASE_URL=%s\n' "$BASE_URL" >>"$ENVF"
fi

python3 - "$CONFIG" "$SNIPPET" "$BEGIN" "$END" <<'PY'
import pathlib
import re
import sys
import time

config_path = pathlib.Path(sys.argv[1])
snippet_path = pathlib.Path(sys.argv[2])
begin, end = sys.argv[3], sys.argv[4]

text = config_path.read_text()
snip = snippet_path.read_text()
m = re.search(re.escape(begin) + r".*?" + re.escape(end), snip, flags=re.S)
if not m:
    raise SystemExit("bloco LAB não encontrado no snippet")
block = m.group(0).rstrip() + "\n"

text2 = re.sub(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    "",
    text,
    flags=re.S,
)

# Reason: inserir DENTRO de model_list (fim da secção), não antes de general_settings.
ml = re.search(r"(?m)^model_list:\s*$", text2)
if not ml:
    raise SystemExit("model_list: não encontrado no config")
rest = text2[ml.end() :]
# Próxima chave top-level (col 0) após model_list — se existir
nxt = re.search(r"(?m)^[a-zA-Z_][\w-]*:", rest)
if nxt:
    insert_at = ml.end() + nxt.start()
    text2 = text2[:insert_at] + "\n" + block + text2[insert_at:]
else:
    text2 = text2.rstrip() + "\n\n" + block + "\n"

bak = config_path.with_name(
    config_path.name + f".bak.auth2api.{time.strftime('%Y%m%d%H%M%S')}"
)
bak.write_text(text)
config_path.write_text(text2)
print(f"Backup: {bak}")
print(f"Inject OK: {begin} … {end}")
PY

# LiteLLM precisa das vars no container — compose usa env_file
(cd "$LITELLM_DIR" && docker compose up -d litellm-proxy)
sleep 5

echo
echo "=== LAB auth2api → LiteLLM (${LITELLM_DIR}) ==="
echo "BASE: $BASE_URL"
echo "Smoke: bash $ROOT/scripts/auth2api/smoke-litellm-lab.sh"
echo "Disable: bash $ROOT/scripts/auth2api/disable-litellm-lab.sh"

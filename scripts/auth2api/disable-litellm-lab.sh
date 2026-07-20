#!/usr/bin/env bash
# Remove bloco AUTH2API_LAB do LiteLLM local /opt/litellm (mantém .env keys).
set -euo pipefail

LITELLM_DIR="${LITELLM_OPT_DIR:-/opt/litellm}"
CONFIG="${LITELLM_DIR}/config.yaml"
BEGIN="# >>> AUTH2API_LAB_BEGIN"
END="# <<< AUTH2API_LAB_END"

if [[ ! -f "$CONFIG" ]]; then
  echo "Sem $CONFIG" >&2
  exit 1
fi

python3 - "$CONFIG" "$BEGIN" "$END" <<'PY'
import pathlib, re, sys, time
path = pathlib.Path(sys.argv[1])
begin, end = sys.argv[2], sys.argv[3]
text = path.read_text()
new, n = re.subn(
    re.escape(begin) + r".*?" + re.escape(end) + r"\n?",
    "",
    text,
    flags=re.S,
)
if n == 0:
    print("Nenhum bloco AUTH2API_LAB encontrado — noop")
else:
    bak = path.with_name(path.name + f".bak.auth2api-off.{time.strftime('%Y%m%d%H%M%S')}")
    bak.write_text(text)
    path.write_text(new)
    print(f"Removido ({n}); backup {bak}")
PY

(cd "$LITELLM_DIR" && docker compose up -d litellm-proxy)
echo "OK: lab auth2api desligado do model_list"

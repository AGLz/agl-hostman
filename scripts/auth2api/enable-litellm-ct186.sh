#!/usr/bin/env bash
# Inject modelos auth2api no LiteLLM canónico CT186 (/opt/agl-litellm).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
SNIPPET="$ROOT/config/litellm/auth2api-lab-snippet.yaml"
CT186_SSH="${LITELLM_SSH_HOST:-root@100.125.249.8}"
REMOTE_DIR="${LITELLM_REMOTE_DIR:-/opt/agl-litellm}"
# Canónico: auth2api no CT186 (mesma rede docker). Lab agldv04 só com AUTH2API_BASE_URL override.
BASE_URL="${AUTH2API_BASE_URL:-http://agl-auth2api:8317/v1}"
# Health a partir deste host (Tailscale CT186); dentro do proxy usa agl-auth2api.
HOST_HEALTH_URL="${AUTH2API_HEALTH_URL:-http://100.125.249.8:8317/health}"
PROXY_HEALTH_URL="${AUTH2API_PROXY_HEALTH_URL:-http://agl-auth2api:8317/health}"
BEGIN="# >>> AUTH2API_LAB_BEGIN"
END="# <<< AUTH2API_LAB_END"

# shellcheck disable=SC1091
set -a
source "$AUTH_DIR/.env"
set +a
[[ -n "${AUTH2API_API_KEY:-}" ]] || { echo "AUTH2API_API_KEY em falta" >&2; exit 1; }
[[ -f "$SNIPPET" ]] || { echo "snippet em falta" >&2; exit 1; }

if ! curl -fsS -m 8 "$HOST_HEALTH_URL" >/dev/null; then
  echo "auth2api inacessível em $HOST_HEALTH_URL (deploy CT186 primeiro?)" >&2
  exit 1
fi

BLOCK_TMP="$(mktemp)"
REMOTE_PY="$(mktemp)"
trap 'rm -f "$BLOCK_TMP" "$REMOTE_PY"' EXIT

python3 - "$SNIPPET" "$BEGIN" "$END" "$BLOCK_TMP" <<'PY'
import pathlib, re, sys
snip, begin, end, out = sys.argv[1:5]
text = pathlib.Path(snip).read_text()
m = re.search(re.escape(begin) + r".*?" + re.escape(end), text, flags=re.S)
if not m:
    raise SystemExit("bloco LAB não encontrado")
pathlib.Path(out).write_text(m.group(0).rstrip() + "\n")
PY

cat >"$REMOTE_PY" <<'PY'
#!/usr/bin/env python3
import os, pathlib, re, time

remote_dir = pathlib.Path(os.environ["REMOTE_DIR"])
base_url = os.environ["BASE_URL"]
api_key = os.environ["AUTH2API_API_KEY"]
begin = os.environ["BEGIN"]
end = os.environ["END"]
block_path = pathlib.Path("/tmp/auth2api-lab.block")

cfg = remote_dir / "config.yaml"
envf = remote_dir / ".env"
assert cfg.is_file() and envf.is_file(), f"falta {cfg} ou {envf}"

lines = envf.read_text().splitlines()
keys = {"AUTH2API_API_KEY": api_key, "AUTH2API_BASE_URL": base_url}
out_lines, seen = [], set()
for line in lines:
    hit = False
    for k, v in keys.items():
        if line.startswith(k + "="):
            out_lines.append(f"{k}={v}")
            seen.add(k)
            hit = True
            break
    if not hit:
        out_lines.append(line)
for k, v in keys.items():
    if k not in seen:
        out_lines.append(f"{k}={v}")
envf.write_text("\n".join(out_lines).rstrip() + "\n")
print("env OK")

block = block_path.read_text().rstrip() + "\n"
text = cfg.read_text()
text2 = re.sub(re.escape(begin) + r".*?" + re.escape(end) + r"\n?", "", text, flags=re.S)
ml = re.search(r"(?m)^model_list:\s*$", text2)
if not ml:
    raise SystemExit("model_list: não encontrado")
rest = text2[ml.end() :]
nxt = re.search(r"(?m)^[a-zA-Z_][\w-]*:", rest)
if nxt:
    insert_at = ml.end() + nxt.start()
    text2 = text2[:insert_at] + "\n" + block + text2[insert_at:]
else:
    text2 = text2.rstrip() + "\n\n" + block + "\n"
bak = cfg.with_name(cfg.name + f".bak.auth2api.{time.strftime('%Y%m%d%H%M%S')}")
bak.write_text(text)
cfg.write_text(text2)
print(f"Backup {bak}")
print("config written")
PY

scp -o StrictHostKeyChecking=accept-new "$BLOCK_TMP" "${CT186_SSH}:/tmp/auth2api-lab.block"
scp -o StrictHostKeyChecking=accept-new "$REMOTE_PY" "${CT186_SSH}:/tmp/auth2api-enable-ct186.py"

ssh -o StrictHostKeyChecking=accept-new "$CT186_SSH" \
  "export REMOTE_DIR='$REMOTE_DIR' BASE_URL='$BASE_URL' AUTH2API_API_KEY='$AUTH2API_API_KEY' BEGIN='$BEGIN' END='$END'; \
   python3 /tmp/auth2api-enable-ct186.py && \
   cd '$REMOTE_DIR' && docker compose up -d --force-recreate litellm-proxy && sleep 15 && \
   docker exec litellm-proxy python -c \"import yaml; yaml.safe_load(open('/app/config.yaml')); print('yaml ok')\" && \
   docker exec litellm-proxy python -c \"import urllib.request; print(urllib.request.urlopen('${PROXY_HEALTH_URL}', timeout=8).read())\""

echo "OK enable CT186. Modelos: auth2api-claude-fable-5|sonnet|opus|haiku|gpt-5.5|gpt-5.4|gpt-5.6|gpt-codex"

#!/usr/bin/env bash
# Sincroniza EXA_API_KEY e FIRECRAWL_API_KEY nos hosts AGLDV* + CT188 Hermes + makemoney01/.env
# Uso: EXA_API_KEY=... FIRECRAWL_API_KEY=... bash scripts/makemoney/sync-video-api-keys-agldv.sh
set -euo pipefail

EXA_API_KEY="${EXA_API_KEY:?defina EXA_API_KEY}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:?defina FIRECRAWL_API_KEY}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
MARKER="# --- makemoney01 research APIs (Exa/Firecrawl) ---"
ZSHRC_BLOCK="${MARKER}
export EXA_API_KEY=\"${EXA_API_KEY}\"
export FIRECRAWL_API_KEY=\"${FIRECRAWL_API_KEY}\"
"

SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=15 -o StrictHostKeyChecking=accept-new)
# Tailscale proxy quando disponível
if command -v tailscale >/dev/null 2>&1; then
  SSH_OPTS=(-o "ProxyCommand=tailscale nc %h %p" "${SSH_OPTS[@]}")
fi

declare -A AGLDV_HOSTS=(
  [agldv03]="100.94.221.87"
  [agldv04]="100.113.9.98"
  [agldv05]="100.82.71.49"
  [agldv06]="100.71.229.12"
  [agldv12]="100.71.217.115"
)

patch_zshrc_local() {
  local zshrc="${1:-$HOME/.zshrc}"
  touch "$zshrc"
  if grep -qF "$MARKER" "$zshrc" 2>/dev/null; then
    python3 - "$zshrc" "$EXA_API_KEY" "$FIRECRAWL_API_KEY" "$MARKER" <<'PY'
import re, sys
path, exa, fc, marker = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
block = f'{marker}\nexport EXA_API_KEY="{exa}"\nexport FIRECRAWL_API_KEY="{fc}"\n'
pat = re.compile(re.escape(marker) + r".*?(?=\n# |\nexport [A-Z_]+=|\Z)", re.S)
if pat.search(text):
    text = pat.sub(block.rstrip() + "\n", text, count=1)
else:
    text = text.rstrip() + "\n\n" + block
open(path, "w", encoding="utf-8").write(text)
print(f"OK: {path} (updated block)")
PY
  else
    printf '\n%s' "$ZSHRC_BLOCK" >> "$zshrc"
    echo "OK: $zshrc (appended block)"
  fi
}

patch_env_file() {
  local file="$1"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  for kv in "EXA_API_KEY=${EXA_API_KEY}" "FIRECRAWL_API_KEY=${FIRECRAWL_API_KEY}"; do
    key="${kv%%=*}"
    if grep -q "^${key}=" "$file" 2>/dev/null; then
      sed -i "s|^${key}=.*|${kv}|" "$file"
    else
      echo "$kv" >> "$file"
    fi
  done
  echo "OK: $file"
}

echo "=== makemoney01/.env ==="
patch_env_file "${MAKEMONEY_DIR}/.env"

echo "=== localhost .zshrc ==="
patch_zshrc_local "$HOME/.zshrc"

for name in "${!AGLDV_HOSTS[@]}"; do
  ip="${AGLDV_HOSTS[$name]}"
  echo "=== ${name} (${ip}) .zshrc ==="
  if ! ssh "${SSH_OPTS[@]}" "root@${ip}" "hostname -s" 2>/dev/null; then
    echo "WARN: skip ${name} (SSH falhou)"
    continue
  fi
  ssh "${SSH_OPTS[@]}" "root@${ip}" "bash -s" "$EXA_API_KEY" "$FIRECRAWL_API_KEY" <<'REMOTE'
set -euo pipefail
EXA_API_KEY="$1"
FIRECRAWL_API_KEY="$2"
MARKER="# --- makemoney01 research APIs (Exa/Firecrawl) ---"
ZSHRC="/root/.zshrc"
touch "$ZSHRC"
python3 - "$ZSHRC" "$EXA_API_KEY" "$FIRECRAWL_API_KEY" "$MARKER" <<'PY'
import re, sys
path, exa, fc, marker = sys.argv[1:5]
text = open(path, encoding="utf-8").read()
block = f'{marker}\nexport EXA_API_KEY="{exa}"\nexport FIRECRAWL_API_KEY="{fc}"\n'
pat = re.compile(re.escape(marker) + r".*?(?=\n# |\nexport [A-Z_]+=|\Z)", re.S)
if marker in text:
    text = pat.sub(block.rstrip() + "\n", text, count=1)
else:
    text = text.rstrip() + "\n\n" + block
open(path, "w", encoding="utf-8").write(text)
print(f"OK: {path}")
PY
REMOTE
done

echo "=== CT188 Hermes /opt/agl-hermes/data/.env ==="
if ssh "${SSH_OPTS[@]}" root@100.107.113.33 "pct exec 188 -- true" 2>/dev/null; then
  ssh "${SSH_OPTS[@]}" root@100.107.113.33 "pct exec 188 -- bash -s" "$EXA_API_KEY" "$FIRECRAWL_API_KEY" <<'CT188'
set -euo pipefail
ENV=/opt/agl-hermes/data/.env
touch "$ENV"
for kv in "EXA_API_KEY=$1" "FIRECRAWL_API_KEY=$2"; do
  key="${kv%%=*}"
  val="${kv#*=}"
  if grep -q "^${key}=" "$ENV" 2>/dev/null; then
    sed -i "s|^${key}=.*|${key}=${val}|" "$ENV"
  else
    echo "${key}=${val}" >> "$ENV"
  fi
done
grep -E '^(EXA|FIRECRAWL)_API_KEY=' "$ENV" | sed 's/=.*/=SET/'
docker restart agl-hermes-jarvis >/dev/null && echo "OK: agl-hermes-jarvis restarted"
CT188
else
  echo "WARN: CT188 SSH falhou — keys só em AGLDV* + makemoney01"
fi

echo "=== Verificação local makemoney01 ==="
cd "${MAKEMONEY_DIR}" && EXA_API_KEY="${EXA_API_KEY}" FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY}" \
  python3 scripts/check_video_apis.py || true

echo "Done."

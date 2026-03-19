#!/usr/bin/env bash
# Patch ~/.zshrc em cada host com bloco Claude-Flow + LiteLLM (source + cclitellm)
# Uso: ./scripts/ruflo/patch-zshrc-all-hosts.sh [host1 host2 ...]
# Sem args: patch em agldv04, agldv12, fgsrv06 (agldv03 = host atual, já tem)
# Ref: docs/CLAUDE-FLOW-LITELLM.md

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCH_FILE="$REPO_ROOT/scripts/ruflo/zshrc-claude-flow-block.txt"

# Gerar arquivo de patch se não existir
if [[ ! -f "$PATCH_FILE" ]]; then
  cat > "$PATCH_FILE" << 'ENDBLOCK'

# Claude-Flow + LiteLLM (agl-hostman) — source e cclitellm com key dinâmica
for _cf_root in "$WORKSPACE_FOLDER" "$DEVPOD_WORKSPACE_FOLDER" "/mnt/overpower/apps/dev/agl/agl-hostman" "/workspaces/agl-hostman"; do
  [[ -n "$_cf_root" && -f "$_cf_root/config/openclaw/zshrc-openclaw.env" ]] && source "$_cf_root/config/openclaw/zshrc-openclaw.env" && cclitellm && break
done
ENDBLOCK
fi

MARKER="Claude-Flow + LiteLLM (agl-hostman)"

declare -A HOST_IPS
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

[[ $# -gt 0 ]] && TARGETS=("$@") || TARGETS=(agldv04 agldv12 fgsrv06)

echo "=============================================="
echo "  Patch ~/.zshrc — Claude-Flow + LiteLLM"
echo "=============================================="
echo "Hosts: ${TARGETS[*]}"
echo ""

for host in "${TARGETS[@]}"; do
  ip="${HOST_IPS[$host]:-}"
  if [[ -z "$ip" ]]; then
    echo "  WARN: host '$host' desconhecido, ignorando"
    continue
  fi

  echo "=== $host ($ip) ==="
  result=$(scp -q "$PATCH_FILE" "root@${ip}:/tmp/zshrc-block.txt" 2>/dev/null && \
    ssh "root@${ip}" "
      if grep -qF '$MARKER' ~/.zshrc 2>/dev/null; then
        echo 'SKIP: bloco já existe'
      else
        cat /tmp/zshrc-block.txt >> ~/.zshrc
        echo 'OK: bloco adicionado'
      fi
      rm -f /tmp/zshrc-block.txt
    " 2>&1) || result="ERR: falha SSH/scp"
  echo "  $result"
  echo ""
done

echo "=============================================="
echo "  Patch concluído"
echo "=============================================="
echo ""
echo "Em cada host: source ~/.zshrc ou abra novo terminal"
echo ""

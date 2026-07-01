#!/usr/bin/env bash
# Sync Claude Flow / Ruflo / Claude Code config para todos os hosts
# Uso: ./scripts/ruflo/sync-config-all-hosts.sh [host1 host2 ...]
# Sem args: sync para agldv02, agldv03, agldv04, agldv05, agldv06, agldv07, agldv12, fgsrv06
# Ref: docs/CLAUDE-FLOW-CONFIG.md

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_PATH_REMOTE="/mnt/overpower/apps/dev/agl/agl-hostman"

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

# Hosts alvo (default: todos)
[[ $# -gt 0 ]] && TARGETS=("$@") || TARGETS=(agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12 fgsrv06)

echo "=============================================="
echo "  Claude Flow / Ruflo — Sync Config → Hosts"
echo "=============================================="
echo "Repo local: $REPO_ROOT"
echo "Repo remoto: $REPO_PATH_REMOTE"
echo "Hosts: ${TARGETS[*]}"
echo ""

# Arquivos/dirs a replicar (mesma config em todos os hosts)
SYNC_ITEMS=(
  ".claude/settings.json"
  ".claude/settings.litellm.json"
  ".claude/plugins.json"
  ".claude/helpers"
  "config/ruflo"
  "config/openclaw/zshrc-openclaw.env"
  "config/openclaw/zshrc-openclaw-litellm.env"
  "config/templates/claude-code"
  "scripts/ruflo"
  "scripts/ccll.sh"
)

for host in "${TARGETS[@]}"; do
  ip="${HOST_IPS[$host]:-}"
  if [[ -z "$ip" ]]; then
    echo "  WARN: host '$host' desconhecido, ignorando"
    continue
  fi

  echo "=== $host ($ip) ==="

  ssh "root@${ip}" "mkdir -p $REPO_PATH_REMOTE/config/ruflo $REPO_PATH_REMOTE/config/openclaw $REPO_PATH_REMOTE/scripts/ruflo $REPO_PATH_REMOTE/.claude/helpers"

  for item in "${SYNC_ITEMS[@]}"; do
    src="$REPO_ROOT/$item"
    if [[ ! -e "$src" ]]; then
      echo "  WARN: $item não encontrado"
      continue
    fi
    if [[ -d "$src" ]]; then
      parent="$REPO_PATH_REMOTE/$(dirname "$item")"
      ssh "root@${ip}" "mkdir -p $parent"
      scp -rq "$src" "root@${ip}:$parent/"
    else
      ssh "root@${ip}" "mkdir -p $REPO_PATH_REMOTE/$(dirname "$item")"
      scp -q "$src" "root@${ip}:$REPO_PATH_REMOTE/$item"
    fi
    echo "  OK: $item"
  done

  echo ""
done

echo "=============================================="
echo "  Sync concluído"
echo "=============================================="
echo ""
echo "Claude Code shell (ccll/ccs/CC_PROVIDER):"
echo "  ./scripts/ruflo/propagate-claude-code-shell-all-hosts.sh"
echo ""
echo "LiteLLM: gateway CT186 (100.125.249.8:4000) + apiKeyHelper get-litellm-key.sh"
echo "  settings-litellm.json em ~/.claude/ (não exportar ANTHROPIC_* no shell)"
echo ""

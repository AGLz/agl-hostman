#!/usr/bin/env bash
# Deploy completo Ruflo/Claude-Flow avançado
# Roadmap: 3-tier router, RuVector, Background workers, Hive Mind, ReasoningBank
# Uso: ./scripts/ruflo-deploy-agldv03.sh [host]
#   host: root@100.94.221.87 (agldv03), root@100.113.9.98 (agldv04), root@100.71.217.115 (agldv12), root@100.83.51.9 (fgsrv06), ou "local"
# Sync config para todos: ./scripts/ruflo/sync-config-all-hosts.sh
# Repo remoto: /mnt/overpower/apps/dev/agl/agl-hostman

set -e
TARGET="${1:-root@100.94.221.87}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts/ruflo"
REPO_PATH_REMOTE="/mnt/overpower/apps/dev/agl/agl-hostman"

echo "=============================================="
echo "  Ruflo Advanced Deploy"
echo "=============================================="
echo "Host: $TARGET"
echo "Repo local: $REPO_ROOT"
echo "Repo remoto: $REPO_PATH_REMOTE"
echo ""

# Verificar se estamos no repo ou se precisamos sync
if [[ "$TARGET" != "local" ]] && [[ -n "$TARGET" ]]; then
  echo "=== Sincronizando config para $TARGET ==="
  ssh "$TARGET" "mkdir -p $REPO_PATH_REMOTE/config/ruflo $REPO_PATH_REMOTE/scripts/ruflo"
  scp -r "$REPO_ROOT/config/ruflo/"* "$TARGET:$REPO_PATH_REMOTE/config/ruflo/" 2>/dev/null || true
  scp "$REPO_ROOT/scripts/ruflo/"*.sh "$TARGET:$REPO_PATH_REMOTE/scripts/ruflo/" 2>/dev/null || true
  echo "  OK: config e scripts copiados"
  echo ""
fi

# Executar cada passo
for step in validate-ruflo setup-ruvector setup-background-workers setup-hive-mind setup-reasoningbank; do
  echo ">>> Executando: $step"
  SCRIPT="$SCRIPTS_DIR/${step}.sh"
  if [[ -f "$SCRIPT" ]]; then
    if [[ "$TARGET" == "local" ]] || [[ -z "$TARGET" ]]; then
      bash "$SCRIPT"
    else
      ssh "$TARGET" "cd $REPO_PATH_REMOTE 2>/dev/null || cd /tmp; bash scripts/ruflo/${step}.sh"
    fi
  else
    echo "  WARN: $SCRIPT não encontrado"
  fi
  echo ""
done

echo "=============================================="
echo "  Deploy concluído"
echo "=============================================="
echo ""
echo "Próximos passos em $TARGET:"
echo "  1. source ~/.openclaw/zshrc-openclaw.env"
echo "  2. npx ruflo@latest hooks intel route \"sua tarefa\" --top-k 3"
echo "  3. npx ruflo@latest hive-mind spawn \"Build API\" --queen-type tactical"
echo "  4. npx claude-flow@alpha memory status --reasoningbank"
echo ""
echo "Sync config para todos os hosts: ./scripts/ruflo/sync-config-all-hosts.sh"
echo "Documentação: docs/CLAUDE-FLOW-CONFIG.md, docs/RUFLO-ADVANCED.md"

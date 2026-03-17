#!/usr/bin/env bash
# Deploy completo Ruflo/Claude-Flow avançado em agldv03
# Roadmap: 3-tier router, RuVector, Background workers, Hive Mind, ReasoningBank
# Uso: ./scripts/ruflo-deploy-agldv03.sh [host]
# Host default: root@100.94.221.87 (agldv03)
# Repo em agldv03: /mnt/overpower/apps/dev/agl/agl-hostman (mesma pasta)

set -e
AGLDV03="${1:-root@100.94.221.87}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts/ruflo"
REPO_PATH_REMOTE="/mnt/overpower/apps/dev/agl/agl-hostman"

echo "=============================================="
echo "  Ruflo Advanced Deploy - agldv03"
echo "=============================================="
echo "Host: $AGLDV03"
echo "Repo local: $REPO_ROOT"
echo "Repo remoto: $REPO_PATH_REMOTE"
echo ""

# Verificar se estamos no repo ou se precisamos sync
if [[ "$AGLDV03" != "local" ]] && [[ -n "$AGLDV03" ]]; then
  echo "=== Sincronizando config para $AGLDV03 ==="
  ssh "$AGLDV03" "mkdir -p $REPO_PATH_REMOTE/config/ruflo $REPO_PATH_REMOTE/scripts/ruflo"
  scp -r "$REPO_ROOT/config/ruflo/"* "$AGLDV03:$REPO_PATH_REMOTE/config/ruflo/" 2>/dev/null || true
  scp "$REPO_ROOT/scripts/ruflo/"*.sh "$AGLDV03:$REPO_PATH_REMOTE/scripts/ruflo/" 2>/dev/null || true
  echo "  OK: config e scripts copiados"
  echo ""
fi

# Executar cada passo
for step in validate-ruflo setup-ruvector setup-background-workers setup-hive-mind setup-reasoningbank; do
  echo ">>> Executando: $step"
  SCRIPT="$SCRIPTS_DIR/${step}.sh"
  if [[ -f "$SCRIPT" ]]; then
    if [[ "$AGLDV03" == "local" ]] || [[ -z "$AGLDV03" ]]; then
      bash "$SCRIPT"
    else
      ssh "$AGLDV03" "cd $REPO_PATH_REMOTE 2>/dev/null || cd /tmp; bash scripts/ruflo/${step}.sh"
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
echo "Próximos passos em agldv03:"
echo "  1. source ~/.openclaw/zshrc-openclaw.env"
echo "  2. npx ruflo@latest hooks intel route \"sua tarefa\" --top-k 3"
echo "  3. npx ruflo@latest hive-mind spawn \"Build API\" --queen-type tactical"
echo "  4. npx claude-flow@alpha memory status --reasoningbank"
echo ""
echo "Documentação: docs/RUFLO-ADVANCED.md"

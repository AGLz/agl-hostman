#!/usr/bin/env bash
# Deploy IS_SANDBOX + --dangerously-skip-permissions para todos os AGLDV*
# Uso: ./scripts/ruflo/deploy-is-sandbox-all-hosts.sh [host1 host2 ...]
# Executar de agldv03 (ou host com .zshrc e .claude/settings.json atualizados)

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_ZSHRC="${SOURCE_ZSHRC:-/root/.zshrc}"
SOURCE_CLAUDE_SETTINGS="${SOURCE_CLAUDE_SETTINGS:-/root/.claude/settings.json}"

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

[[ $# -gt 0 ]] && TARGETS=("$@") || TARGETS=(agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12 fgsrv06)

echo "=============================================="
echo "  Deploy IS_SANDBOX → Hosts"
echo "=============================================="
echo "Source .zshrc: $SOURCE_ZSHRC"
echo "Source .claude/settings.json: $SOURCE_CLAUDE_SETTINGS"
echo "Hosts: ${TARGETS[*]}"
echo ""

# Verificar arquivos fonte
[[ ! -f "$SOURCE_ZSHRC" ]] && { echo "ERRO: $SOURCE_ZSHRC não encontrado"; exit 1; }
[[ ! -f "$SOURCE_CLAUDE_SETTINGS" ]] && { echo "ERRO: $SOURCE_CLAUDE_SETTINGS não encontrado"; exit 1; }

for host in "${TARGETS[@]}"; do
  ip="${HOST_IPS[$host]:-}"
  if [[ -z "$ip" ]]; then
    echo "  WARN: host '$host' desconhecido, ignorando"
    continue
  fi

  echo "=== $host ($ip) ==="

  # Backup + deploy
  result=$(ssh -o ConnectTimeout=10 "root@${ip}" "
    set -e
    TS=\$(date +%Y%m%d_%H%M%S)
    # Backup
    [[ -f ~/.zshrc ]] && cp ~/.zshrc ~/.zshrc.backup.\$TS
    mkdir -p ~/.claude
    [[ -f ~/.claude/settings.json ]] && cp ~/.claude/settings.json ~/.claude/settings.json.backup.\$TS
    echo 'Backup: .zshrc and .claude/settings.json'
  " 2>&1) || { echo "  ERRO: $result"; continue; }

  # SCP .zshrc
  scp -q "$SOURCE_ZSHRC" "root@${ip}:~/.zshrc" && echo "  OK: .zshrc" || echo "  ERRO: .zshrc"

  # SCP .claude/settings.json
  scp -q "$SOURCE_CLAUDE_SETTINGS" "root@${ip}:~/.claude/settings.json" && echo "  OK: .claude/settings.json" || echo "  ERRO: .claude/settings.json"

  # Verificar IS_SANDBOX no .zshrc
  ssh "root@${ip}" "grep -q 'IS_SANDBOX' ~/.zshrc && echo '  OK: IS_SANDBOX presente' || echo '  WARN: IS_SANDBOX não encontrado'"

  echo ""
done

echo "=============================================="
echo "  Sync config do repo (devpods, .claude do projeto)"
echo "=============================================="
"$REPO_ROOT/scripts/ruflo/sync-config-all-hosts.sh" "${TARGETS[@]}" 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Deploy concluído"
echo "=============================================="
echo "Em cada host: source ~/.zshrc ou abra novo terminal"
echo ""

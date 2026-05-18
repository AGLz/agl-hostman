#!/usr/bin/env bash
# Deploy OpenClaw config com OpenRouter como PRIMÁRIO (todos FREE)
# Solução temporária para problema com DashScope 401
# Uso: ./scripts/deploy-openclaw-openrouter-primary.sh
# Requer: jq, ssh acesso aos hosts remotos

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/openclaw/openclaw-openrouter-primary.json"

# Hosts com OpenClaw
HOSTS=(
  "root@100.94.221.87"   # agldv03 (CT179)
  "root@100.83.51.9"     # fgsrv6
)

OPENCLAW_REMOTE="~/.openclaw/openclaw.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Erro: $CONFIG_FILE não encontrado"
  exit 1
fi

# --- Verificar variáveis de ambiente necessárias ---
echo "=== Verificando variáveis de ambiente ==="
MISSING_VARS=""

# Verificar OPENROUTER_API_KEY (modelos gratuitos)
if [[ -z "$OPENROUTER_API_KEY" ]]; then
  MISSING_VARS="$MISSING_VARS OPENROUTER_API_KEY"
fi

if [[ -n "$MISSING_VARS" ]]; then
  echo "⚠️  ATENÇÃO: Variáveis não definidas:$MISSING_VARS"
  echo "   Configure-as antes de executar este script:"
  echo ""
  echo "   export OPENROUTER_API_KEY='sua-chave-openrouter'"
  echo ""
  echo "   Obter chave:"
  echo "   - OpenRouter: https://openrouter.ai/keys"
  echo ""
  read -p "   Continuar mesmo assim? (y/N): " CONTINUE
  if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
    echo "   Cancelado."
    exit 1
  fi
fi

# --- Deploy LOCAL ---
echo ""
echo "=== Deploy LOCAL (OpenRouter Primário) ==="
mkdir -p "$HOME/.openclaw"
cp "$CONFIG_FILE" "$HOME/.openclaw/openclaw.json"
echo "  OK: openclaw.json (OpenRouter Primário)"

# Criar environment file
cat > "$HOME/.openclaw/openclaw-openrouter.env" <<ENV_EOF
# OpenClaw OpenRouter Primary Environment
# Configurado por: deploy-openclaw-openrouter-primary.sh

# OpenRouter (modelos :free)
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
ENV_EOF

# Criar environment file para systemd
mkdir -p "$HOME/.config/environment.d"
cat > "$HOME/.config/environment.d/openclaw.conf" <<ENV_EOF
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
ENV_EOF

echo "  OK: Environment criado"

# --- Deploy REMOTO ---
for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== Deploy em $host (OpenRouter Primário) ==="

  # 0. Testar conectividade primeiro
  if ! timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" "echo 'OK'" 2>/dev/null; then
    echo "  ⚠️  Host inacessível (pulando)"
    continue
  fi

  # 1. Copiar configuração OpenClaw
  echo "  Copiando openclaw.json..."
  ssh "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true
  scp "$CONFIG_FILE" "$host:$OPENCLAW_REMOTE" 2>/dev/null

  # 2. Criar environment file remoto
  echo "  Criando environment file..."
  ssh "$host" "mkdir -p ~/.config/environment.d && cat > ~/.config/environment.d/openclaw.conf" <<ENV_EOF
OPENROUTER_API_KEY=${OPENROUTER_API_KEY}
ENV_EOF

  # 3. Reiniciar gateway
  echo "  Reiniciando gateway..."
  ssh "$host" "systemctl --user restart openclaw-gateway" 2>/dev/null || true

  echo "  OK: $host (OpenRouter Primário)"
done

echo ""
echo "=== Concluído (OpenRouter Primário) ==="
echo ""
echo "✅ OpenClaw configurado com OpenRouter como PRIMÁRIO"
echo ""
echo "Modelos GRATUITOS configurados:"
echo "  PRIMÁRIO:"
echo "    1. Llama 3.3 70B (OpenRouter :free) - 64K ctx"
echo ""
echo "  FALLBACKS:"
echo "    2. Nemotron 3 Super 120B (OpenRouter :free) - 262K ctx"
echo "    3. MiniMax M2.5 (OpenRouter :free) - 196K ctx"
echo "    4. Gemma 3 27B (OpenRouter :free) - 131K ctx"
echo "    5. Mistral Small 3.1 24B (OpenRouter :free)"
echo "    6. Hermes 3 405B (OpenRouter :free)"
echo ""
echo "📋 Próximos passos:"
echo "   1. Testar: openclaw agent -m 'Hello' --to +15550000000"
echo "   2. Verificar logs: journalctl --user -u openclaw-gateway -f"
echo ""
echo "💰 Custo total: \$0/mês (todos FREE)"

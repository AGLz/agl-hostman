#!/usr/bin/env bash
# Deploy OpenClaw config com ACESSO DIRETO aos providers FREE (sem LiteLLM)
# Modelos: GLM-4.7-Flash (ZAI), Qwen (DashScope Singapore), OpenRouter :free
# Uso: ./scripts/deploy-openclaw-direct-providers.sh
# Requer: jq, ssh acesso aos hosts remotos

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/openclaw/openclaw-direct-free-providers.json"

# Hosts com OpenClaw que precisam de acesso DIRETO aos providers
HOSTS=(
  "root@100.94.221.87"   # agldv03 (CT179)
  "root@100.83.51.9"     # fgsrv6
  # "root@100.70.229.12"   # aglwk45 - VM acessível via aglsrv1 + qemu-ga
)

# Hosts especiais (VM via QEMU guest agent)
QEMU_HOSTS=(
  "aglsrv1:vm104"        # aglwk45 via QEMU GA
)

OPENCLAW_REMOTE="~/.openclaw/openclaw.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Erro: $CONFIG_FILE não encontrado"
  exit 1
fi

# --- Verificar variáveis de ambiente necessárias ---
echo "=== Verificando variáveis de ambiente para acesso DIRETO ==="
MISSING_VARS=""

# Verificar ZAI_API_KEY (GLM gratuito)
if [[ -z "$ZAI_API_KEY" ]]; then
  MISSING_VARS="$MISSING_VARS ZAI_API_KEY"
fi

# Verificar DASHSCOPE_API_KEY (Qwen gratuito - Singapore)
if [[ -z "$DASHSCOPE_API_KEY" ]]; then
  MISSING_VARS="$MISSING_VARS DASHSCOPE_API_KEY"
fi

# Verificar OPENROUTER_API_KEY (modelos gratuitos)
if [[ -z "$OPENROUTER_API_KEY" ]]; then
  MISSING_VARS="$MISSING_VARS OPENROUTER_API_KEY"
fi

if [[ -n "$MISSING_VARS" ]]; then
  echo "⚠️  ATENÇÃO: Variáveis não definidas:$MISSING_VARS"
  echo "   Configure-as antes de executar este script:"
  echo ""
  echo "   export ZAI_API_KEY='sua-chave-zai'"
  echo "   export DASHSCOPE_API_KEY='sua-chave-dashscope'"
  echo "   export OPENROUTER_API_KEY='sua-chave-openrouter'"
  echo ""
  echo "   Obter chaves:"
  echo "   - ZAI: https://api.z.ai"
  echo "   - DashScope: https://dashscope.console.aliyun.com/ (região Singapore)"
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
echo "=== Deploy LOCAL (ACESSO DIRETO) ==="
mkdir -p "$HOME/.openclaw"
cp "$CONFIG_FILE" "$HOME/.openclaw/openclaw.json"
echo "  OK: openclaw.json (DIRETO: GLM-4.7-Flash + Qwen + OpenRouter)"

# Criar environment file com as API keys
cat > "$HOME/.openclaw/openclaw-direct.env" <<'ENV_EOF'
# OpenClaw Direct Providers Environment
# Configurado por: deploy-openclaw-direct-providers.sh

# ZAI (GLM gratuito)
export ZAI_API_KEY="${ZAI_API_KEY}"

# DashScope Singapore (Qwen gratuito)
export DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY}"

# OpenRouter (modelos :free)
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
ENV_EOF

# Adicionar source ao .zshrc
ZSHRC_MARKER="# --- OpenClaw Direct Providers env (agl-hostman) ---"
if ! grep -q "$ZSHRC_MARKER" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "$ZSHRC_MARKER" >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/openclaw-direct.env ]] && source ~/.openclaw/openclaw-direct.env' >> "$HOME/.zshrc"
  echo "  OK: vars DIRETO adicionadas ao .zshrc"
else
  echo "  OK: .zshrc já contém as vars DIRETO"
fi

# --- Deploy REMOTO ---
for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== Deploy DIRETO em $host ==="

  # 0. Testar conectividade primeiro
  if ! timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" "echo 'OK'" 2>/dev/null; then
    echo "  ⚠️  Host inacessível (pulando)"
    continue
  fi

  # 1. Copiar configuração OpenClaw
  echo "  Copiando openclaw.json (DIRETO)..."
  ssh "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true
  scp "$CONFIG_FILE" "$host:$OPENCLAW_REMOTE" 2>/dev/null

  # 2. Criar environment file remoto com as API keys
  echo "  Criando environment file..."
  ssh "$host" "cat > ~/.openclaw/openclaw-direct.env" <<ENV_EOF
# OpenClaw Direct Providers Environment
export ZAI_API_KEY="${ZAI_API_KEY}"
export DASHSCOPE_API_KEY="${DASHSCOPE_API_KEY}"
export OPENROUTER_API_KEY="${OPENROUTER_API_KEY}"
ENV_EOF

  # 3. Adicionar source ao .zshrc
  echo "  Verificando .zshrc..."
  if ! ssh "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars DIRETO ao .zshrc..."
    ssh "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/openclaw-direct.env ]] && source ~/.openclaw/openclaw-direct.env' >> ~/.zshrc"
  else
    echo "  .zshrc atualizado (DIRETO)"
  fi

  echo "  OK: $host (DIRETO)"
done

# --- Deploy REMOTO via QEMU Guest Agent ---
for qemu_host in "${QEMU_HOSTS[@]}"; do
  IFS=':' read -r proxmox_host vmid <<< "$qemu_host"

  echo ""
  echo "=== Deploy DIRETO em $vmid via $proxmox_host (QEMU GA) ==="

  # Criar script temporário para aplicar na VM
  cat > /tmp/openclaw-direct-apply.sh <<'SCRIPT_EOF'
#!/bin/bash
set -e
OPENCLAW_REMOTE="/root/.openclaw/openclaw.json"
ZSHRC_MARKER="# --- OpenClaw Direct Providers env (agl-hostman) ---"

# Copiar config
cp /tmp/openclaw-direct-config.json "$OPENCLAW_REMOTE"

# Criar environment file
cat > /root/.openclaw/openclaw-direct.env <<'ENV_EOF'
export ZAI_API_KEY="ZAI_KEY_PLACEHOLDER"
export DASHSCOPE_API_KEY="DASHSCOPE_KEY_PLACEHOLDER"
export OPENROUTER_API_KEY="OPENROUTER_KEY_PLACEHOLDER"
ENV_EOF

# Substituir placeholders com valores reais
sed -i "s/ZAI_KEY_PLACEHOLDER/$ZAI_API_KEY/g" /root/.openclaw/openclaw-direct.env
sed -i "s/DASHSCOPE_KEY_PLACEHOLDER/$DASHSCOPE_API_KEY/g" /root/.openclaw/openclaw-direct.env
sed -i "s/OPENROUTER_KEY_PLACEHOLDER/$OPENROUTER_API_KEY/g" /root/.openclaw/openclaw-direct.env

# Adicionar ao .zshrc
if ! grep -q "$ZSHRC_MARKER" ~/.zshrc 2>/dev/null; then
  echo "" >> ~/.zshrc
  echo "$ZSHRC_MARKER" >> ~/.zshrc
  echo '[[ -f ~/.openclaw/openclaw-direct.env ]] && source ~/.openclaw/openclaw-direct.env' >> ~/.zshrc
fi

echo "OK-VM-DIRECT"
SCRIPT_EOF

  # Substituir as chaves no script
  sed -i "s/ZAI_KEY_PLACEHOLDER/$ZAI_API_KEY/g" /tmp/openclaw-direct-apply.sh
  sed -i "s/DASHSCOPE_KEY_PLACEHOLDER/$DASHSCOPE_API_KEY/g" /tmp/openclaw-direct-apply.sh
  sed -i "s|OPENROUTER_KEY_PLACEHOLDER|$OPENROUTER_API_KEY|g" /tmp/openclaw-direct-apply.sh

  # Copiar arquivos para o Proxmox host
  scp "$CONFIG_FILE" "$proxmox_host:/tmp/openclaw-direct-config.json" 2>/dev/null || true
  scp /tmp/openclaw-direct-apply.sh "$proxmox_host:/tmp/openclaw-direct-apply.sh" 2>/dev/null || true

  # Copiar arquivos para dentro da VM via QEMU
  ssh "$proxmox_host" "qm guest exec $vmid -- mkdir -p /root/.openclaw" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/openclaw-direct-config.json /tmp/openclaw-direct-config.json" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/openclaw-direct-apply.sh /tmp/openclaw-direct-apply.sh" 2>/dev/null || true

  # Executar script de aplicação na VM
  ssh "$proxmox_host" "qm guest exec $vmid -- bash /tmp/openclaw-direct-apply.sh" 2>/dev/null && \
    echo "  OK: $vmid via $proxmox_host (DIRETO)" || \
    echo "  ⚠️  Falha no deploy via QEMU GA (vm pode não ter guest agent rodando)"
done

echo ""
echo "=== Concluído (ACESSO DIRETO) ==="
echo ""
echo "✅ OpenClaw configurado com ACESSO DIRETO aos providers (SEM LiteLLM)"
echo ""
echo "Modelos GRATUITOS configurados:"
echo "  PRIMÁRIO:"
echo "    1. GLM-4.7-Flash (ZAI) - FREE - https://api.z.ai"
echo "    2. Qwen-Coder (DashScope Singapore) - FREE"
echo "    3. Qwen3.5-Plus (DashScope Singapore) - FREE - 1M ctx"
echo "    4. Qwen-Turbo (DashScope Singapore) - FREE"
echo ""
echo "  FALLBACKS (OpenRouter :free):"
echo "    5. Llama 3.3 70B - FREE - 64K ctx"
echo "    6. Nemotron 3 Super - FREE - 262K ctx"
echo "    7. MiniMax M2.5 - FREE - 196K ctx"
echo "    8. Step 3.5 Flash - FREE"
echo "    9. Gemma 3 variants - FREE"
echo "   10. Mistral Small 3.1 - FREE"
echo "   11. Hermes 3 - FREE"
echo ""
echo "⚠️  IMPORTANTE: OpenClaw agora acessa os providers DIRETAMENTE"
echo "   NÃO passa pelo LiteLLM Gateway"
echo ""
echo "📋 Próximos passos:"
echo "   1. Reiniciar sessão ou: source ~/.zshrc"
echo "   2. Testar: openclaw 'Hello' (deve usar GLM-4.7-Flash FREE)"

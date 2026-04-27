#!/usr/bin/env bash
# Deploy OpenClaw config FREE-ONLY (agldv03, fgsrv06, aglwk45)
# Usa apenas modelos gratuitos: GLM-4.7-Flash, Qwen (DashScope Singapore), OpenRouter :free
# Uso: ./scripts/deploy-openclaw-free-config.sh
# Requer: jq, ssh acesso aos hosts remotos

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$REPO_ROOT/config/openclaw/openclaw-free-only.json"
ZSHRC_ENV="$REPO_ROOT/config/openclaw/zshrc-openclaw.env"
LITELLM_LOCAL_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-local.env"
LITELLM_LOCAL_JQ="$REPO_ROOT/config/openclaw/openclaw-litellm-local.jq"

# Hosts com OpenClaw que precisam de FREE-ONLY
HOSTS=(
  "root@100.94.221.87"   # agldv03 (CT179)
  "root@100.83.51.9"     # fgsrv6
  # "root@100.70.229.12"   # aglwk45 - VM acessível via aglsrv1 + qemu-ga
)

# Hosts especiais (VM via QEMU guest agent)
QEMU_HOSTS=(
  "aglsrv1:vm104"        # aglwk45 via QEMU GA
)

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
OPENCLAW_REMOTE="~/.openclaw/openclaw.json"
ZSHRC_MARKER="# --- OpenClaw/LiteLLM FREE env (agl-hostman) ---"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Erro: $PATCH_FILE não encontrado"
  exit 1
fi

# --- Verificar variáveis de ambiente necessárias ---
echo "=== Verificando variáveis de ambiente para FREE TIER ==="
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
echo "=== Deploy LOCAL (FREE-ONLY) ==="
mkdir -p "$HOME/.openclaw"
current=$(cat "$OPENCLAW_CONFIG" 2>/dev/null || echo '{}')
patch=$(cat "$PATCH_FILE")
merged=$({ echo "$current"; echo "$patch"; } | jq -s '.[0] * .[1]' 2>/dev/null) || true
if [[ -n "$merged" ]]; then
  echo "$merged" | jq -f "$LITELLM_LOCAL_JQ" > "$OPENCLAW_CONFIG"
  echo "  OK: openclaw.json (FREE-ONLY: GLM-4.7-Flash + Qwen + OpenRouter :free)"
else
  echo "  Aviso: merge local falhou (jq instalado?)"
fi
cp "$ZSHRC_ENV" "$HOME/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
cp "$LITELLM_LOCAL_ENV" "$HOME/.openclaw/litellm-gateway.env" 2>/dev/null || true
echo "  OK: litellm-gateway.env → localhost:4000 (FREE-ONLY)"
if ! grep -q "$ZSHRC_MARKER" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "$ZSHRC_MARKER" >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> "$HOME/.zshrc"
  echo "  OK: vars FREE adicionadas ao .zshrc"
else
  grep -q 'litellm-gateway.env' "$HOME/.zshrc" 2>/dev/null || \
    sed -i '/zshrc-openclaw.env/i [[ -f ~/.openclaw/litellm-gateway.env ]] \&\& source ~/.openclaw/litellm-gateway.env' "$HOME/.zshrc"
  echo "  OK: .zshrc já contém as vars FREE"
fi

# --- Deploy REMOTO ---
for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== Deploy FREE-ONLY em $host ==="

  # 0. Testar conectividade primeiro
  if ! timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes "$host" "echo 'OK'" 2>/dev/null; then
    echo "  ⚠️  Host inacessível (pulando)"
    continue
  fi

  # 1. Merge OpenClaw config
  echo "  Merging openclaw.json (FREE-ONLY)..."
  ssh "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true

  current=$(ssh "$host" "if [[ -f $OPENCLAW_REMOTE ]]; then cat $OPENCLAW_REMOTE; else echo '{}'; fi" 2>/dev/null) || current="{}"
  patch=$(cat "$PATCH_FILE")

  merged=$({ echo "$current"; echo "$patch"; } | jq -s '.[0] * .[1]' 2>/dev/null) || merged=""

  if [[ -n "$merged" ]]; then
    echo "$merged" | ssh "$host" "cat > $OPENCLAW_REMOTE"
  else
    echo "  Merge local falhou. Tentando merge remoto..."
    scp "$PATCH_FILE" "$host:/tmp/openclaw-patch.json" 2>/dev/null
    ssh "$host" "cp $OPENCLAW_REMOTE ${OPENCLAW_REMOTE}.bak 2>/dev/null; jq -s '.[0] * .[1]' $OPENCLAW_REMOTE /tmp/openclaw-patch.json 2>/dev/null | sponge $OPENCLAW_REMOTE 2>/dev/null || (jq -s '.[0] * .[1]' $OPENCLAW_REMOTE /tmp/openclaw-patch.json > ${OPENCLAW_REMOTE}.new && mv ${OPENCLAW_REMOTE}.new $OPENCLAW_REMOTE)" 2>/dev/null || echo "  Falha - verifique jq no host"
  fi

  # 2. Copiar zshrc + LiteLLM local (cada host com proxy em :4000 usa localhost)
  scp "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  scp "$LITELLM_LOCAL_ENV" "$host:~/.openclaw/litellm-gateway.env" 2>/dev/null || true
  scp -q "$LITELLM_LOCAL_JQ" "$host:/tmp/openclaw-litellm-local.jq" 2>/dev/null || true
  ssh "$host" "if [[ -f ~/.openclaw/openclaw.json ]] && [[ -f /tmp/openclaw-litellm-local.jq ]]; then jq -f /tmp/openclaw-litellm-local.jq ~/.openclaw/openclaw.json > /tmp/oc-litellm.json && mv /tmp/oc-litellm.json ~/.openclaw/openclaw.json && echo OK-openclaw-litellm-local; fi" || true

  # 3. Adicionar source ao .zshrc
  echo "  Verificando .zshrc..."
  if ! ssh "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars FREE ao .zshrc..."
    ssh "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc"
  else
    ssh "$host" "grep -q 'litellm-gateway.env' ~/.zshrc 2>/dev/null || sed -i '/zshrc-openclaw.env/i [[ -f ~\/.openclaw\/litellm-gateway.env ]] \&\& source ~\/.openclaw\/litellm-gateway.env' ~/.zshrc"
    echo "  .zshrc atualizado (FREE)"
  fi

  echo "  OK: $host (FREE-ONLY)"
done

# --- Deploy REMOTO via QEMU Guest Agent ---
for qemu_host in "${QEMU_HOSTS[@]}"; do
  IFS=':' read -r proxmox_host vmid <<< "$qemu_host"

  echo ""
  echo "=== Deploy FREE-ONLY em $vmid via $proxmox_host (QEMU GA) ==="

  # 1. Merge OpenClaw config via QEMU exec
  echo "  Merging openclaw.json (FREE-ONLY) via QEMU GA..."
  ssh "$proxmox_host" "mkdir -p ~/.openclaw" 2>/dev/null || true

  # Executar comandos na VM via QEMU guest agent
  ssh "$proxmox_host" "qm guest exec $vmid -- mkdir -p /root/.openclaw" 2>/dev/null || true

  # Criar script temporário para aplicar na VM
  cat > /tmp/openclaw-free-apply.sh <<'SCRIPT_EOF'
#!/bin/bash
set -e
OPENCLAW_REMOTE="/root/.openclaw/openclaw.json"
ZSHRC_MARKER="# --- OpenClaw/LiteLLM FREE env (agl-hostman) ---"

# Merge config
if [[ -f "$OPENCLAW_REMOTE" ]]; then
  jq -s '.[0] * .[1]' "$OPENCLAW_REMOTE" /tmp/openclaw-patch.json > /tmp/oc-merged.json 2>/dev/null && \
    mv /tmp/oc-merged.json "$OPENCLAW_REMOTE" || echo "merge falhou"
else
  cp /tmp/openclaw-patch.json "$OPENCLAW_REMOTE"
fi

# Aplicar JQ transform
if [[ -f /tmp/openclaw-litellm-local.jq ]]; then
  jq -f /tmp/openclaw-litellm-local.jq "$OPENCLAW_REMOTE" > /tmp/oc-final.json && \
    mv /tmp/oc-final.json "$OPENCLAW_REMOTE"
fi

# Adicionar ao .zshrc
if ! grep -q "$ZSHRC_MARKER" ~/.zshrc 2>/dev/null; then
  echo "" >> ~/.zshrc
  echo "$ZSHRC_MARKER" >> ~/.zshrc
  echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc
  echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc
fi

echo "OK-VM"
SCRIPT_EOF

  # Copiar arquivos para o Proxmox host
  scp "$PATCH_FILE" "$proxmox_host:/tmp/openclaw-patch.json" 2>/dev/null || true
  scp "$LITELLM_LOCAL_JQ" "$proxmox_host:/tmp/openclaw-litellm-local.jq" 2>/dev/null || true
  scp "$ZSHRC_ENV" "$proxmox_host:/tmp/zshrc-openclaw.env" 2>/dev/null || true
  scp "$LITELLM_LOCAL_ENV" "$proxmox_host:/tmp/litellm-gateway.env" 2>/dev/null || true
  scp /tmp/openclaw-free-apply.sh "$proxmox_host:/tmp/openclaw-free-apply.sh" 2>/dev/null || true

  # Copiar arquivos para dentro da VM via QEMU
  ssh "$proxmox_host" "qm guest exec $vmid -- mkdir -p /root/.openclaw" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/openclaw-patch.json /tmp/openclaw-patch.json" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/openclaw-litellm-local.jq /tmp/openclaw-litellm-local.jq" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/zshrc-openclaw.env /root/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/litellm-gateway.env /root/.openclaw/litellm-gateway.env" 2>/dev/null || true
  ssh "$proxmox_host" "qm guest file-upload $vmid /tmp/openclaw-free-apply.sh /tmp/openclaw-free-apply.sh" 2>/dev/null || true

  # Executar script de aplicação na VM
  ssh "$proxmox_host" "qm guest exec $vmid -- bash /tmp/openclaw-free-apply.sh" 2>/dev/null && \
    echo "  OK: $vmid via $proxmox_host (FREE-ONLY)" || \
    echo "  ⚠️  Falha no deploy via QEMU GA (vm pode não ter guest agent rodando)"
done

# --- Gerar environment file e reiniciar gateway OpenClaw ---
echo ""
echo "=== Gerando environment file e reiniciando gateway OpenClaw ==="
SYNC_ENV_SCRIPT="$REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"
for h in 100.94.221.87 100.83.51.9; do
  echo -n "  $h: "
  scp -q "$SYNC_ENV_SCRIPT" "root@$h:/tmp/sync-systemd-openclaw-env.sh"
  ssh "root@$h" 'chmod +x /tmp/sync-systemd-openclaw-env.sh && bash /tmp/sync-systemd-openclaw-env.sh' && echo -n " -> "
  # Reiniciar gateway
  ssh "root@$h" 'systemctl --user daemon-reload && systemctl --user restart openclaw-gateway 2>/dev/null' && echo "gateway OK" || echo "skip"
done

echo ""
echo "=== Concluído (FREE-ONLY) ==="
echo ""
echo "Modelos GRATUITOS configurados:"
echo "  1. GLM-4.7-Flash (ZAI) - FREE"
echo "  2. Qwen-Coder (DashScope Singapore) - FREE"
echo "  3. Qwen3.5-Plus (DashScope Singapore) - FREE"
echo "  4. Qwen-Turbo (DashScope Singapore) - FREE"
echo "  5. Nemotron 3 Super (OpenRouter :free) - 262K ctx"
echo "  6. MiniMax M2.5 (OpenRouter :free) - 196K ctx"
echo "  7. Llama 3.3 70B (OpenRouter :free) - 64K ctx"
echo "  8. Step 3.5 Flash (OpenRouter :free)"
echo "  9. Gemma 3 variants (OpenRouter :free)"
echo "  10. Mistral Small 3.1 (OpenRouter :free)"
echo "  11. Hermes 3 Llama (OpenRouter :free)"
echo "  12. openrouter/free (router inteligente)"
echo ""
echo "⚠️  NOTA: google/gemini-2.5-flash-lite:free foi REMOVIDO"
echo "   pois não está funcionando via OpenRouter."
echo "   Use zai/glm-4.7-flash (FREE) como alternativa."

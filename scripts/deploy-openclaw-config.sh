#!/usr/bin/env bash
# Deploy OpenClaw config + zshrc vars (local + agldv03 + fgsrv6)
# Deploy zshrc-only (multi-models env) em agldv04, agldv05, agldv06 (sem OpenClaw)
# Uso: ./scripts/deploy-openclaw-config.sh
# Requer: jq, ssh acesso aos hosts remotos

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$REPO_ROOT/config/openclaw/openclaw-patch.json"
ZSHRC_ENV="$REPO_ROOT/config/openclaw/zshrc-openclaw.env"
LITELLM_CLIENT_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-client.env"

HOSTS=(
  "root@100.94.221.87"   # agldv03 (CT179)
  "root@100.83.51.9"     # fgsrv6
)

# Hosts sem OpenClaw: apenas zshrc (multi-models env)
ZSHRC_ONLY_HOSTS=(
  "root@100.113.9.98"    # agldv04
  "root@100.119.41.63"   # agldv05
  "root@100.71.229.12"   # agldv06
)

OPENCLAW_CONFIG="$HOME/.openclaw/openclaw.json"
OPENCLAW_REMOTE="~/.openclaw/openclaw.json"
ZSHRC_MARKER="# --- OpenClaw/LiteLLM env (agl-hostman) ---"

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Erro: $PATCH_FILE não encontrado"
  exit 1
fi

# --- Deploy LOCAL ---
echo ""
echo "=== Deploy LOCAL ==="
mkdir -p "$HOME/.openclaw"
current=$(cat "$OPENCLAW_CONFIG" 2>/dev/null || echo '{}')
patch=$(cat "$PATCH_FILE")
merged=$({ echo "$current"; echo "$patch"; } | jq -s '.[0] * .[1]' 2>/dev/null) || true
if [[ -n "$merged" ]]; then
  echo "$merged" > "$OPENCLAW_CONFIG"
  echo "  OK: openclaw.json atualizado"
else
  echo "  Aviso: merge local falhou (jq instalado?)"
fi
cp "$ZSHRC_ENV" "$HOME/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
if ! grep -q "$ZSHRC_MARKER" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "$ZSHRC_MARKER" >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> "$HOME/.zshrc"
  echo "  OK: vars + Claude-Flow multi-model adicionadas ao .zshrc"
else
  grep -q 'litellm-gateway.env' "$HOME/.zshrc" 2>/dev/null || \
    sed -i '/zshrc-openclaw.env/i [[ -f ~/.openclaw/litellm-gateway.env ]] \&\& source ~/.openclaw/litellm-gateway.env' "$HOME/.zshrc"
  echo "  OK: .zshrc já contém as vars (multi-model)"
fi

# --- Deploy REMOTO ---
for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== Deploy em $host ==="
  
  # 1. Merge OpenClaw config
  echo "  Merging openclaw.json..."
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
  
  # 2. Copiar zshrc-openclaw.env para ~/.openclaw/ no host
  scp "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  
  # 3. Adicionar source ao .zshrc (Claude-Flow multi-model)
  echo "  Verificando .zshrc..."
  if ! ssh "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars + multi-model ao .zshrc..."
    ssh "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc"
  else
    ssh "$host" "grep -q 'litellm-gateway.env' ~/.zshrc 2>/dev/null || sed -i '/zshrc-openclaw.env/i [[ -f ~\/.openclaw\/litellm-gateway.env ]] \&\& source ~\/.openclaw\/litellm-gateway.env' ~/.zshrc"
    echo "  .zshrc atualizado (multi-model)"
  fi
  
  echo "  OK: $host"
done

# --- Deploy zshrc-only (hosts sem OpenClaw) ---
for host in "${ZSHRC_ONLY_HOSTS[@]}"; do
  echo ""
  echo "=== Deploy zshrc-only em $host (sem OpenClaw, multi-model via agldv03) ==="
  ssh "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true
  scp "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  scp "$LITELLM_CLIENT_ENV" "$host:~/.openclaw/litellm-gateway.env" 2>/dev/null || true
  if ! ssh "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars + multi-model ao .zshrc..."
    ssh "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc"
  else
    ssh "$host" "grep -q 'litellm-gateway.env' ~/.zshrc 2>/dev/null || sed -i '/zshrc-openclaw.env/i [[ -f ~\/.openclaw\/litellm-gateway.env ]] \&\& source ~\/.openclaw\/litellm-gateway.env' ~/.zshrc"
    echo "  .zshrc atualizado (multi-model)"
  fi
  echo "  OK: $host"
done

# --- Gerar environment file e reiniciar gateway OpenClaw (agldv03 + fgsrv6) ---
echo ""
echo "=== Gerando environment file e reiniciando gateway OpenClaw ==="
for h in 100.94.221.87 100.83.51.9; do
  echo -n "  $h: "
  # Gerar environment file a partir do zshrc
  ssh "root@$h" 'mkdir -p ~/.config/environment.d && grep -h -E "^export (ZAI_API_KEY|GLM_AUTH|GLM_URL|KIMI_AUTH|KIMI_URL|MOONSHOT_API_KEY|DEEPSEEK_API_KEY|DEEPSEEK_AUTH|DEEPSEEK_URL|OPENAI_API_KEY|OPENAI_AUTH|OPENAI_URL|GEMINI_API_KEY|GEMINI_AUTH|GEMINI_URL|OPENROUTER_API_KEY|DASHSCOPE_API_KEY|ANTHROPIC_API_KEY)=" ~/.zshrc ~/.openclaw/zshrc-openclaw.env 2>/dev/null | sed "s/^export //" > ~/.config/environment.d/openclaw.conf; grep -q "ANTHROPIC_API_KEY=" ~/.config/environment.d/openclaw.conf || echo 'ANTHROPIC_API_KEY="sk-optional"' >> ~/.config/environment.d/openclaw.conf; sed -i '\''s/^ANTHROPIC_API_KEY=""$/ANTHROPIC_API_KEY="sk-optional"/'\'' ~/.config/environment.d/openclaw.conf 2>/dev/null; echo "env OK"' && echo -n " -> "
  # Reiniciar gateway
  ssh "root@$h" 'systemctl --user daemon-reload && systemctl --user restart openclaw-gateway 2>/dev/null' && echo "gateway OK" || echo "skip"
done

echo ""
echo "=== Concluído ==="

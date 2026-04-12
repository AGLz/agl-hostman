#!/usr/bin/env bash
# Deploy OpenClaw config + zshrc vars (local + agldv03 + fgsrv6)
# Deploy zshrc-only (multi-models env) em agldv04, agldv05, agldv06 (sem OpenClaw)
#
# Para copiar o openclaw.json *completo* desde agldv03 para satélites (agldv04/05/07/12, fgsrv06)
# sem mexer em ~/.openclaw/cron/ em cada destino, usar:
#   bash scripts/openclaw/propagate-openclaw-from-agldv03.sh
#
# Uso: ./scripts/deploy-openclaw-config.sh
# Requer: jq, ssh acesso aos hosts remotos

set -e
# Reason: SSH direto a IPs Tailscale 100.x pode bloquear no banner; tailscale nc estabiliza.
OPENCLAW_SSH=(ssh -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new)
OPENCLAW_SCP=(scp -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="$REPO_ROOT/config/openclaw/openclaw-patch.json"
ZSHRC_ENV="$REPO_ROOT/config/openclaw/zshrc-openclaw.env"
LITELLM_CLIENT_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-client.env"
LITELLM_LOCAL_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-local.env"
LITELLM_LOCAL_JQ="$REPO_ROOT/config/openclaw/openclaw-litellm-local.jq"

HOSTS=(
  "root@100.94.221.87"   # agldv03 (CT179)
  "root@100.83.51.9"     # fgsrv6 (se timeout: tailscale status; alternativa comum 100.98.108.66)
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
  echo "$merged" | jq -f "$LITELLM_LOCAL_JQ" > "$OPENCLAW_CONFIG"
  echo "  OK: openclaw.json (merge + providers → localhost:4000)"
else
  echo "  Aviso: merge local falhou (jq instalado?)"
fi
cp "$ZSHRC_ENV" "$HOME/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
cp "$LITELLM_LOCAL_ENV" "$HOME/.openclaw/litellm-gateway.env" 2>/dev/null || true
echo "  OK: litellm-gateway.env → localhost:4000 (Claude + OpenClaw)"
if ! grep -q "$ZSHRC_MARKER" "$HOME/.zshrc" 2>/dev/null; then
  echo "" >> "$HOME/.zshrc"
  echo "$ZSHRC_MARKER" >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/litellm-master.secret.env ]] && source ~/.openclaw/litellm-master.secret.env' >> "$HOME/.zshrc"
  echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> "$HOME/.zshrc"
  echo "  OK: vars + Claude-Flow multi-model adicionadas ao .zshrc"
else
  grep -q 'litellm-gateway.env' "$HOME/.zshrc" 2>/dev/null || \
    sed -i '/zshrc-openclaw.env/i [[ -f ~/.openclaw/litellm-gateway.env ]] \&\& source ~/.openclaw/litellm-gateway.env' "$HOME/.zshrc"
  if ! grep -qF 'litellm-master.secret.env' "$HOME/.zshrc" 2>/dev/null; then
    sed -i '/litellm-gateway.env.*source ~\/.openclaw\/litellm-gateway.env/a [[ -f ~/.openclaw/litellm-master.secret.env ]] \&\& source ~/.openclaw/litellm-master.secret.env' "$HOME/.zshrc" 2>/dev/null || true
  fi
  echo "  OK: .zshrc já contém as vars (multi-model)"
fi

# --- Deploy REMOTO ---
for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== Deploy em $host ==="
  
  # 1. Merge OpenClaw config
  echo "  Merging openclaw.json..."
  "${OPENCLAW_SSH[@]}" "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true
  
  current=$("${OPENCLAW_SSH[@]}" "$host" "if [[ -f $OPENCLAW_REMOTE ]]; then cat $OPENCLAW_REMOTE; else echo '{}'; fi" 2>/dev/null) || current="{}"
  patch=$(cat "$PATCH_FILE")
  
  merged=$({ echo "$current"; echo "$patch"; } | jq -s '.[0] * .[1]' 2>/dev/null) || merged=""
  
  if [[ -n "$merged" ]]; then
    echo "$merged" | "${OPENCLAW_SSH[@]}" "$host" "cat > $OPENCLAW_REMOTE"
  else
    echo "  Merge local falhou. Tentando merge remoto..."
    "${OPENCLAW_SCP[@]}" "$PATCH_FILE" "$host:/tmp/openclaw-patch.json" 2>/dev/null
    "${OPENCLAW_SSH[@]}" "$host" "cp $OPENCLAW_REMOTE ${OPENCLAW_REMOTE}.bak 2>/dev/null; jq -s '.[0] * .[1]' $OPENCLAW_REMOTE /tmp/openclaw-patch.json 2>/dev/null | sponge $OPENCLAW_REMOTE 2>/dev/null || (jq -s '.[0] * .[1]' $OPENCLAW_REMOTE /tmp/openclaw-patch.json > ${OPENCLAW_REMOTE}.new && mv ${OPENCLAW_REMOTE}.new $OPENCLAW_REMOTE)" 2>/dev/null || echo "  Falha - verifique jq no host"
  fi
  
  # 2. Copiar zshrc + LiteLLM local (cada host com proxy em :4000 usa localhost)
  "${OPENCLAW_SCP[@]}" "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  "${OPENCLAW_SCP[@]}" "$LITELLM_LOCAL_ENV" "$host:~/.openclaw/litellm-gateway.env" 2>/dev/null || true
  "${OPENCLAW_SCP[@]}" -q "$LITELLM_LOCAL_JQ" "$host:/tmp/openclaw-litellm-local.jq" 2>/dev/null || true
  "${OPENCLAW_SSH[@]}" "$host" "if [[ -f ~/.openclaw/openclaw.json ]] && [[ -f /tmp/openclaw-litellm-local.jq ]]; then jq -f /tmp/openclaw-litellm-local.jq ~/.openclaw/openclaw.json > /tmp/oc-litellm.json && mv /tmp/oc-litellm.json ~/.openclaw/openclaw.json && echo OK-openclaw-litellm-local; fi" || true

  # 3. Adicionar source ao .zshrc (Claude-Flow multi-model)
  echo "  Verificando .zshrc..."
  if ! "${OPENCLAW_SSH[@]}" "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars + multi-model ao .zshrc..."
    "${OPENCLAW_SSH[@]}" "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-master.secret.env ]] && source ~/.openclaw/litellm-master.secret.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc"
  else
    "${OPENCLAW_SSH[@]}" "$host" "grep -q 'litellm-gateway.env' ~/.zshrc 2>/dev/null || sed -i '/zshrc-openclaw.env/i [[ -f ~\/.openclaw\/litellm-gateway.env ]] \&\& source ~\/.openclaw\/litellm-gateway.env' ~/.zshrc"
    "${OPENCLAW_SSH[@]}" "$host" "grep -qF 'litellm-master.secret.env' ~/.zshrc 2>/dev/null || sed -i '/litellm-gateway.env.*source ~\/.openclaw\/litellm-gateway.env/a [[ -f ~/.openclaw/litellm-master.secret.env ]] \&\& source ~/.openclaw/litellm-master.secret.env' ~/.zshrc" 2>/dev/null || true
    echo "  .zshrc atualizado (multi-model)"
  fi
  
  echo "  OK: $host"
done

# --- Deploy zshrc-only (hosts sem OpenClaw) ---
for host in "${ZSHRC_ONLY_HOSTS[@]}"; do
  echo ""
  echo "=== Deploy zshrc-only em $host (sem OpenClaw, multi-model via agldv03) ==="
  "${OPENCLAW_SSH[@]}" "$host" "mkdir -p ~/.openclaw" 2>/dev/null || true
  "${OPENCLAW_SCP[@]}" "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  "${OPENCLAW_SCP[@]}" "$LITELLM_CLIENT_ENV" "$host:~/.openclaw/litellm-gateway.env" 2>/dev/null || true
  if ! "${OPENCLAW_SSH[@]}" "$host" "grep -q '$ZSHRC_MARKER' ~/.zshrc 2>/dev/null"; then
    echo "  Adicionando vars + multi-model ao .zshrc..."
    "${OPENCLAW_SSH[@]}" "$host" "echo '' >> ~/.zshrc && echo '$ZSHRC_MARKER' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-gateway.env ]] && source ~/.openclaw/litellm-gateway.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/litellm-master.secret.env ]] && source ~/.openclaw/litellm-master.secret.env' >> ~/.zshrc && echo '[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env' >> ~/.zshrc"
  else
    "${OPENCLAW_SSH[@]}" "$host" "grep -q 'litellm-gateway.env' ~/.zshrc 2>/dev/null || sed -i '/zshrc-openclaw.env/i [[ -f ~\/.openclaw\/litellm-gateway.env ]] \&\& source ~\/.openclaw\/litellm-gateway.env' ~/.zshrc"
    "${OPENCLAW_SSH[@]}" "$host" "grep -qF 'litellm-master.secret.env' ~/.zshrc 2>/dev/null || sed -i '/litellm-gateway.env.*source ~\/.openclaw\/litellm-gateway.env/a [[ -f ~/.openclaw/litellm-master.secret.env ]] \&\& source ~/.openclaw/litellm-master.secret.env' ~/.zshrc" 2>/dev/null || true
    echo "  .zshrc atualizado (multi-model)"
  fi
  echo "  OK: $host"
done

# --- Gerar environment file e reiniciar gateway OpenClaw (agldv03 + fgsrv6) ---
echo ""
echo "=== Gerando environment file e reiniciando gateway OpenClaw ==="
SYNC_ENV_SCRIPT="$REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"
for h in 100.94.221.87 100.83.51.9; do
  echo -n "  $h: "
  "${OPENCLAW_SCP[@]}" -q "$SYNC_ENV_SCRIPT" "root@$h:/tmp/sync-systemd-openclaw-env.sh"
  "${OPENCLAW_SSH[@]}" "root@$h" 'chmod +x /tmp/sync-systemd-openclaw-env.sh && bash /tmp/sync-systemd-openclaw-env.sh' && echo -n " -> "
  # Reiniciar gateway
  "${OPENCLAW_SSH[@]}" "root@$h" 'systemctl --user daemon-reload && systemctl --user restart openclaw-gateway 2>/dev/null' && echo "gateway OK" || echo "skip"
done

echo ""
echo "=== Concluído ==="

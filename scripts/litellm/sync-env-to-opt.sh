#!/usr/bin/env bash
# Sincroniza chaves de config/litellm/.env para /opt/litellm/.env
# Atualiza apenas vars não vazias no destino (preserva LITELLM_MASTER_KEY se já configurado)
# Uso: ./scripts/litellm/sync-env-to-opt.sh
# Requer: sudo para escrever em /opt/litellm/

set -e
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SRC="$REPO_ROOT/config/litellm/.env"
DEST="/opt/litellm/.env"

[[ ! -f "$SRC" ]] && { echo "Erro: $SRC não encontrado"; exit 1; }
[[ ! -f "$DEST" ]] && { echo "Erro: $DEST não encontrado. Execute deploy primeiro."; exit 1; }

echo "=== Sync .env → /opt/litellm ==="
echo "  Source: $SRC"
echo "  Dest:   $DEST"
echo ""

updated=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^#.*$ ]] && continue
  [[ "$line" =~ ^[[:space:]]*$ ]] && continue
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    val="${BASH_REMATCH[2]}"
    val="${val%\"}"; val="${val#\"}"  # strip quotes
    [[ -z "$val" ]] && continue
    if grep -q "^${key}=" "$DEST" 2>/dev/null; then
      # Preserva LITELLM_MASTER_KEY se destino já tem valor (produção)
      if [[ "$key" == "LITELLM_MASTER_KEY" ]]; then
        dest_val=$(grep "^${key}=" "$DEST" | cut -d= -f2-)
        [[ -n "$dest_val" && "$dest_val" != "sk-litellm-default" ]] && continue
      fi
      sudo sed -i "s|^${key}=.*|${key}=${val}|" "$DEST"
      echo "  OK: $key"
      ((updated++)) || true
    else
      echo "  ADD: $key"
      echo "${key}=${val}" | sudo tee -a "$DEST" > /dev/null
      ((updated++)) || true
    fi
  fi
done < "$SRC"

echo ""
echo "  Atualizadas: $updated variáveis"
echo "  Reinicie: docker restart litellm-proxy"
echo ""

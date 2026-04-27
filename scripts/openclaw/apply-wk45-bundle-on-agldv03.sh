#!/usr/bin/env bash
# Aplica bundle .openclaw exportado da aglwk45 em /root/.openclaw no agldv03.
# Mantem apenas Telegram nos canais (token/regras do backup actual do agldv03).
# Mantem .gateway do agldv03 (porta/paths Linux). Resto = wk45 (agents, skills, workspaces, etc.).
# Preserva litellm-gateway.env e zshrc-openclaw.env do agldv03 (LiteLLM local).
#
# Repo no agldv03: /mnt/overpower/apps/dev/agl/agl-hostman (sobrepor com AGL_HOSTMAN_ROOT)
#
# Uso (no agldv03 como root):
#   bash apply-wk45-bundle-on-agldv03.sh /tmp/openclaw-wk45-for-agldv03-....tgz
#
# Requer: jq, tar
set -euo pipefail

AGL_HOSTMAN_ROOT="${AGL_HOSTMAN_ROOT:-/mnt/overpower/apps/dev/agl/agl-hostman}"

ARCHIVE="${1:?Uso: $0 /caminho/para/openclaw-wk45-for-agldv03.tgz}"
AGL_DIR="${OPENCLAW_HOME:-/root/.openclaw}"
STAMP=$(date +%Y%m%d%H%M%S)
BACKUP="${AGL_DIR}.bak.wk45-sync-${STAMP}"
WORKDIR=$(mktemp -d)
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Erro: arquivo nao encontrado: $ARCHIVE" >&2
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "Erro: jq e obrigatorio" >&2
  exit 1
fi

echo "=== Backup de $AGL_DIR -> $BACKUP ==="
cp -a "$AGL_DIR" "$BACKUP"

echo "=== Extrair bundle ==="
tar -xzf "$ARCHIVE" -C "$WORKDIR"
SRC=""
if [[ -f "$WORKDIR/.openclaw/openclaw.json" ]]; then
  SRC="$WORKDIR/.openclaw"
elif [[ -f "$WORKDIR/openclaw/openclaw.json" ]]; then
  SRC="$WORKDIR/openclaw"
else
  JSON=$(find "$WORKDIR" -name 'openclaw.json' -type f -print -quit || true)
  [[ -n "$JSON" ]] || { echo "Erro: openclaw.json nao encontrado no arquivo" >&2; exit 1; }
  SRC=$(dirname "$JSON")
fi

WK_JSON="$SRC/openclaw.json"
AGL_JSON_BAK="$BACKUP/openclaw.json"
if [[ ! -f "$AGL_JSON_BAK" ]]; then
  echo "Erro: backup sem openclaw.json" >&2
  exit 1
fi
if ! jq -e '.channels.telegram.botToken' "$AGL_JSON_BAK" >/dev/null 2>&1; then
  echo "Erro: o backup do agldv03 nao tem channels.telegram.botToken (configura Telegram antes)." >&2
  exit 1
fi

MERGED=$(mktemp)
jq -s '
  .[0] as $wk | .[1] as $ag |
  ($ag.plugins // {}) as $agp |
  ($wk.plugins // {}) as $wkp |
  $wk
  | .channels = { telegram: $ag.channels.telegram }
  | .gateway = $ag.gateway
  | .plugins = ($wk.plugins // {})
  | .plugins.entries = ($wk.plugins.entries // {})
  | .plugins.entries.telegram = (
      ($agp.entries // {}).telegram // ($wkp.entries // {}).telegram // { "enabled": true }
    )
  | .bindings = (
      if ($ag.bindings != null and ($ag.bindings | length) > 0) then
        [ $ag.bindings[] | select(.match.channel == "telegram") ]
      else
        [ $wk.bindings[]? | select(.match.channel == "telegram") ]
      end
    )
' "$WK_JSON" "$AGL_JSON_BAK" > "$MERGED"

echo "=== Sincronizar arquivos wk45 -> $AGL_DIR (sem openclaw.json) ==="
mkdir -p "$AGL_DIR"
rsync -a --delete --exclude 'openclaw.json' "$SRC"/ "$AGL_DIR"/

echo "=== Gravar openclaw.json unificado ==="
install -m 600 "$MERGED" "$AGL_DIR/openclaw.json"

for f in litellm-gateway.env zshrc-openclaw.env; do
  if [[ -f "$BACKUP/$f" ]]; then
    cp -a "$BACKUP/$f" "$AGL_DIR/$f"
    echo "Preservado: $f"
  fi
done

echo ""
echo "=== Concluido ==="
echo "Backup completo: $BACKUP"
echo "Reiniciar gateway: systemctl --user restart openclaw-gateway"
echo "Se falhar doctor/canais: cd $AGL_HOSTMAN_ROOT && bash scripts/openclaw/fix-openclaw-agldv03-fgsrv06.sh"

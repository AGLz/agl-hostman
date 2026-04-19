#!/usr/bin/env bash
# Envia o .tgz gerado na wk45 (pack-openclaw-for-agldv03.ps1) para o agldv03 e aplica o merge.
# Executar a partir da raiz do repo (ou qualquer pasta com o .tgz):
#   bash scripts/openclaw/push-wk45-bundle-to-agldv03.sh ~/Desktop/openclaw-wk45-for-agldv03-*.tgz
#
# Variáveis opcionais: AGLDV03=root@100.94.221.87
set -euo pipefail

ARCHIVE="${1:?Uso: $0 /caminho/openclaw-wk45-for-agldv03....tgz}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY="$REPO_ROOT/scripts/openclaw/apply-wk45-bundle-on-agldv03.sh"
HOST="${AGLDV03:-root@100.94.221.87}"

[[ -f "$ARCHIVE" ]] || { echo "Erro: ficheiro nao encontrado: $ARCHIVE" >&2; exit 1; }
[[ -f "$APPLY" ]] || { echo "Erro: falta $APPLY" >&2; exit 1; }

BASE=$(basename "$ARCHIVE")
REMOTE_TMP="/tmp/$BASE"

echo "=== scp -> $HOST ==="
scp -q "$ARCHIVE" "$HOST:$REMOTE_TMP"
scp -q "$APPLY" "$HOST:/tmp/apply-wk45-bundle-on-agldv03.sh"

echo "=== aplicar no destino ==="
ssh "$HOST" "bash /tmp/apply-wk45-bundle-on-agldv03.sh $REMOTE_TMP"

echo "=== Reiniciar gateway (opcional) ==="
ssh "$HOST" 'systemctl --user restart openclaw-gateway 2>/dev/null && systemctl --user is-active openclaw-gateway || true'

echo "OK."

#!/usr/bin/env bash
# Aumenta o timeout de handshake WebSocket do gateway OpenClaw (predefinição: 3s no código).
#
# Motivo: o CLI `openclaw gateway call` / `openclaw agent` pode demorar >3s a enviar o
# frame "connect" após o TCP; o servidor regista `handshake timeout` e fecha com 1000,
# parecendo falha de auth ou resposta vazia.
#
# Uso:
#   bash scripts/openclaw/apply-openclaw-gateway-ws-handshake-timeout.sh [ms]
#   # ms predefinido: 30000
#
# Depois: systemctl --user restart openclaw-gateway
#
# Nota: altera ficheiros em node_modules global do OpenClaw; repetir após `npm i -g openclaw`.
set -euo pipefail

MS="${1:-30000}"
if ! [[ "$MS" =~ ^[0-9]+$ ]] || [[ "$MS" -lt 1000 ]]; then
  echo "ERRO: ms deve ser inteiro >= 1000 (recebido: ${1:-})" >&2
  exit 1
fi

if ! command -v openclaw >/dev/null 2>&1; then
  echo "ERRO: openclaw não está no PATH" >&2
  exit 1
fi

OC_BIN="$(command -v openclaw)"
OC_REAL="$(readlink -f "$OC_BIN" 2>/dev/null || echo "$OC_BIN")"
# bin/openclaw → ../lib/node_modules/openclaw/openclaw.mjs (dirname = raiz do pacote)
OC_ROOT="$(cd "$(dirname "$OC_REAL")" && pwd)"
DIST="$OC_ROOT/dist"
if [[ ! -d "$DIST" ]]; then
  echo "ERRO: pasta dist não encontrada em $OC_ROOT" >&2
  exit 1
fi

shopt -s nullglob
patched=0
for f in "$DIST"/gateway-cli-*.js; do
  if grep -q 'DEFAULT_HANDSHAKE_TIMEOUT_MS = 3e3' "$f"; then
    cp -a "$f" "${f}.bak.handshake-${MS}"
    sed -i "s/DEFAULT_HANDSHAKE_TIMEOUT_MS = 3e3/DEFAULT_HANDSHAKE_TIMEOUT_MS = ${MS}/" "$f"
    echo "OK: $f -> DEFAULT_HANDSHAKE_TIMEOUT_MS = ${MS}"
    patched=$((patched + 1))
  elif grep -q "DEFAULT_HANDSHAKE_TIMEOUT_MS = ${MS}" "$f"; then
    echo "SKIP (já ${MS}ms): $f"
  else
    echo "AVISO: padrão 3e3 não encontrado em $f — rever manualmente ou versão diferente do pacote." >&2
  fi
done

if [[ "$patched" -eq 0 ]]; then
  echo "Nenhum ficheiro patchado (já aplicado ou versão OpenClaw inesperada)." >&2
fi

echo "Reiniciar gateway: systemctl --user restart openclaw-gateway"

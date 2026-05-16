#!/usr/bin/env bash
# Aplica ct200-ollama-override.conf no serviço systemd do Ollama (CT200).
# Executar como root no contentor CT200, com o checkout agl-hostman montado ou copiado.
#
# Exemplo (dentro do CT200):
#   cd /caminho/agl-hostman && bash scripts/aglsrv1/apply-ct200-ollama-override.sh
#
# Exemplo (desde AGLSRV1 com pct):
#   pct push 200 /mnt/.../agl-hostman/scripts/aglsrv1/ct200-ollama-override.conf \
#     /tmp/ct200-ollama-override.conf
#   pct exec 200 -- bash -c 'install -d /etc/systemd/system/ollama.service.d && \
#     cp /tmp/ct200-ollama-override.conf /etc/systemd/system/ollama.service.d/override.conf && \
#     systemctl daemon-reload && systemctl restart ollama'
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${SCRIPT_DIR}/ct200-ollama-override.conf"
DEST_DIR="/etc/systemd/system/ollama.service.d"
DEST="${DEST_DIR}/override.conf"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "ERRO: correr como root (sudo)." >&2
  exit 1
fi

if [[ ! -f "$SRC" ]]; then
  echo "ERRO: ficheiro fonte em falta: $SRC" >&2
  exit 1
fi

install -d "$DEST_DIR"
cp -a "$SRC" "$DEST"
echo "Instalado: $DEST"
systemctl daemon-reload
systemctl restart ollama
sleep 2
systemctl --no-pager -l status ollama || true
echo ""
echo "Verificar ambiente:"
systemctl show ollama -p Environment --no-pager | tr ' ' '\n' | grep -E '^OLLAMA_' || true

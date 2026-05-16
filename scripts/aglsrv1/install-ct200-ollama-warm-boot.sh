#!/usr/bin/env bash
# Instala warm Ollama Cloud no arranque do CT200 (systemd oneshot).
# Executar no host AGLSRV1 como root (usa pct 200).
set -euo pipefail

CTID="${CTID:-200}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WARM="${SCRIPT_DIR}/warm-ollama-cloud-models.sh"
UNIT="${SCRIPT_DIR}/ollama-warm-cloud.service"

if [[ "${EUID:-0}" -ne 0 ]]; then
  echo "ERRO: correr como root no AGLSRV1." >&2
  exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
  echo "ERRO: pct não encontrado (não é Proxmox?)." >&2
  exit 1
fi

for f in "$WARM" "$UNIT"; do
  if [[ ! -f "$f" ]]; then
    echo "ERRO: ficheiro em falta: $f" >&2
    exit 1
  fi
done

TMP="/tmp/ct200-warm-install-$$"
mkdir -p "$TMP"
cp -a "$WARM" "$TMP/warm-ollama-cloud-models.sh"
cp -a "$UNIT" "$TMP/ollama-warm-cloud.service"
sed -i 's/\r$//' "$TMP/warm-ollama-cloud-models.sh" "$TMP/ollama-warm-cloud.service" || true

pct push "$CTID" "$TMP/warm-ollama-cloud-models.sh" /usr/local/sbin/warm-ollama-cloud-models.sh
pct push "$CTID" "$TMP/ollama-warm-cloud.service" /etc/systemd/system/ollama-warm-cloud.service
rm -rf "$TMP"

pct exec "$CTID" -- chmod +x /usr/local/sbin/warm-ollama-cloud-models.sh
pct exec "$CTID" -- systemctl daemon-reload
pct exec "$CTID" -- systemctl enable ollama-warm-cloud.service
echo "Instalado: ollama-warm-cloud.service (enabled). Correr agora: pct exec $CTID -- systemctl start ollama-warm-cloud.service"

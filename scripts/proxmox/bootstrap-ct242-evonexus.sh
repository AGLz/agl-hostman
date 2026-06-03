#!/usr/bin/env bash
# Prepara CT242 vazio (ou recém-instalado) para receber sync CT189 → 242.
# Instala Docker e dependências; não copia dados EvoNexus.
#
# Uso no fgsrv7 (host Proxmox):
#   bash scripts/proxmox/bootstrap-ct242-evonexus.sh
#   CTID=242 bash scripts/proxmox/bootstrap-ct242-evonexus.sh
#
# Depois: bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh

set -euo pipefail

CTID="${CTID:-242}"

require_pct() {
  command -v pct >/dev/null || { echo "ERRO: pct — correr no Proxmox fgsrv7" >&2; exit 1; }
}

ensure_ct_running() {
  local st
  st="$(pct status "${CTID}" 2>/dev/null | awk '{print $2}' || true)"
  case "${st}" in
    running) ;;
    stopped)
      echo "=== A iniciar CT${CTID} ==="
      pct start "${CTID}"
      sleep 5
      ;;
    *)
      echo "ERRO: CT${CTID} estado inválido: ${st:-inexistente}. Recriar rootfs antes (RESTORE-CT242-EVONEXUS.md)." >&2
      exit 1
      ;;
  esac
}

bootstrap_inside_ct() {
  pct exec "${CTID}" -- bash -s <<'INSIDE'
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Instalar Docker ==="
  apt-get update -qq
  apt-get install -y -qq ca-certificates curl git gnupg
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || service docker start 2>/dev/null || true
fi

apt-get install -y -qq ca-certificates curl git gnupg jq 2>/dev/null || true

install -d -m 0755 /opt/evonexus

if docker info >/dev/null 2>&1; then
  echo "OK: Docker activo no CT"
  docker --version
else
  echo "ERRO: Docker não responde após instalação" >&2
  exit 1
fi
INSIDE
}

main() {
  require_pct
  ensure_ct_running
  bootstrap_inside_ct
  echo ""
  echo "OK: CT${CTID} pronto para pct-sync-evonexus-189-to-242.sh"
}

main "$@"

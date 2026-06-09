#!/usr/bin/env bash
# Copia stack EvoNexus do CT189 (AGLSRV1) para CT548 evonexus (fgsrv7; antes CT242).
# Executar no host Proxmox fgsrv7 como root (pct local para 548; SSH para AGLSRV1/189).
#
# Pré-requisitos:
#   - CT548 a correr com Ubuntu + Docker (ver bootstrap-ct242-evonexus.sh)
#   - SSH BatchMode root@AGLSRV1 → pct exec 189
#   - CT189 com stack EvoNexus em /opt/evonexus e volumes evonexus_evonexus_*
#
# Uso:
#   bash scripts/proxmox/pct-sync-evonexus-189-to-242.sh
#   SYNC_OPT_ONLY=1 bash ...          # só /opt/evonexus (sem volumes)
#   SYNC_VOLUMES_ONLY=1 bash ...      # só volumes Docker
#   SYNC_COMPOSE_UP=1 bash ...        # docker compose up -d após import
#
# Pós-sync (CT548): ver scripts/proxmox/RESTORE-CT242-EVONEXUS.md

set -euo pipefail

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
CT_SOURCE="${CT_SOURCE:-189}"
CT_TARGET="${CT_TARGET:-548}"
COMPOSE_FILE="${COMPOSE_FILE:-/opt/evonexus/docker-compose.hub.yml}"

TMP="/tmp/evonexus-ct189-opt-$$.tgz"
VOL_TMP="/tmp/evonexus-ct189-vols-$$.tgz"

SYNC_OPT_ONLY="${SYNC_OPT_ONLY:-0}"
SYNC_VOLUMES_ONLY="${SYNC_VOLUMES_ONLY:-0}"
SYNC_COMPOSE_UP="${SYNC_COMPOSE_UP:-0}"

VOLUMES=(
  evonexus_evonexus_config
  evonexus_evonexus_workspace
  evonexus_evonexus_dashboard_data
  evonexus_evonexus_memory
  evonexus_evonexus_adw_logs
  evonexus_evonexus_agent_memory
)

cleanup() { rm -f "${TMP}" "${VOL_TMP}" 2>/dev/null || true; }
trap cleanup EXIT

require_pct() {
  command -v pct >/dev/null || { echo "ERRO: pct — correr no Proxmox fgsrv7" >&2; exit 1; }
}

require_ct_running() {
  local vmid="$1"
  local st
  st="$(pct status "${vmid}" 2>/dev/null | awk '{print $2}' || true)"
  if [[ "${st}" != "running" ]]; then
    echo "ERRO: CT${vmid} não está running (estado: ${st:-desconhecido})" >&2
    exit 1
  fi
}

require_docker_in_ct() {
  local vmid="$1"
  if ! pct exec "${vmid}" -- docker info >/dev/null 2>&1; then
    echo "ERRO: Docker indisponível no CT${vmid}. Correr bootstrap-ct242-evonexus.sh primeiro." >&2
    exit 1
  fi
}

export_opt_from_189() {
  echo "=== [1/3] Export /opt/evonexus (CT${CT_SOURCE} @ AGLSRV1) ==="
  if ! ssh -o BatchMode=yes "${AGLSRV1}" \
    "pct exec ${CT_SOURCE} -- test -d /opt/evonexus"; then
    echo "ERRO: /opt/evonexus inexistente no CT${CT_SOURCE}" >&2
    exit 1
  fi
  if ! ssh -o BatchMode=yes "${AGLSRV1}" \
    "pct exec ${CT_SOURCE} -- tar czf - -C /opt evonexus" >"${TMP}"; then
    echo "ERRO: export /opt/evonexus falhou" >&2
    exit 1
  fi
  if [[ ! -s "${TMP}" ]]; then
    echo "ERRO: export /opt/evonexus vazio" >&2
    exit 1
  fi
  echo "  $(wc -c <"${TMP}") bytes"
}

import_opt_to_242() {
  echo "=== Import /opt/evonexus → CT${CT_TARGET} ==="
  pct exec "${CT_TARGET}" -- mkdir -p /opt
  cat "${TMP}" | pct exec "${CT_TARGET}" -- tar xzf - -C /opt
  pct exec "${CT_TARGET}" -- test -f "${COMPOSE_FILE}" || {
    echo "ERRO: ${COMPOSE_FILE} não encontrado após import" >&2
    exit 1
  }
}

export_volumes_from_189() {
  echo "=== [2/3] Export volumes Docker (CT${CT_SOURCE}) ==="
  ssh -o BatchMode=yes "${AGLSRV1}" "pct exec ${CT_SOURCE} -- bash -s" <<'REMOTE' >"${VOL_TMP}"
set -euo pipefail
export_dir=/tmp/evonexus-vol-export-$$
mkdir -p "${export_dir}"
for v in \
  evonexus_evonexus_config \
  evonexus_evonexus_workspace \
  evonexus_evonexus_dashboard_data \
  evonexus_evonexus_memory \
  evonexus_evonexus_adw_logs \
  evonexus_evonexus_agent_memory
do
  if ! docker volume inspect "${v}" >/dev/null 2>&1; then
    echo "AVISO: volume ${v} não existe no CT189" >&2
    continue
  fi
  docker run --rm -v "${v}:/from:ro" -v "${export_dir}:/to" alpine \
    sh -c "mkdir -p /to/${v} && cp -a /from/. /to/${v}/"
done
tar czf - -C "$(dirname "${export_dir}")" "$(basename "${export_dir}")"
rm -rf "${export_dir}"
REMOTE
  if [[ ! -s "${VOL_TMP}" ]]; then
    echo "ERRO: export de volumes vazio" >&2
    exit 1
  fi
  echo "  $(wc -c <"${VOL_TMP}") bytes"
}

import_volumes_to_242() {
  echo "=== [3/3] Import volumes → CT${CT_TARGET} ==="
  pct exec "${CT_TARGET}" -- bash -c '
set -euo pipefail
if docker compose -f '"${COMPOSE_FILE}"' ps -q 2>/dev/null | grep -q .; then
  echo "Parar stack EvoNexus antes de importar volumes..."
  docker compose -f '"${COMPOSE_FILE}"' down || true
fi
'
  cat "${VOL_TMP}" | pct exec "${CT_TARGET}" -- tar xzf - -C /tmp
  pct exec "${CT_TARGET}" -- bash -c '
set -euo pipefail
dir=$(ls -d /tmp/evonexus-vol-export-* 2>/dev/null | head -1)
test -n "${dir}" || { echo "ERRO: pasta de export de volumes não encontrada" >&2; exit 1; }
for sub in "${dir}"/*/; do
  [[ -d "${sub}" ]] || continue
  vname=$(basename "${sub}")
  docker volume create "${vname}" >/dev/null 2>&1 || true
  docker run --rm -v "${vname}:/to" -v "${sub}:/from:ro" alpine sh -c "rm -rf /to/* /to/.[!.]* 2>/dev/null; cp -a /from/. /to/"
  echo "  importado: ${vname}"
done
rm -rf "${dir}"
'
}

compose_up_if_requested() {
  if [[ "${SYNC_COMPOSE_UP}" != "1" ]]; then
    echo ""
    echo "Sync concluído. Para subir a stack: SYNC_COMPOSE_UP=1 $0"
    echo "Ou no CT242: docker compose -f ${COMPOSE_FILE} pull && docker compose -f ${COMPOSE_FILE} up -d"
    echo "Seguir: scripts/proxmox/RESTORE-CT242-EVONEXUS.md (pós-sync)"
    return 0
  fi
  echo "=== docker compose up -d (CT${CT_TARGET}) ==="
  pct exec "${CT_TARGET}" -- bash -c "
set -euo pipefail
cd /opt/evonexus
docker compose -f ${COMPOSE_FILE} pull
docker compose -f ${COMPOSE_FILE} up -d
docker compose -f ${COMPOSE_FILE} ps
"
}

main() {
  require_pct
  require_ct_running "${CT_TARGET}"
  require_docker_in_ct "${CT_TARGET}"

  echo "Fonte: CT${CT_SOURCE} via ${AGLSRV1}"
  echo "Destino: CT${CT_TARGET} (local fgsrv7)"
  echo ""

  if [[ "${SYNC_VOLUMES_ONLY}" != "1" ]]; then
    export_opt_from_189
    import_opt_to_242
  fi

  if [[ "${SYNC_OPT_ONLY}" != "1" ]]; then
    export_volumes_from_189
    import_volumes_to_242
  fi

  compose_up_if_requested
  echo ""
  echo "OK: EvoNexus /opt + volumes copiados CT${CT_SOURCE} → CT${CT_TARGET}"
}

main "$@"

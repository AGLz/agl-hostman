#!/usr/bin/env bash
# Copia stack EvoNexus do CT242 (fgsrv7) para CT189 (AGLSRV1): /opt/evonexus + volumes Docker.
# Executar no AGLSRV1 como root.
#
# Inverso (189 → 242): scripts/proxmox/pct-sync-evonexus-189-to-242.sh (fgsrv7)
# Runbook restauro CT242: scripts/proxmox/RESTORE-CT242-EVONEXUS.md
#
# Uso: bash scripts/proxmox/pct-sync-evonexus-242-to-189.sh

set -euo pipefail

FGSRV7="${FGSRV7:-root@100.109.181.93}"
TMP="/tmp/evonexus-ct242-opt-$$.tgz"
VOL_TMP="/tmp/evonexus-ct242-vols-$$.tgz"

command -v pct >/dev/null || { echo "ERRO: pct — correr no Proxmox AGLSRV1" >&2; exit 1; }

cleanup() { rm -f "${TMP}" "${VOL_TMP}" 2>/dev/null || true; }
trap cleanup EXIT

echo "=== [1/3] Export /opt/evonexus (CT242) ==="
if ! ssh -o BatchMode=yes "${FGSRV7}" "pct exec 242 -- tar czf - -C /opt evonexus" >"${TMP}"; then
  echo "ERRO: export /opt/evonexus falhou" >&2
  exit 1
fi
if [[ ! -s "${TMP}" ]]; then
  echo "ERRO: export vazio" >&2
  exit 1
fi
echo "  $(wc -c <"${TMP}") bytes"
pct exec 189 -- mkdir -p /opt
cat "${TMP}" | pct exec 189 -- tar xzf - -C /opt

echo "=== [2/3] Export volumes (CT242) ==="
ssh -o BatchMode=yes "${FGSRV7}" "pct exec 242 -- bash -s" <<'REMOTE' >"${VOL_TMP}"
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
  docker run --rm -v "${v}:/from:ro" -v "${export_dir}:/to" alpine \
    sh -c "mkdir -p /to/${v} && cp -a /from/. /to/${v}/"
done
tar czf - -C "$(dirname "${export_dir}")" "$(basename "${export_dir}")"
rm -rf "${export_dir}"
REMOTE

echo "=== [3/3] Import volumes (CT189) ==="
cat "${VOL_TMP}" | pct exec 189 -- tar xzf - -C /tmp
pct exec 189 -- bash -c '
set -euo pipefail
dir=$(ls -d /tmp/evonexus-vol-export-* 2>/dev/null | head -1)
test -n "${dir}"
for sub in "${dir}"/*/; do
  vname=$(basename "${sub}")
  docker volume create "${vname}" >/dev/null 2>&1 || true
  docker run --rm -v "${vname}:/to" -v "${sub}:/from:ro" alpine sh -c "cp -a /from/. /to/"
done
rm -rf "${dir}"
'

echo "OK: EvoNexus /opt + volumes em CT189"

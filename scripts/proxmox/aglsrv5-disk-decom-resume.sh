#!/usr/bin/env bash
# AGLSRV5 — retoma decom VM127: sdf agora, depois sdb → sdc (sda já concluído).
# Executar no host: nohup bash /dev/shm/disk-decom-resume.sh >> /dev/shm/disk-decom-server/nohup-resume.log 2>&1 &
set -uo pipefail

LOGDIR="/dev/shm/disk-decom-server"
DISKS=(sdf sdb sdc)

log() {
  echo "[$(date -Iseconds)] $*" | tee -a "${LOGDIR}/run.log"
}

wait_smart_idle() {
  local dev="$1"
  for _ in $(seq 1 48); do
    if smartctl -c "/dev/${dev}" 2>/dev/null | grep -q "Self-test in progress"; then
      sleep 300
    else
      break
    fi
  done
}

prep_sdf() {
  log "=== /dev/sdf: prep (ZFS label órfã, ex-mirror base) ==="
  if zpool status base 2>/dev/null | grep -q "S2N6J50B708823"; then
    log "ERRO: sdf ainda referenciado no pool base — abortar"
    return 1
  fi
  wipefs -a /dev/sdf 2>&1 | tee -a "${LOGDIR}/sdf-wipefs.log"
  log "sdf wipefs done"
}

decom_disk() {
  local dev="$1"

  umount "/dev/${dev}"* 2>/dev/null || true
  umount "/mnt/storage/tmp_${dev}1" 2>/dev/null || true

  if [[ "${dev}" == "sdf" ]]; then
    prep_sdf || return 1
    smartctl -t short "/dev/sdf" > "${LOGDIR}/smart-short-start-sdf.txt" 2>&1 || true
    sleep 120
    smartctl -l selftest "/dev/sdf" > "${LOGDIR}/smart-short-result-sdf.txt" 2>&1 || true
    if ! grep -q "Self-test" "${LOGDIR}/smart-long-start-sdf.txt" 2>/dev/null; then
      smartctl -t long "/dev/sdf" > "${LOGDIR}/smart-long-start-sdf.txt" 2>&1 || true
      wait_smart_idle "${dev}"
    fi
  else
    wait_smart_idle "${dev}"
  fi

  smartctl -l selftest "/dev/${dev}" > "${LOGDIR}/smart-long-result-${dev}.txt" 2>&1 || true
  smartctl -a "/dev/${dev}" > "${LOGDIR}/smart-full-${dev}.txt" 2>&1 || true

  log "=== /dev/${dev}: badblocks -wsv (sem smartctl em paralelo) ==="
  badblocks -wsv "/dev/${dev}" 2>&1 | tee "${LOGDIR}/badblocks-${dev}.log"
  log "=== /dev/${dev}: dd zero wipe ==="
  dd if=/dev/zero of="/dev/${dev}" bs=4M status=progress conv=fsync 2>&1 | tee "${LOGDIR}/dd-zero-${dev}.log"
  log "=== /dev/${dev}: DONE ==="
}

mkdir -p "${LOGDIR}"

if ! grep -q "=== /dev/sda: DONE ===" "${LOGDIR}/run.log" 2>/dev/null; then
  if strings "${LOGDIR}/badblocks-sda.log" 2>/dev/null | grep -q "Pass completed, 0 bad blocks"; then
    log "=== /dev/sda: DONE (registado na retoma — badblocks 0 erros, 2026-06-23) ==="
  fi
fi

log "=== RETOMA decom: ordem sdf → sdb → sdc ==="

for dev in "${DISKS[@]}"; do
  if grep -q "=== /dev/${dev}: DONE ===" "${LOGDIR}/run.log" 2>/dev/null; then
    log "=== /dev/${dev}: skip (já DONE) ==="
    continue
  fi
  decom_disk "${dev}" || log "ERRO: decom /dev/${dev} falhou — continuar fila"
done

log "ALL DONE (sda prévio + sdf sdb sdc)"

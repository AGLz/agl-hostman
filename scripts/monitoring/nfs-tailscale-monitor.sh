#!/bin/bash
# NFS & Tailscale Health Monitor for FileServer5 (CT138) <-> FGSRV4
# This script checks NFS mount status and Tailscale connectivity,
# then triggers automated recovery if issues are detected.
#
# Usage: ./nfs-tailscale-monitor.sh [--dry-run] [--verbose]
# Exit codes: 0=healthy, 1=degraded, 2=critical, 3=recovery triggered

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs/nfs-monitor"
LOG_FILE="${LOG_DIR}/monitor-$(date +%Y%m%d).log"
LOCK_FILE="/tmp/nfs-monitor.lock"
RECOVERY_SCRIPT="${SCRIPT_DIR}/nfs-tailscale-recovery.sh"

# Hosts configuration
FILESERVER5_HOST="100.66.136.84"  # CT138 Tailscale IP
FGSRV4_HOST="100.111.79.2"       # VPS Tailscale IP
AGLSRV5_HOST="100.119.223.113"   # Proxmox host running CT138
CT_ID="138"

# NFS mount points to verify (inside CT138)
EXPECTED_MOUNTS=(
  "/mnt/fgsrv4-fg_antigo-wg"
  "/mnt/fgsrv4-fg_antigo-ts"
  "/mnt/fgsrv4-nfs-ts"
)

# Thresholds
PING_TIMEOUT=3
PING_COUNT=2
MAX_LATENCY_MS=100  # Alert if latency > 100ms

# Flags
DRY_RUN=false
VERBOSE=false

# ============================================================
# Parse arguments
# ============================================================
while [[ $# -gt 0 ]]; do
  case $1 in
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --verbose)
      VERBOSE=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# ============================================================
# Utility functions
# ============================================================
log() {
  local level="$1"
  shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_line="[${timestamp}] [${level}] ${message}"

  mkdir -p "${LOG_DIR}"
  echo "${log_line}" >> "${LOG_FILE}"

  if [[ "${VERBOSE}" == "true" ]]; then
    echo "${log_line}"
  fi
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_critical() { log "CRITICAL" "$@"; }

cleanup() {
  rm -f "${LOCK_FILE}"
}

acquire_lock() {
  if [[ -f "${LOCK_FILE}" ]]; then
    local pid
    pid=$(cat "${LOCK_FILE}")
    if kill -0 "${pid}" 2>/dev/null; then
      log_warn "Another instance is running (PID: ${pid}), exiting"
      exit 3
    else
      log_warn "Stale lock file found, removing"
      rm -f "${LOCK_FILE}"
    fi
  fi
  echo $$ > "${LOCK_FILE}"
  trap cleanup EXIT
}

# ============================================================
# Health check functions
# ============================================================
check_tailscale_connectivity() {
  local target="$1"
  local name="$2"

  log_info "Checking Tailscale connectivity to ${name} (${target})"

  if ping -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${target}" &>/dev/null; then
    # Measure latency
    local latency
    latency=$(ping -c "${PING_COUNT}" -W "${PING_TIMEOUT}" "${target}" 2>/dev/null | \
              grep 'rtt' | awk -F'/' '{print $5}' | cut -d. -f1)

    if [[ -z "${latency}" ]]; then
      latency=0
    fi

    log_info "✅ ${name} is reachable (latency: ${latency}ms)"

    if [[ "${latency}" -gt "${MAX_LATENCY_MS}" ]]; then
      log_warn "⚠️  High latency detected: ${latency}ms (threshold: ${MAX_LATENCY_MS}ms)"
      return 1
    fi

    return 0
  else
    log_error "❌ ${name} is UNREACHABLE"
    return 2
  fi
}

check_ct_status() {
  log_info "Checking CT${CT_ID} (fileserver5) status on AGLSRV5"

  local status
  status=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
           root@${AGLSRV5_HOST} "pct status ${CT_ID} 2>/dev/null | awk '{print \$2}'" 2>/dev/null || echo "unknown")

  if [[ "${status}" == "running" ]]; then
    log_info "✅ CT${CT_ID} is running"
    return 0
  else
    log_critical "❌ CT${CT_ID} status: ${status}"
    return 2
  fi
}

check_nfs_mounts() {
  log_info "Checking NFS mounts inside CT${CT_ID}"

  local mounts_ok=0
  local mounts_failed=0
  local failed_mounts=()

  for mount_point in "${EXPECTED_MOUNTS[@]}"; do
    local is_mounted
    is_mounted=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                 root@${AGLSRV5_HOST} \
                 "pct exec ${CT_ID} -- bash -c 'mountpoint -q ${mount_point} && echo yes || echo no'" 2>/dev/null || echo "no")

    if [[ "${is_mounted}" == "yes" ]]; then
      log_info "✅ Mount ${mount_point} is active"
      ((mounts_ok++))
    else
      log_error "❌ Mount ${mount_point} is MISSING"
      ((mounts_failed++))
      failed_mounts+=("${mount_point}")
    fi
  done

  # Check disk space on mounted filesystems
  local disk_check
  disk_check=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
               root@${AGLSRV5_HOST} \
               "pct exec ${CT_ID} -- df -h /mnt/fgsrv4-fg_antigo-ts 2>/dev/null | tail -1" 2>/dev/null || echo "unavailable")

  if [[ "${disk_check}" != "unavailable" ]]; then
    local usage_pct
    usage_pct=$(echo "${disk_check}" | awk '{print $5}' | tr -d '%')
    if [[ -n "${usage_pct}" && "${usage_pct}" =~ ^[0-9]+$ ]]; then
      if [[ "${usage_pct}" -gt 90 ]]; then
        log_warn "⚠️  Disk usage high: ${usage_pct}%"
      else
        log_info "✅ Disk usage: ${usage_pct}%"
      fi
    fi
  fi

  if [[ "${mounts_failed}" -eq 0 ]]; then
    log_info "✅ All ${mounts_ok} NFS mounts are healthy"
    return 0
  else
    log_critical "❌ ${mounts_failed}/${#EXPECTED_MOUNTS[@]} mounts failed: ${failed_mounts[*]}"
    return 2
  fi
}

check_nfs_export_availability() {
  log_info "Checking NFS exports on FGSRV4"

  local exports
  exports=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
            root@${AGLSRV5_HOST} \
            "pct exec ${CT_ID} -- showmount -e ${FGSRV4_HOST} 2>/dev/null" 2>/dev/null || echo "failed")

  if [[ "${exports}" == "failed" || -z "${exports}" ]]; then
    log_error "❌ Cannot retrieve NFS exports from FGSRV4"
    return 2
  else
    log_info "✅ NFS exports available on FGSRV4"
    log_info "Exports: $(echo "${exports}" | tr '\n' ' ')"
    return 0
  fi
}

check_samba_service() {
  log_info "Checking Samba service on CT${CT_ID}"

  local smbd_status
  smbd_status=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
                root@${AGLSRV5_HOST} \
                "pct exec ${CT_ID} -- systemctl is-active smbd 2>/dev/null" 2>/dev/null || echo "unknown")

  if [[ "${smbd_status}" == "active" ]]; then
    log_info "✅ Samba (smbd) is active"
    return 0
  else
    log_error "❌ Samba (smbd) status: ${smbd_status}"
    return 2
  fi
}

# ============================================================
# Main health check
# ============================================================
run_health_checks() {
  local health_status=0

  log_info "=========================================="
  log_info "NFS & Tailscale Health Check Started"
  log_info "=========================================="

  # Check 1: CT138 status
  if ! check_ct_status; then
    health_status=2
  fi

  # Check 2: FGSRV4 connectivity
  local fgsrv4_status
  check_tailscale_connectivity "${FGSRV4_HOST}" "FGSRV4" || fgsrv4_status=$?
  if [[ "${fgsrv4_status:-0}" -gt "${health_status}" ]]; then
    health_status=${fgsrv4_status}
  fi

  # Check 3: FileServer5 connectivity
  local fs5_status
  check_tailscale_connectivity "${FILESERVER5_HOST}" "FileServer5" || fs5_status=$?
  if [[ "${fs5_status:-0}" -gt "${health_status}" ]]; then
    health_status=${fs5_status}
  fi

  # Check 4: NFS exports availability
  if [[ "${health_status}" -lt 2 ]]; then
    check_nfs_export_availability || health_status=2
  fi

  # Check 5: NFS mounts inside CT138
  if [[ "${health_status}" -lt 2 ]]; then
    check_nfs_mounts || health_status=2
  fi

  # Check 6: Samba service
  check_samba_service || true  # Non-critical for NFS

  log_info "=========================================="
  case ${health_status} in
    0)
      log_info "Health Check Result: ✅ ALL SYSTEMS HEALTHY"
      ;;
    1)
      log_warn "Health Check Result: ⚠️  DEGRADED (high latency or partial failure)"
      ;;
    2)
      log_critical "Health Check Result: ❌ CRITICAL (connectivity or mount failure)"
      ;;
  esac
  log_info "=========================================="

  return ${health_status}
}

# ============================================================
# Trigger recovery if needed
# ============================================================
recovery_runs_on_proxmox_host() {
  command -v pct &>/dev/null && pct status "${CT_ID}" &>/dev/null
}

trigger_recovery() {
  local issue_type="$1"

  log_warn "Triggering automated recovery for: ${issue_type}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    if recovery_runs_on_proxmox_host; then
      log_info "[DRY RUN] Would execute locally: ${RECOVERY_SCRIPT} ${issue_type}"
    else
      log_info "[DRY RUN] Would execute on ${AGLSRV5_HOST}: ${RECOVERY_SCRIPT} ${issue_type}"
    fi
    return 0
  fi

  if [[ ! -x "${RECOVERY_SCRIPT}" ]]; then
    log_error "Recovery script not found or not executable: ${RECOVERY_SCRIPT}"
    return 1
  fi

  log_info "Executing recovery script..."
  local recovery_status=0
  local recovery_out
  set +e
  if recovery_runs_on_proxmox_host; then
    recovery_out=$("${RECOVERY_SCRIPT}" "${issue_type}" 2>&1)
    recovery_status=$?
  else
    # Reason: recovery usa pct/exec — tem de correr no Proxmox AGLSRV5, não no host de monitorização.
    local remote_bin="/usr/local/lib/agl-nfs-monitor/nfs-tailscale-recovery.sh"
    if ssh -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
      root@"${AGLSRV5_HOST}" "test -x ${remote_bin}" 2>/dev/null; then
      recovery_out=$(ssh -o ConnectTimeout=120 -o StrictHostKeyChecking=no root@"${AGLSRV5_HOST}" \
        "export NFS_MONITOR_LOG_DIR=/var/log/agl-nfs-monitor; ${remote_bin} $(printf '%q' "${issue_type}")" 2>&1)
      recovery_status=$?
    else
      log_warn "Script remoto em falta (${remote_bin}); a enviar cópia temporária..."
      if scp -o ConnectTimeout=30 -o StrictHostKeyChecking=no \
        "${RECOVERY_SCRIPT}" root@"${AGLSRV5_HOST}":/tmp/nfs-tailscale-recovery-run.sh 2>/dev/null; then
        recovery_out=$(ssh -o ConnectTimeout=120 -o StrictHostKeyChecking=no root@"${AGLSRV5_HOST}" \
          "export NFS_MONITOR_LOG_DIR=/var/log/agl-nfs-monitor; bash /tmp/nfs-tailscale-recovery-run.sh $(printf '%q' "${issue_type}"); ec=\$?; rm -f /tmp/nfs-tailscale-recovery-run.sh; exit \$ec" 2>&1)
        recovery_status=$?
      else
        recovery_out="scp para ${AGLSRV5_HOST} falhou (host inacessível?)"
        recovery_status=1
      fi
    fi
  fi
  set -e

  if [[ -n "${recovery_out}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      log_info "[RECOVERY] ${line}"
    done <<< "${recovery_out}"
  fi

  if [[ "${recovery_status}" -eq 0 ]]; then
    log_info "✅ Recovery completed successfully"
  else
    log_critical "❌ Recovery failed with status: ${recovery_status}"
  fi

  return "${recovery_status}"
}

# ============================================================
# Main execution
# ============================================================
main() {
  acquire_lock

  local health_status=0
  run_health_checks || health_status=$?

  if [[ "${health_status}" -eq 0 ]]; then
    log_info "No action needed, all systems healthy"
    exit 0
  fi

  # Determine issue type and trigger appropriate recovery
  local issue_type="unknown"

  if [[ "${health_status}" -eq 2 ]]; then
    issue_type="nfs-connectivity-critical"
  elif [[ "${health_status}" -eq 1 ]]; then
    issue_type="nfs-degraded-performance"
  fi

  log_warn "System unhealthy (${health_status}), triggering recovery..."
  trigger_recovery "${issue_type}" || exit 2

  # Re-run health check after recovery
  log_info "Running post-recovery health check..."
  local post_recovery_status=0
  run_health_checks || post_recovery_status=$?

  if [[ "${post_recovery_status}" -eq 0 ]]; then
    log_info "✅ Post-recovery verification: ALL SYSTEMS HEALTHY"
    exit 0
  else
    log_critical "❌ Post-recovery verification failed (status: ${post_recovery_status})"
    exit 2
  fi
}

main "$@"

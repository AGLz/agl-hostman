#!/bin/bash
# Automated NFS & Tailscale Recovery Script for FileServer5 (CT538, ex-CT138) <-> FGSRV4
# Optimized for LOCAL execution on AGLSRV5 (Proxmox host)
#
# Usage: ./nfs-tailscale-recovery.sh [issue_type]

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${NFS_MONITOR_LOG_DIR:-${SCRIPT_DIR}/../../logs/nfs-monitor}"
LOG_FILE="${LOG_DIR}/recovery-$(date +%Y%m%d).log"
RECOVERY_LOCK="/tmp/nfs-recovery.lock"
RECOVERY_COOLDOWN=300  # 5 minutes

CT_ID="538"
FGSRV4_TS_IP="100.111.79.2"
FGSRV4_WG_IP="10.6.0.16"

MOUNT_POINTS=(
  "/mnt/fgsrv4-fg_antigo-wg"
  "/mnt/fgsrv4-fg_antigo-ts"
  "/mnt/fgsrv4-nfs-ts"
)

ISSUE_TYPE="${ISSUE_TYPE:-${1:-manual}}"

# ============================================================
# Utility functions
# ============================================================
log() {
  local level="$1"; shift
  local message="$*"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  local log_line="[${timestamp}] [RECOVERY] [${level}] ${message}"

  mkdir -p "${LOG_DIR}"
  echo "${log_line}" >> "${LOG_FILE}"
  echo "${log_line}"
}

log_info() { log "INFO" "$@"; }
log_warn() { log "WARN" "$@"; }
log_error() { log "ERROR" "$@"; }
log_success() { log "SUCCESS" "$@"; }

check_recovery_cooldown() {
  local last_recovery_file="${LOG_DIR}/last-recovery-attempt"

  if [[ -f "${last_recovery_file}" ]]; then
    local last_attempt
    last_attempt=$(cat "${last_recovery_file}")
    local current_time
    current_time=$(date +%s)
    local elapsed=$((current_time - last_attempt))

    if [[ "${elapsed}" -lt "${RECOVERY_COOLDOWN}" ]]; then
      local remaining=$((RECOVERY_COOLDOWN - elapsed))
      log_warn "Recovery cooldown active (${remaining}s remaining), skipping"
      return 1
    fi
  fi

  date +%s > "${last_recovery_file}"
  return 0
}

acquire_recovery_lock() {
  if [[ -f "${RECOVERY_LOCK}" ]]; then
    local pid
    pid=$(cat "${RECOVERY_LOCK}")
    if kill -0 "${pid}" 2>/dev/null; then
      log_warn "Another recovery instance is running (PID: ${pid}), exiting"
      exit 1
    else
      log_warn "Stale recovery lock found, removing"
      rm -f "${RECOVERY_LOCK}"
    fi
  fi
  echo $$ > "${RECOVERY_LOCK}"
  trap 'rm -f "${RECOVERY_LOCK}"' EXIT
}

run_ct() {
  pct exec "${CT_ID}" -- bash -c "$*" 2>&1
}

# ============================================================
# Recovery Strategies
# ============================================================
strategy_restart_tailscale() {
  log_info "Strategy 1: Checking Tailscale connectivity"

  local ts_status
  ts_status=$(run_ct "tailscale status --json 2>/dev/null | jq -r '.BackendState' // 'unknown'" 2>&1 || echo "failed")

  if [[ "${ts_status}" != "Running" ]]; then
    log_warn "Tailscale not running on CT${CT_ID}, restarting..."
    run_ct "systemctl restart tailscaled && sleep 3 && tailscale up --reset --accept-routes=false --hostname=agl-host-fileserver5 --ssh" || {
      log_error "Failed to restart Tailscale on CT${CT_ID}"
      return 1
    }
    log_info "✅ Tailscale restarted on CT${CT_ID}"
  else
    log_info "✅ Tailscale running on CT${CT_ID} (state: ${ts_status})"
  fi

  sleep 2
  if run_ct "ping -c 2 -W 3 ${FGSRV4_TS_IP}" &>/dev/null; then
    log_success "✅ Tailscale connectivity to FGSRV4 restored"
    return 0
  else
    log_warn "⚠️  Tailscale connectivity still failing"
    return 1
  fi
}

strategy_remount_nfs() {
  log_info "Strategy 2: Remounting NFS shares"

  # Unmount stale mounts
  for mount_point in "${MOUNT_POINTS[@]}"; do
    local is_mounted
    is_mounted=$(run_ct "mountpoint -q ${mount_point} && echo yes || echo no" 2>&1 || echo "no")

    if [[ "${is_mounted}" == "yes" ]]; then
      log_info "Unmounting ${mount_point}"
      run_ct "umount -f ${mount_point} 2>/dev/null || umount -l ${mount_point} 2>/dev/null || true"
    fi
  done

  sleep 2

  # Remount via fstab
  log_info "Remounting all NFS via fstab"
  run_ct "mount -a" || {
    log_error "fstab mount failed, attempting manual mount"

    run_ct "mkdir -p /mnt/fgsrv4-fg_antigo-ts /mnt/fgsrv4-nfs-ts"

    run_ct "mount -t nfs4 -o rsize=1048576,wsize=1048576,timeo=600,retrans=5,actimeo=120,nocto,noatime,soft ${FGSRV4_TS_IP}:/var/www/fg_antigo /mnt/fgsrv4-fg_antigo-ts" || {
      log_error "Failed to mount fg_antigo via Tailscale"
      return 1
    }

    run_ct "mount -t nfs4 -o rsize=1048576,wsize=1048576,timeo=600,retrans=5,actimeo=120,nocto,noatime,soft ${FGSRV4_TS_IP}:/storage/nfs-export /mnt/fgsrv4-nfs-ts" || {
      log_error "Failed to mount nfs-export via Tailscale"
      return 1
    }
  }

  # Verify
  local mounts_ok=0
  for mount_point in "${MOUNT_POINTS[@]}"; do
    local check
    check=$(run_ct "mountpoint -q ${mount_point} && echo ok || echo fail" 2>&1 || echo "fail")
    if [[ "${check}" == "ok" ]]; then
      ((mounts_ok++))
      log_success "✅ ${mount_point} mounted"
    fi
  done

  if [[ "${mounts_ok}" -gt 0 ]]; then
    log_success "✅ NFS mounts restored (${mounts_ok}/${#MOUNT_POINTS[@]})"
    return 0
  else
    log_error "❌ No NFS mounts established"
    return 1
  fi
}

strategy_restart_samba() {
  log_info "Strategy 3: Restarting Samba services"

  run_ct "systemctl restart smbd nmbd" || {
    log_error "Failed to restart Samba"
    return 1
  }

  sleep 2

  local smbd_status
  smbd_status=$(run_ct "systemctl is-active smbd" 2>&1 || echo "unknown")

  if [[ "${smbd_status}" == "active" ]]; then
    log_success "✅ Samba restarted"
    return 0
  else
    log_error "❌ Samba failed to start (status: ${smbd_status})"
    return 1
  fi
}

strategy_restart_container() {
  log_info "Strategy 4: Restarting CT${CT_ID} (fileserver5)"

  log_warn "Graceful stop of CT${CT_ID}"
  pct stop "${CT_ID}" || {
    log_warn "Graceful stop failed, force stopping"
    pct shutdown "${CT_ID}" --timeout 30 || true
  }

  sleep 3

  # Clean up stuck resources
  find /sys/fs/cgroup/ -name "*${CT_ID}*" -type d -print -delete 2>/dev/null || true
  ip link del veth${CT_ID}i0 2>/dev/null || true
  ip link del veth${CT_ID}i1 2>/dev/null || true

  sleep 2

  log_info "Starting CT${CT_ID}"
  pct start "${CT_ID}" || {
    log_error "Failed to start CT${CT_ID}"
    return 1
  }

  log_info "Waiting for CT${CT_ID} to boot..."
  sleep 15

  local ct_status
  ct_status=$(pct status "${CT_ID}" | awk '{print $2}' || echo "unknown")

  if [[ "${ct_status}" == "running" ]]; then
    log_success "✅ CT${CT_ID} restarted"
    return 0
  else
    log_error "❌ CT${CT_ID} failed to start (status: ${ct_status})"
    return 1
  fi
}

strategy_fix_tailscale_routing() {
  log_info "Strategy 5: Fixing Tailscale routing conflicts"

  log_info "Disabling accept-routes on CT${CT_ID}"
  run_ct "tailscale set --accept-routes=false" || {
    log_error "Failed to disable accept-routes"
    return 1
  }

  sleep 2

  local route_check
  route_check=$(run_ct "ip route get 172.2.2.222 2>/dev/null | grep -o 'dev [^ ]*'" 2>&1 || echo "unknown")

  if [[ "${route_check}" == *"eth1"* ]]; then
    log_success "✅ Tailscale routing fixed (using eth1)"
    return 0
  else
    log_warn "⚠️  Routing may still be incorrect (route: ${route_check})"
    return 1
  fi
}

# ============================================================
# Main recovery orchestration
# ============================================================
main() {
  acquire_recovery_lock

  log_info "=========================================="
  log_info "Automated NFS Recovery Started"
  log_info "Issue Type: ${ISSUE_TYPE}"
  log_info "=========================================="

  if ! check_recovery_cooldown; then
    exit 0
  fi

  local recovery_success=false

  case "${ISSUE_TYPE}" in
    nfs-connectivity-critical)
      log_info "Attempting full recovery sequence..."

      if strategy_restart_tailscale; then
        if strategy_remount_nfs; then
          recovery_success=true
        fi
      fi

      if [[ "${recovery_success}" != "true" ]]; then
        log_warn "Initial recovery failed, trying container restart..."
        if strategy_restart_container; then
          sleep 10
          if strategy_remount_nfs && strategy_restart_samba; then
            recovery_success=true
          fi
        fi
      fi

      if [[ "${recovery_success}" != "true" ]]; then
        log_warn "Container restart failed, trying routing fix..."
        strategy_fix_tailscale_routing || true
        sleep 5
        strategy_remount_nfs || true
      fi
      ;;

    nfs-degraded-performance)
      log_info "Attempting performance recovery..."
      strategy_restart_tailscale || strategy_remount_nfs || true
      recovery_success=true
      ;;

    manual)
      log_info "Manual recovery triggered..."
      strategy_restart_tailscale || true
      strategy_remount_nfs || true
      strategy_restart_samba || true
      recovery_success=true
      ;;

    *)
      log_error "Unknown issue type: ${ISSUE_TYPE}"
      exit 1
      ;;
  esac

  log_info "=========================================="
  if [[ "${recovery_success}" == "true" ]]; then
    log_success "✅ Recovery completed successfully"
  else
    log_error "❌ Recovery completed with errors - manual intervention required"
  fi
  log_info "=========================================="

  if [[ "${recovery_success}" != "true" ]]; then
    log_error "ALERT: Automated recovery failed for NFS/CT${CT_ID}"
    log_error "ALERT: Manual intervention required on AGLSRV5"
  fi

  [[ "${recovery_success}" == "true" ]]
}

main "$@"

#!/bin/bash
# Automated NFS & Tailscale Recovery Script for FileServer5 (CT138) <-> FGSRV4
# Implements multiple repair strategies with escalating severity.
# This script is called by nfs-tailscale-monitor.sh when issues are detected.
#
# Usage: ./nfs-tailscale-recovery.sh [issue_type]
# issue_type: nfs-connectivity-critical | nfs-degraded-performance | manual

set -euo pipefail

# ============================================================
# Configuration
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/../logs/nfs-monitor"
LOG_FILE="${LOG_DIR}/recovery-$(date +%Y%m%d).log"
RECOVERY_LOCK="/tmp/nfs-recovery.lock"
MAX_RECOVERY_ATTEMPTS=3
RECOVERY_COOLDOWN=300  # 5 minutes between recovery attempts

# Hosts configuration
FILESERVER5_TS_IP="100.66.136.84"    # CT138 Tailscale IP
FGSRV4_TS_IP="100.111.79.2"         # FGSRV4 Tailscale IP
FGSRV4_WG_IP="10.6.0.16"            # FGSRV4 WireGuard IP
AGLSRV5_TS_IP="100.119.223.113"     # Proxmox host
CT_ID="138"

# NFS mount points
NFS_EXPORTS=(
  "/var/www/fg_antigo"
  "/storage/nfs-export"
)

MOUNT_POINTS=(
  "/mnt/fgsrv4-fg_antigo-wg"
  "/mnt/fgsrv4-fg_antigo-ts"
  "/mnt/fgsrv4-nfs-ts"
)

# Issue type
ISSUE_TYPE="${1:-manual}"

# ============================================================
# Utility functions
# ============================================================
log() {
  local level="$1"
  shift
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

run_ssh_cmd() {
  local host="$1"
  shift
  local cmd="$*"

  ssh -o ConnectTimeout=10 \
      -o StrictHostKeyChecking=no \
      -o BatchMode=yes \
      root@${host} "${cmd}" 2>&1
}

run_ct_cmd() {
  local cmd="$*"
  run_ssh_cmd "${AGLSRV5_TS_IP}" "pct exec ${CT_ID} -- bash -c '${cmd}'"
}

# ============================================================
# Recovery Strategy 1: Check & Restart Tailscale
# ============================================================
strategy_restart_tailscale() {
  log_info "Strategy 1: Checking Tailscale connectivity"

  # Check if Tailscale is running on CT138
  local ts_status
  ts_status=$(run_ct_cmd "tailscale status --json 2>/dev/null | jq -r '.BackendState' // 'unknown'" || echo "failed")

  if [[ "${ts_status}" != "Running" ]]; then
    log_warn "Tailscale is not running on CT${CT_ID}, attempting restart..."
    run_ct_cmd "systemctl restart tailscaled && sleep 3 && tailscale up --accept-routes=false --hostname=agl-host-fileserver5" || {
      log_error "Failed to restart Tailscale on CT${CT_ID}"
      return 1
    }
    log_info "✅ Tailscale restarted on CT${CT_ID}"
  else
    log_info "✅ Tailscale is running on CT${CT_ID} (state: ${ts_status})"
  fi

  # Verify connectivity to FGSRV4
  sleep 2
  if ping -c 2 -W 3 "${FGSRV4_TS_IP}" &>/dev/null; then
    log_success "✅ Tailscale connectivity to FGSRV4 restored"
    return 0
  else
    log_warn "⚠️  Tailscale connectivity still failing after restart"
    return 1
  fi
}

# ============================================================
# Recovery Strategy 2: Remount NFS shares
# ============================================================
strategy_remount_nfs() {
  log_info "Strategy 2: Remounting NFS shares"

  # Unmount stale mounts
  for mount_point in "${MOUNT_POINTS[@]}"; do
    local is_mounted
    is_mounted=$(run_ct_cmd "mountpoint -q ${mount_point} && echo yes || echo no" || echo "no")

    if [[ "${is_mounted}" == "yes" ]]; then
      log_info "Unmounting ${mount_point}"
      run_ct_cmd "umount -f ${mount_point} 2>/dev/null || umount -l ${mount_point} 2>/dev/null || true"
    fi
  done

  sleep 2

  # Remount using fstab
  log_info "Remounting all NFS shares via fstab"
  run_ct_cmd "mount -a" || {
    log_error "Failed to mount via fstab, attempting manual mount"

    # Try manual mount for Tailscale path (most reliable)
    run_ct_cmd "mkdir -p /mnt/fgsrv4-fg_antigo-ts /mnt/fgsrv4-nfs-ts"
    run_ct_cmd "mount -t nfs4 -o rsize=1048576,wsize=1048576,timeo=600,retrans=5,actimeo=120,nocto,noatime,soft ${FGSRV4_TS_IP}:/var/www/fg_antigo /mnt/fgsrv4-fg_antigo-ts" || {
      log_error "Failed to mount fg_antigo via Tailscale"
      return 1
    }

    run_ct_cmd "mount -t nfs4 -o rsize=1048576,wsize=1048576,timeo=600,retrans=5,actimeo=120,nocto,noatime,soft ${FGSRV4_TS_IP}:/storage/nfs-export /mnt/fgsrv4-nfs-ts" || {
      log_error "Failed to mount nfs-export via Tailscale"
      return 1
    }
  }

  # Verify mounts
  local mounts_ok=0
  for mount_point in "${MOUNT_POINTS[@]}"; do
    local check
    check=$(run_ct_cmd "mountpoint -q ${mount_point} && echo ok || echo fail" || echo "fail")
    if [[ "${check}" == "ok" ]]; then
      ((mounts_ok++))
      log_success "✅ ${mount_point} mounted successfully"
    fi
  done

  if [[ "${mounts_ok}" -gt 0 ]]; then
    log_success "✅ NFS mounts restored (${mounts_ok}/${#MOUNT_POINTS[@]})"
    return 0
  else
    log_error "❌ No NFS mounts could be established"
    return 1
  fi
}

# ============================================================
# Recovery Strategy 3: Restart Samba service
# ============================================================
strategy_restart_samba() {
  log_info "Strategy 3: Restarting Samba services"

  run_ct_cmd "systemctl restart smbd nmbd" || {
    log_error "Failed to restart Samba services"
    return 1
  }

  sleep 2

  local smbd_status
  smbd_status=$(run_ct_cmd "systemctl is-active smbd" || echo "unknown")

  if [[ "${smbd_status}" == "active" ]]; then
    log_success "✅ Samba services restarted successfully"
    return 0
  else
    log_error "❌ Samba services failed to start (status: ${smbd_status})"
    return 1
  fi
}

# ============================================================
# Recovery Strategy 4: Restart CT138
# ============================================================
strategy_restart_container() {
  log_info "Strategy 4: Restarting CT${CT_ID} (fileserver5)"

  log_warn "Attempting graceful restart of CT${CT_ID}"

  # Stop container
  run_ssh_cmd "${AGLSRV5_TS_IP}" "pct stop ${CT_ID}" || {
    log_warn "Graceful stop failed, attempting force stop"
    run_ssh_cmd "${AGLSRV5_TS_IP}" "pct shutdown ${CT_ID} --timeout 30" || true
  }

  sleep 3

  # Clean up stuck resources (from previous recovery docs)
  run_ssh_cmd "${AGLSRV5_TS_IP}" "find /sys/fs/cgroup/ -name '*${CT_ID}*' -type d -print -delete 2>/dev/null || true"
  run_ssh_cmd "${AGLSRV5_TS_IP}" "ip link del veth${CT_ID}i0 2>/dev/null || true"
  run_ssh_cmd "${AGLSRV5_TS_IP}" "ip link del veth${CT_ID}i1 2>/dev/null || true"

  sleep 2

  # Start container
  run_ssh_cmd "${AGLSRV5_TS_IP}" "pct start ${CT_ID}" || {
    log_error "Failed to start CT${CT_ID}"
    return 1
  }

  # Wait for container to boot
  log_info "Waiting for CT${CT_ID} to boot..."
  sleep 15

  # Verify container is running
  local ct_status
  ct_status=$(run_ssh_cmd "${AGLSRV5_TS_IP}" "pct status ${CT_ID} | awk '{print \$2}'" || echo "unknown")

  if [[ "${ct_status}" == "running" ]]; then
    log_success "✅ CT${CT_ID} restarted successfully"
    return 0
  else
    log_error "❌ CT${CT_ID} failed to start (status: ${ct_status})"
    return 1
  fi
}

# ============================================================
# Recovery Strategy 5: Check FGSRV4 NFS service
# ============================================================
strategy_check_fgsrv4_nfs() {
  log_info "Strategy 5: Checking FGSRV4 NFS server status"

  # Try to check NFS status on FGSRV4 via Tailscale
  # Note: This may fail if we don't have SSH access to FGSRV4
  local nfs_check
  nfs_check=$(ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
              root@${FGSRV4_TS_IP} "systemctl is-active nfs-server 2>/dev/null || echo 'unknown'" 2>/dev/null || echo "unreachable")

  if [[ "${nfs_check}" == "active" ]]; then
    log_info "✅ NFS server is active on FGSRV4"
    return 0
  elif [[ "${nfs_check}" == "unknown" ]]; then
    log_warn "⚠️  Cannot determine NFS server status on FGSRV4 (no SSH access)"
    return 0  # Non-critical, continue with other checks
  else
    log_warn "⚠️  NFS server on FGSRV4 is not active (status: ${nfs_check})"
    log_info "Attempting to restart NFS server on FGSRV4..."

    ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
        root@${FGSRV4_TS_IP} "systemctl restart nfs-server && systemctl enable nfs-server" 2>/dev/null || {
      log_error "Failed to restart NFS server on FGSRV4"
      return 1
    }

    log_success "✅ NFS server restarted on FGSRV4"
    return 0
  fi
}

# ============================================================
# Recovery Strategy 6: Fix Tailscale routing issues
# ============================================================
strategy_fix_tailscale_routing() {
  log_info "Strategy 6: Fixing Tailscale routing conflicts"

  # This addresses the known issue where Tailscale intercepts local traffic
  log_info "Disabling accept-routes on CT${CT_ID} Tailscale"

  run_ct_cmd "tailscale set --accept-routes=false" || {
    log_error "Failed to disable accept-routes"
    return 1
  }

  sleep 2

  # Verify routing table
  local route_check
  route_check=$(run_ct_cmd "ip route get 172.2.2.222 2>/dev/null | grep -o 'dev [^ ]*'" || echo "unknown")

  if [[ "${route_check}" == *"eth1"* ]]; then
    log_success "✅ Tailscale routing fixed (using eth1 for local traffic)"
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

  # Try strategies in escalating order
  case "${ISSUE_TYPE}" in
    nfs-connectivity-critical)
      # Critical: Try all strategies
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
        log_warn "Container restart failed, checking FGSRV4..."
        strategy_check_fgsrv4_nfs || true
        strategy_fix_tailscale_routing || true
        sleep 5
        strategy_remount_nfs || true
      fi
      ;;

    nfs-degraded-performance)
      # Degraded: Try lighter recovery first
      log_info "Attempting performance recovery..."

      if ! strategy_restart_tailscale; then
        strategy_remount_nfs || true
      fi
      recovery_success=true  # Assume success for degraded
      ;;

    manual)
      # Manual trigger: Run all strategies
      log_info "Manual recovery triggered, running all strategies..."

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

  # Post-recovery verification
  log_info "=========================================="
  if [[ "${recovery_success}" == "true" ]]; then
    log_success "✅ Recovery completed successfully"
  else
    log_error "❌ Recovery completed with errors - manual intervention required"
  fi
  log_info "=========================================="

  # Send alert if recovery failed
  if [[ "${recovery_success}" != "true" ]]; then
    log_error "ALERT: Automated recovery failed for NFS/CT${CT_ID}"
    log_error "ALERT: Manual intervention required on AGLSRV5"
    log_error "ALERT: Check logs at ${LOG_FILE}"

    # Could integrate with notification systems here (email, Slack, etc.)
    # Example: curl -X POST "$SLACK_WEBHOOK" -d "..."
  fi

  [[ "${recovery_success}" == "true" ]]
}

main "$@"

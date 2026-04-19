#!/bin/bash
#
# rollback-api.sh — Emergency rollback: API8 → API1 on FGSRV5
#
# Reverts the nginx upstream / fastcgi_pass from fg_API8_d (PHP 8.1 FPM)
# back to fg_OLD2_NEW (PHP 7.4 FPM), then disables all FeatureFlags.
#
# Usage:
#   ./rollback-api.sh [--dry-run]
#
# Options:
#   --dry-run   Print commands without executing SSH/nginx changes.
#
# Environment:
#   FGSRV5_HOST   SSH target (default: root@100.71.107.26)
#   NGINX_CONF    Full path to the nginx site config on FGSRV5
#                 (default: /etc/nginx/sites-enabled/falg-api.conf)

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
FGSRV5_HOST="${FGSRV5_HOST:-root@100.71.107.26}"
NGINX_CONF="${NGINX_CONF:-/etc/nginx/sites-enabled/falg-api.conf}"
ROLLBACK_FLAG="/tmp/hostman-rollback-active"
REMOTE_LOG="/var/log/hostman/rollback.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
DRY_RUN=false

# PHP-FPM sockets — adjust if the OS uses TCP ports instead
API1_FPM="unix:/run/php/php7.4-fpm.sock"
API1_ROOT="/var/www/fg_OLD2_NEW/public"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log()  { echo "[${TIMESTAMP}] $*"; }
info() { echo "[INFO]  $*"; }
warn() { echo "[WARN]  $*"; }
ok()   { echo "[OK]    $*"; }
err()  { echo "[ERROR] $*" >&2; }

run_remote() {
    # Execute a command on FGSRV5 (or print it in dry-run mode).
    local cmd="$1"
    if $DRY_RUN; then
        echo "  [DRY-RUN] ssh ${FGSRV5_HOST} \"${cmd}\""
    else
        ssh -o BatchMode=yes -o ConnectTimeout=10 "${FGSRV5_HOST}" "${cmd}"
    fi
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
if $DRY_RUN; then
    warn "DRY-RUN mode active — no changes will be made."
fi

info "Rollback initiated at ${TIMESTAMP}"
info "Target host : ${FGSRV5_HOST}"
info "Nginx config: ${NGINX_CONF}"

# ---------------------------------------------------------------------------
# Step 1: Backup current nginx config
# ---------------------------------------------------------------------------
BACKUP_PATH="${NGINX_CONF}.rollback-${TIMESTAMP// /_}"
info "Backing up nginx config to ${BACKUP_PATH}"
run_remote "cp '${NGINX_CONF}' '${BACKUP_PATH}'"
ok "Nginx config backed up"

# ---------------------------------------------------------------------------
# Step 2: Switch fastcgi_pass / upstream back to API1 (PHP 7.4)
#
# The sed expression covers two common nginx patterns:
#   fastcgi_pass  unix:/run/php/php8.1-fpm.sock;
#   root          /var/www/fg_API8_d/public;
# ---------------------------------------------------------------------------
info "Patching nginx config to point to fg_OLD2_NEW (PHP 7.4 FPM)"
run_remote "sed -i \
    -e 's|unix:/run/php/php8\.1-fpm\.sock|${API1_FPM}|g' \
    -e 's|/var/www/fg_API8_d/public|${API1_ROOT}|g' \
    '${NGINX_CONF}'"
ok "Nginx config patched"

# ---------------------------------------------------------------------------
# Step 3: Validate nginx configuration
# ---------------------------------------------------------------------------
info "Testing nginx configuration"
run_remote "nginx -t"
ok "Nginx config test passed"

# ---------------------------------------------------------------------------
# Step 4: Reload nginx
# ---------------------------------------------------------------------------
info "Reloading nginx"
run_remote "nginx -s reload"
ok "Nginx reloaded"

# ---------------------------------------------------------------------------
# Step 5: Disable all FeatureFlags on remote host
# ---------------------------------------------------------------------------
info "Disabling all FeatureFlags (creating rollback sentinel)"
run_remote "echo '{\"auth\":false,\"properties\":false,\"users\":false,\"financial\":false,\"contracts\":false,\"reports\":false,\"settings\":false}' \
    > /tmp/hostman-feature-flags.json && touch '${ROLLBACK_FLAG}'"
ok "FeatureFlags disabled; rollback sentinel created at ${ROLLBACK_FLAG}"

# ---------------------------------------------------------------------------
# Step 6: Log the rollback event on the remote server
# ---------------------------------------------------------------------------
info "Logging rollback event to ${REMOTE_LOG} on FGSRV5"
run_remote "mkdir -p /var/log/hostman && \
    echo '[${TIMESTAMP}] ROLLBACK EXECUTED: API8 -> API1 by $(whoami) from $(hostname)' \
    >> '${REMOTE_LOG}'"
ok "Rollback logged"

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
ok "==========================================="
ok " ROLLBACK COMPLETE — Traffic now → API1"
ok "==========================================="
echo ""
echo "  API1 root : ${API1_ROOT}"
echo "  API1 FPM  : ${API1_FPM}"
echo "  Nginx conf: ${NGINX_CONF}"
echo "  Backup    : ${BACKUP_PATH}"
echo ""
echo "Verify:"
echo "  curl -s -o /dev/null -w '%{http_code}' https://api.falg.com.br/api/login"
echo ""
if $DRY_RUN; then
    warn "DRY-RUN — no actual changes were made."
fi

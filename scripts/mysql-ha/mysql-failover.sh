#!/bin/bash
#
# MySQL HA Failover Script with Cloudflare Tunnel DNS
# Monitors MySQL Master and triggers failover to Slave
#
# Architecture:
#   Topologia 2026-06: CT561 (mysql7) = MASTER · CT535 (mysql5) = SLAVE read_only (ex.235/135).
#   Túneis Cloudflare / DNS: validar destinos em config.yml (CT530/CT570; ex.130/170).
#
# On failover (slave CT135 promovido): CNAME mysql-ha / db-ha → túnel que alcança AGLSRV5
# (CF_FAILOVER_DNS_TUNNEL, por omissão = CF_MASTER_TUNNEL). Enquanto o master CT235 está UP,
# o estado “túnel activo” segue CF_PRIMARY_MASTER_TUNNEL (por omissão = CF_SLAVE_TUNNEL / FGSRV7).
#

set -e

# Configuration
CONFIG_FILE="/etc/mysql-ha/mysql-failover.conf"
STATE_FILE="/var/lib/mysql-ha/failover.state"
LOG_FILE="/var/log/mysql-failover.log"

# Load configuration
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi

# Defaults nomes legados CF_*: master CT235 via FGSRV7 = CF_SLAVE_TUNNEL; pós-failover DNS → CF_MASTER_TUNNEL (AGLSRV5).
CF_PRIMARY_MASTER_TUNNEL="${CF_PRIMARY_MASTER_TUNNEL:-$CF_SLAVE_TUNNEL}"
CF_FAILOVER_DNS_TUNNEL="${CF_FAILOVER_DNS_TUNNEL:-$CF_MASTER_TUNNEL}"

# Ensure state directory exists
mkdir -p "$(dirname "$STATE_FILE")"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
    echo "$1"
}

# Initialize state file
init_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        echo "MASTER_UP=true" > "$STATE_FILE"
        echo "FAILURE_COUNT=0" >> "$STATE_FILE"
        echo "CURRENT_MASTER=${CF_PRIMARY_MASTER_TUNNEL}" >> "$STATE_FILE"
        echo "LAST_FAILOVER=0" >> "$STATE_FILE"
    fi
    source "$STATE_FILE"
}

# Save state
save_state() {
    echo "MASTER_UP=$MASTER_UP" > "$STATE_FILE"
    echo "FAILURE_COUNT=$FAILURE_COUNT" >> "$STATE_FILE"
    echo "CURRENT_MASTER=$CURRENT_MASTER" >> "$STATE_FILE"
    echo "LAST_FAILOVER=$LAST_FAILOVER" >> "$STATE_FILE"
}

# Check MySQL Master health via Tailscale
check_master_health() {
    local attempts=0
    local max_attempts=3

    while [[ $attempts -lt $max_attempts ]]; do
        # Try to connect and run a simple query
        if mysql -h "${MASTER_MYSQL_IP}" -u "${MYSQL_USER}" -p"${MYSQL_PASS}" \
           -e "SELECT 1;" &>/dev/null; then
            return 0
        fi

        # Also check if replication is working (from slave perspective)
        if [[ "${ROLE}" == "slave" ]]; then
            if mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" \
               -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -q "Slave_IO_Running: Yes"; then
                return 0
            fi
        fi

        attempts=$((attempts + 1))
        sleep 2
    done

    return 1
}

# Promote slave to master
promote_slave() {
    log "PROMOTING SLAVE TO MASTER..."

    # Stop slave replication
    mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" -e "STOP SLAVE; RESET SLAVE ALL;"

    # Disable read-only
    mysql -u "${MYSQL_USER}" -p"${MYSQL_PASS}" -e "SET GLOBAL read_only = OFF;"

    log "Slave promoted successfully"
}

# Update Cloudflare DNS CNAME
update_cloudflare_dns() {
    local record_id="$1"
    local record_name="$2"
    local new_tunnel="$3"

    log "Updating Cloudflare DNS: ${record_name}.falg.com.br -> ${new_tunnel}"

    local response
    response=$(curl -s -X PUT \
        "https://api.cloudflare.com/client/v4/zones/${CF_ZONE_ID}/dns_records/${record_id}" \
        -H "X-Auth-Email: ${CF_EMAIL}" \
        -H "X-Auth-Key: ${CF_API_KEY}" \
        -H "Content-Type: application/json" \
        --data "{
            \"type\": \"CNAME\",
            \"name\": \"${record_name}\",
            \"content\": \"${new_tunnel}\",
            \"ttl\": ${CF_TTL},
            \"proxied\": ${CF_PROXIED}
        }")

    if echo "$response" | jq -e '.success == true' &>/dev/null; then
        log "DNS updated: ${record_name}.falg.com.br"
        return 0
    else
        log "ERROR: Failed to update DNS: $(echo "$response" | jq -r '.errors[0].message' 2>/dev/null || echo "$response")"
        return 1
    fi
}

# Send notification
send_notification() {
    local message="$1"
    log "Notification: $message"

    if [[ -n "${WEBHOOK_URL}" ]]; then
        curl -s -X POST "${WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "{\"text\": \"${message}\"}" &>/dev/null || true
    fi
}

# Main failover logic
perform_failover() {
    log "========================================="
    log "STARTING FAILOVER PROCEDURE"
    log "========================================="

    # Check if we're in cooldown period
    local current_time=$(date +%s)
    local time_since_last=$((current_time - LAST_FAILOVER))

    if [[ $time_since_last -lt $FAILOVER_COOLDOWN ]]; then
        log "In cooldown period (${time_since_last}s < ${FAILOVER_COOLDOWN}s), skipping failover"
        return 1
    fi

    # Promote this server (slave) to master
    if promote_slave; then
        # mysql-ha / db-ha → túnel onde o promovido (CT135) é alcançável (tipicamente AGLSRV5)
        local failover_success=true

        if ! update_cloudflare_dns "${CF_MYSQL_HA_ID}" "mysql-ha" "${CF_FAILOVER_DNS_TUNNEL}"; then
            failover_success=false
        fi

        if ! update_cloudflare_dns "${CF_DB_HA_ID}" "db-ha" "${CF_FAILOVER_DNS_TUNNEL}"; then
            failover_success=false
        fi

        if [[ "$failover_success" == "true" ]]; then
            # Update state
            MASTER_UP="true"
            FAILURE_COUNT=0
            CURRENT_MASTER="${CF_FAILOVER_DNS_TUNNEL}"
            LAST_FAILOVER=$current_time
            save_state

            send_notification "MySQL Failover: DNS mysql-ha/db-ha → túnel pós-promoção (CT135)"

            log "FAILOVER COMPLETED SUCCESSFULLY"
            return 0
        else
            log "ERROR: Failover failed at DNS update stage"
            return 1
        fi
    else
        log "ERROR: Failed to promote slave"
        return 1
    fi
}

# Main monitoring loop
main() {
    init_state

    log "--- Health Check ---"
    log "Role: ${ROLE}"
    log "Current Master Tunnel: ${CURRENT_MASTER}"
    log "Master MySQL (Tailscale): ${MASTER_MYSQL_IP}"
    log "This Server: ${THIS_SERVER_TUNNEL}"

    # Check master health
    if check_master_health; then
        if [[ "$MASTER_UP" != "true" ]]; then
            log "Master recovered!"
            send_notification "MySQL: Master ${MASTER_MYSQL_IP} recovered"
        fi

        MASTER_UP="true"
        FAILURE_COUNT=0
        save_state
        log "Master is healthy"
        exit 0

    else
        # Master is not responding
        FAILURE_COUNT=$((FAILURE_COUNT + 1))
        log "Master check failed (attempt $FAILURE_COUNT/$MAX_FAILURES)"

        if [[ $FAILURE_COUNT -ge $MAX_FAILURES ]]; then
            log "CRITICAL: Master has failed $FAILURE_COUNT times!"

            if [[ "$ROLE" == "slave" ]]; then
                perform_failover
            else
                log "This server is not configured as slave, cannot failover"
            fi
        fi

        MASTER_UP="false"
        save_state
        exit 1
    fi
}

# Run main function
main "$@"

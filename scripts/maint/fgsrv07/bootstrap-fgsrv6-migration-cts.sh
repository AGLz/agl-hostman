#!/usr/bin/env bash
# Bootstrap CTs 572/573/576 após provision-fgsrv6-migration-cts.sh
# Migra dados do FGSRV6 (rsync) e backup local .local/fgsrv6-backup-*.
#
# Uso (root FGSRV7):
#   REPO=/path/agl-hostman BACKUP_DIR=.../fgsrv6-backup-20260603 \
#     bash scripts/maint/fgsrv07/bootstrap-fgsrv6-migration-cts.sh
#
# Variáveis:
#   FGSRV6=root@100.83.51.9
#   REPO — caminho agl-hostman no host que corre o script (ou via pct push)
#   BACKUP_DIR — .local/fgsrv6-backup-YYYYMMDD (wireguard, n8n volume)
#   SKIP_RSYNC=1 — não copiar /var/www (já feito)
#   SKIP_WG_START=1 — default; não levantar wg0 até cutover

set -euo pipefail

FGSRV6="${FGSRV6:-root@100.83.51.9}"
REPO="${REPO:-}"
BACKUP_DIR="${BACKUP_DIR:-}"
SKIP_RSYNC="${SKIP_RSYNC:-0}"
SKIP_WG_START="${SKIP_WG_START:-1}"
SSH_OPTS=(-o BatchMode=yes -o ConnectTimeout=20)
# Reason: rsync -e exige uma única string de comando; construir a partir do array evita
# word-splitting incorrecto ao interpolar ${SSH_OPTS[*]} dentro de aspas duplas.
RSYNC_RSH=(ssh "${SSH_OPTS[@]}")
MOUNT_BASE="/mnt/pve-fgsrv6-migrate"

log() { printf '[%s] %s\n' "$(date +%H:%M:%S)" "$*"; }

_ensure_running() {
    local vmid="$1"
    if ! pct status "${vmid}" 2>&1 | grep -qi running; then
        pct start "${vmid}"
        sleep 4
    fi
}

_apt_base() {
    local vmid="$1"
    pct exec "${vmid}" -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq ca-certificates curl gnupg rsync openssh-server
    '
}

bootstrap_572() {
    log "Bootstrap CT572 fg-apis (nginx + PHP 8.4)"
    _ensure_running 572
    _apt_base 572
    pct exec 572 -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y -qq nginx php-fpm php-cli php-mysql php-xml php-mbstring php-curl php-zip php-gd
        mkdir -p /var/www
        chown -R www-data:www-data /var/www
        systemctl enable nginx php8.2-fpm
        systemctl restart nginx php8.2-fpm
    '

    if [[ "${SKIP_RSYNC}" != "1" ]]; then
        log "Rsync /var/www FGSRV6 → CT572 (via pct mount)"
        pct mount 572
        local mnt="/var/lib/lxc/572/rootfs"
        if mountpoint -q "${mnt}"; then
            mkdir -p "${mnt}/var/www" "${mnt}/etc/nginx"
            rsync -aHAX --info=progress2 -e "${RSYNC_RSH[*]}" \
                "${FGSRV6}:/var/www/" "${mnt}/var/www/"
            rsync -aHAX -e "${RSYNC_RSH[*]}" \
                "${FGSRV6}:/etc/nginx/sites-available/" "${mnt}/etc/nginx/sites-available/" 2>/dev/null || true
            rsync -aHAX -e "${RSYNC_RSH[*]}" \
                "${FGSRV6}:/etc/nginx/sites-enabled/" "${mnt}/etc/nginx/sites-enabled/" 2>/dev/null || true
            chown -R 100000:100000 "${mnt}/var/www" 2>/dev/null || true
            pct unmount 572
        else
            log "WARN: pct mount falhou — rsync via rede para IP CT572"
            pct exec 572 -- mkdir -p /var/www
            pct exec 572 -- bash -c "apt-get install -y -qq rsync openssh-client && rsync -aHAX -e '${RSYNC_RSH[*]}' ${FGSRV6}:/var/www/ /var/www/"
        fi
    fi

    pct exec 572 -- nginx -t && pct exec 572 -- systemctl restart nginx
    log "CT572: nginx active"
}

bootstrap_573() {
    log "Bootstrap CT573 n8n7 (Docker + n8n)"
    _ensure_running 573
    _apt_base 573
    pct exec 573 -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y -qq docker.io docker-compose
        systemctl enable --now docker
        mkdir -p /opt/n8n
    '

    pct exec 573 -- bash -c 'cat > /opt/n8n/docker-compose.yml' <<'YAML'
services:
  n8n:
    image: docker.n8n.io/n8nio/n8n
    container_name: n8n-n8n-1
    restart: unless-stopped
    ports:
      - "192.168.70.247:5678:5678"
    environment:
      - N8N_HOST=n8n5e.aglz.io
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - WEBHOOK_URL=https://n8n5e.aglz.io/
      - GENERIC_TIMEZONE=America/Sao_Paulo
      - TZ=America/Sao_Paulo
    volumes:
      - n8n_data:/home/node/.n8n
volumes:
  n8n_data:
YAML

    if [[ -n "${BACKUP_DIR}" && -f "${BACKUP_DIR}/docker-volumes/n8n_data.tar.gz" ]]; then
        log "Restore n8n_data volume"
        pct push 573 "${BACKUP_DIR}/docker-volumes/n8n_data.tar.gz" /tmp/n8n_data.tar.gz
        pct exec 573 -- bash -c '
            docker volume create n8n_data
            docker run --rm -v n8n_data:/data -v /tmp:/backup alpine \
                sh -c "cd /data && tar xzf /backup/n8n_data.tar.gz"
            rm -f /tmp/n8n_data.tar.gz
        '
    fi

    pct exec 573 -- bash -c 'cd /opt/n8n && docker compose up -d 2>/dev/null || docker-compose up -d'
    log "CT573: n8n listening 127.0.0.1:5678 (ingress via cloudflared6)"
}

bootstrap_576() {
    log "Bootstrap CT576 wireguard6"
    _ensure_running 576
    _apt_base 576

    pct exec 576 -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y -qq wireguard wireguard-tools iptables
        sysctl -w net.ipv4.ip_forward=1
        grep -q ip_forward /etc/sysctl.conf || echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
    '

    if [[ -n "${BACKUP_DIR}" && -f "${BACKUP_DIR}/wireguard/wg0.conf" ]]; then
        pct push 576 "${BACKUP_DIR}/wireguard/wg0.conf" /etc/wireguard/wg0.conf
        pct exec 576 -- chmod 600 /etc/wireguard/wg0.conf
        log "wg0.conf restaurado (hub 10.6.0.5)"
    else
        log "WARN: BACKUP_DIR/wireguard/wg0.conf ausente — copiar manualmente"
    fi

    if [[ "${SKIP_WG_START}" == "1" ]]; then
        pct exec 576 -- systemctl disable wg-quick@wg0 2>/dev/null || true
        log "CT576: wg0 NÃO iniciado (SKIP_WG_START=1) — cutover posterior"
    else
        pct exec 576 -- systemctl enable wg-quick@wg0
        pct exec 576 -- systemctl start wg-quick@wg0
        pct exec 576 -- wg show
    fi
}

if [[ -z "${BACKUP_DIR}" && -n "${REPO}" ]]; then
    BACKUP_DIR="$(ls -dt "${REPO}"/.local/fgsrv6-backup-* 2>/dev/null | head -1 || true)"
fi

bootstrap_572
bootstrap_573
bootstrap_576
log "Bootstrap concluído."

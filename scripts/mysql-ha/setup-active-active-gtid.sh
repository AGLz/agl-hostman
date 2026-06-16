#!/usr/bin/env bash
# Configura réplicação circular GTID MariaDB: mysql7 (CT561) <-> mysql5 (CT535).
# Executar no host com pct (FGSRV7 para mysql7, AGLSRV5 para mysql5) ou via SSH remoto.
#
# Pré-requisitos:
# - Tailscale entre nós (mysql7 ~100.93.174.11, mysql5 ~100.98.1.119)
# - Utilizador repl@% com mesma password nos dois lados
# - Bases alinhadas (se divergência GTID, correr resync antes — ver docs)
#
# Uso (cofre para passwords):
#   export MYSQL7_ROOT_PASSWORD='...'
#   export MYSQL5_ROOT_PASSWORD='...'
#   export MYSQL_REPL_PASSWORD='...'
#   bash scripts/mysql-ha/setup-active-active-gtid.sh apply
#
# Subcomandos: apply | status | resync-mysql5-from-mysql7
set -euo pipefail

MYSQL7_CT="${MYSQL7_CT:-561}"
MYSQL5_CT="${MYSQL5_CT:-535}"
MYSQL7_TS="${MYSQL7_TS:-100.93.174.11}"
MYSQL5_TS="${MYSQL5_TS:-100.98.1.119}"
MYSQL7_SERVER_ID="${MYSQL7_SERVER_ID:-235}"
MYSQL5_SERVER_ID="${MYSQL5_SERVER_ID:-135}"
REPL_USER="${MYSQL_REPL_USER:-repl}"
REPL_PW="${MYSQL_REPL_PASSWORD:?Definir MYSQL_REPL_PASSWORD}"
M7_ROOT="${MYSQL7_ROOT_PASSWORD:?Definir MYSQL7_ROOT_PASSWORD}"
M5_ROOT="${MYSQL5_ROOT_PASSWORD:?Definir MYSQL5_ROOT_PASSWORD}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[active-active] %s\n' "$*"; }

pct_mysql() {
  local ct="$1"
  local host_pw="$2"
  shift 2
  pct exec "${ct}" -- mysql -uroot -p"${host_pw}" "$@"
}

pct_bash() {
  local ct="$1"
  shift
  pct exec "${ct}" -- bash -s "$@"
}

push_node_config() {
  local ct="$1"
  local server_id="$2"
  local offset="$3"
  log "CT${ct}: aplicar config active-active (server_id=${server_id}, offset=${offset})"
  pct push "${ct}" "${SCRIPT_DIR}/mariadb-active-active.cnf" /etc/mysql/mariadb.conf.d/50-active-active.cnf
  pct exec "${ct}" -- bash -c "cat > /etc/mysql/mariadb.conf.d/51-active-active-node.cnf <<EOF
[mysqld]
server_id = ${server_id}
auto_increment_offset = ${offset}
EOF"
  pct exec "${ct}" -- sed -i '/^read_only/d' /etc/mysql/mariadb.conf.d/50-ha-replication.cnf 2>/dev/null || true
  pct exec "${ct}" -- mariadbd --validate-config 2>/dev/null || pct exec "${ct}" -- mysqld --validate-config 2>/dev/null || true
  pct exec "${ct}" -- systemctl restart mariadb
}

ensure_repl_user() {
  local ct="$1"
  local root_pw="$2"
  log "CT${ct}: garantir ${REPL_USER}@%"
  pct_mysql "${ct}" "${root_pw}" -e "
    CREATE USER IF NOT EXISTS '${REPL_USER}'@'%' IDENTIFIED BY '${REPL_PW}';
    GRANT REPLICATION SLAVE ON *.* TO '${REPL_USER}'@'%';
    FLUSH PRIVILEGES;
  "
}

setup_mysql5_slave_to_mysql7() {
  log "CT${MYSQL5_CT}: slave -> mysql7"
  pct_mysql "${MYSQL5_CT}" "${M5_ROOT}" -e "
    STOP SLAVE;
    CHANGE MASTER TO
      MASTER_HOST='${MYSQL7_TS}',
      MASTER_USER='${REPL_USER}',
      MASTER_PASSWORD='${REPL_PW}',
      MASTER_PORT=3306,
      MASTER_USE_GTID=slave_pos;
    START SLAVE;
    SET GLOBAL read_only = OFF;
  "
}

setup_mysql7_slave_to_mysql5() {
  log "CT${MYSQL7_CT}: slave -> mysql5 (2.º sentido)"
  pct_mysql "${MYSQL7_CT}" "${M7_ROOT}" -e "
    STOP SLAVE;
    CHANGE MASTER TO
      MASTER_HOST='${MYSQL5_TS}',
      MASTER_USER='${REPL_USER}',
      MASTER_PASSWORD='${REPL_PW}',
      MASTER_PORT=3306,
      MASTER_USE_GTID=current_pos;
    START SLAVE;
    SET GLOBAL read_only = OFF;
  "
}

cmd_status() {
  log "=== mysql7 (CT${MYSQL7_CT}) ==="
  pct_mysql "${MYSQL7_CT}" "${M7_ROOT}" -e "
    SELECT @@server_id, @@read_only, @@auto_increment_increment, @@auto_increment_offset, @@log_slave_updates, @@gtid_current_pos;
    SHOW SLAVE STATUS\G
  " 2>/dev/null | grep -E "@@|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind|Master_Host|Last_.*Error" || true

  log "=== mysql5 (CT${MYSQL5_CT}) ==="
  pct_mysql "${MYSQL5_CT}" "${M5_ROOT}" -e "
    SELECT @@server_id, @@read_only, @@auto_increment_increment, @@auto_increment_offset, @@log_slave_updates, @@gtid_current_pos;
    SHOW SLAVE STATUS\G
  " 2>/dev/null | grep -E "@@|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind|Master_Host|Last_.*Error" || true
}

cmd_resync() {
  log "Resync mysql5 a partir de mysql7 (falgimoveis11) — janela de manutenção"
  pct_mysql "${MYSQL5_CT}" "${M5_ROOT}" -e "STOP SLAVE; RESET SLAVE ALL; RESET MASTER;"
  pct exec "${MYSQL5_CT}" -- bash -c "
    mysqldump -h '${MYSQL7_TS}' -uroot -p'${M7_ROOT}' --single-transaction --gtid --add-drop-database --databases falgimoveis11 \
      | mysql -uroot -p'${M5_ROOT}'
  "
  setup_mysql5_slave_to_mysql7
}

cmd_apply() {
  command -v pct >/dev/null || { echo "pct necessário (Proxmox)" >&2; exit 1; }

  ensure_repl_user "${MYSQL7_CT}" "${M7_ROOT}"
  ensure_repl_user "${MYSQL5_CT}" "${M5_ROOT}"

  push_node_config "${MYSQL7_CT}" "${MYSQL7_SERVER_ID}" 1
  push_node_config "${MYSQL5_CT}" "${MYSQL5_SERVER_ID}" 2

  setup_mysql5_slave_to_mysql7
  setup_mysql7_slave_to_mysql5

  log "Desactivar failover automático (master-slave) se existir no CT${MYSQL5_CT}"
  pct exec "${MYSQL5_CT}" -- bash -c "
    crontab -l 2>/dev/null | grep -v mysql-failover | crontab - 2>/dev/null || true
    systemctl disable --now mysql-failover.timer 2>/dev/null || true
  " || true

  cmd_status
  log "Concluído. Validar com testes de escrita em ambos os nós."
}

case "${1:-status}" in
  apply) cmd_apply ;;
  status) cmd_status ;;
  resync-mysql5-from-mysql7) cmd_resync ;;
  *)
    echo "Uso: $0 {apply|status|resync-mysql5-from-mysql7}" >&2
    exit 1
    ;;
esac

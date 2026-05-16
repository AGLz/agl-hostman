#!/usr/bin/env bash
# Reason: alargar acessos MySQL no CT235 (master HA / mysql7) para VPS FALG via Tailscale.
#
# Executar no host FGSRV7 (Proxmox) como root, com CT235 ativo:
#   export MYSQL_ROOT_PASSWORD='...'   # password do root no CT235
#   # opcional: password que os clientes usarão (default = root)
#   # export MYSQL_REMOTE_PASSWORD='...'
#   # opcional: padrão de host em vez de 100.% (ex.: 100.64.% — só 1 /24)
#   # export MYSQL_HOST_PATTERN='100.%'
#   ./scripts/mysql-ha/grant-vps-tailscale-admin.sh
#
# AVISOS:
# - *.* + GRANT OPTION = administração total (inclui criar bases e utilizadores).
# - O padrão default de host é 100.% (qualquer cliente 100.x.x.x). Mais largo que
#   a tailnet Tailscale (/10); reduzir MYSQL_HOST_PATTERN se quiseres menos exposição.
# - O slave read_only é o CT135: DDL (CREATE DATABASE) deve ser no master CT235;
#   ou desativar read_only só em janelas controladas no slave.
set -euo pipefail

CT_ID="${MYSQL_CT_ID:-235}"
ROOT_PW="${MYSQL_ROOT_PASSWORD:?Definir MYSQL_ROOT_PASSWORD (root no CT235).}"
REMOTE_PW="${MYSQL_REMOTE_PASSWORD:-$ROOT_PW}"
HOST_PATTERN="${MYSQL_HOST_PATTERN:-100.%}"

if ! command -v pct >/dev/null 2>&1; then
  echo "Este script deve correr no Proxmox (pct disponível), tipicamente FGSRV7." >&2
  exit 1
fi

if [[ ! "${HOST_PATTERN}" =~ ^[0-9.%_]+$ ]]; then
  echo "MYSQL_HOST_PATTERN inválido (só dígitos, ., %, _)." >&2
  exit 1
fi

if [[ "${ROOT_PW}" == *"'"* ]] || [[ "${REMOTE_PW}" == *"'"* ]] || [[ "${REMOTE_PW}" == *'\\'* ]]; then
  echo "Password não pode conter aspas simples nem \\ neste script; usa .cnf manual." >&2
  exit 1
fi

# Escapar aspas simples para SQL (duplicar ')
sql_escape() {
  printf '%s' "$1" | sed "s/'/''/g"
}

REMOTE_PW_SQL=$(sql_escape "${REMOTE_PW}")

run_mysql() {
  local sql="$1"
  pct exec "${CT_ID}" -- env MYSQL_PWD="${ROOT_PW}" mysql -u root -N -e "${sql}"
}

echo "A aplicar GRANTs no CT${CT_ID} para 'root'@'${HOST_PATTERN}' (password de cliente = remota definida por MYSQL_REMOTE_PASSWORD)..."
run_mysql "CREATE USER IF NOT EXISTS 'root'@'${HOST_PATTERN}' IDENTIFIED BY '${REMOTE_PW_SQL}';"
run_mysql "ALTER USER 'root'@'${HOST_PATTERN}' IDENTIFIED BY '${REMOTE_PW_SQL}';"
run_mysql "GRANT ALL PRIVILEGES ON *.* TO 'root'@'${HOST_PATTERN}' WITH GRANT OPTION;"
run_mysql "FLUSH PRIVILEGES;"

echo "Concluído. Verificar com:"
echo "  pct exec ${CT_ID} -- mysql -u root -p ... -e \"SELECT user, host FROM mysql.user WHERE user='root' ORDER BY host;\""

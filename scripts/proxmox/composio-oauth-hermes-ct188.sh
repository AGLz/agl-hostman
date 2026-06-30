#!/usr/bin/env bash
# Composio Connect MCP no Hermes CT188 — API key + OAuth MCP (login.composio.dev).
#
# A Composio exige o header x-consumer-api-key mesmo quando auth: oauth está activo.
# Sem tokens OAuth, o gateway reintenta em loop — use --disable-until-login para calmar.
#
# Uso (root no CT188 ou SSH):
#   export COMPOSIO_API_KEY='ck_...'   # dashboard.composio.dev
#   bash composio-oauth-hermes-ct188.sh configure
#   bash composio-oauth-hermes-ct188.sh login      # TTY interactivo (colar URL redirect)
#   bash composio-oauth-hermes-ct188.sh test
#   bash composio-oauth-hermes-ct188.sh status
#
#   bash composio-oauth-hermes-ct188.sh configure --disable-until-login
#   bash composio-oauth-hermes-ct188.sh enable     # após login + test OK
#
# Login interactivo (recomendado):
#   1. docker exec -it -e HERMES_HOME=/opt/data agl-hermes-jarvis hermes mcp login composio
#   2. Abrir a URL no browser; após autorizar, copiar a URL completa da barra
#      (mesmo com "connection refused" em 127.0.0.1:18432) e colar no terminal.
#
# Túnel SSH (alternativa): o listener OAuth corre DENTRO do contentor em 127.0.0.1:18432.
#   Terminal A (CT188): docker exec -it ... hermes mcp login composio
#   Terminal B (CT188): socat com --network container:agl-hermes-jarvis (ver função tunnel abaixo)
#   Terminal C (PC):    ssh -N -L 18432:127.0.0.1:18432 root@192.168.0.188

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_CONTAINER="${HERMES_CONTAINER:-agl-hermes-jarvis}"
# Perfil data: jarvis → data/ ; outros agentes → profiles/<agent>/
if [[ -z "${HERMES_DATA:-}" ]]; then
  if [[ "${HERMES_CONTAINER}" == "agl-hermes-jarvis" ]]; then
    HERMES_DATA="${HERMES_ROOT}/data"
  else
    _agent="${HERMES_CONTAINER#agl-hermes-}"
    HERMES_DATA="${HERMES_ROOT}/profiles/${_agent}"
  fi
fi
HERMES_DATA="${HERMES_DATA:-${HERMES_ROOT}/data}"
ENV_FILE="${HERMES_DATA}/.env"
CFG="${HERMES_DATA}/config.yaml"
TOKENS_DIR="${HERMES_DATA}/mcp-tokens"
OAUTH_PORT="${COMPOSIO_OAUTH_PORT:-18432}"
ENV_KEY="${COMPOSIO_ENV_KEY:-COMPOSIO_API_KEY}"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'

info()  { printf '%b%s%b\n' "${YLW}" "$*" "${NC}"; }
ok()    { printf '%b%s%b\n' "${GRN}" "$*" "${NC}"; }
fail()  { printf '%b%s%b\n' "${RED}" "$*" "${NC}" >&2; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "Correr como root no CT188 (ou sudo)."
    exit 1
  fi
}

require_container() {
  docker ps --format '{{.Names}}' | grep -qx "${HERMES_CONTAINER}" || {
    fail "Contentor ${HERMES_CONTAINER} não está a correr."
    exit 1
  }
}

read_api_key() {
  if [[ -n "${COMPOSIO_API_KEY:-}" ]]; then
    return 0
  fi
  if [[ -f "${ENV_FILE}" ]]; then
    local line
    line="$(grep -E "^${ENV_KEY}=" "${ENV_FILE}" 2>/dev/null | tail -1 || true)"
    if [[ -n "${line}" ]]; then
      COMPOSIO_API_KEY="${line#*=}"
      return 0
    fi
  fi
  return 1
}

save_api_key() {
  local key="${1:?}"
  touch "${ENV_FILE}"
  if grep -qE "^${ENV_KEY}=" "${ENV_FILE}" 2>/dev/null; then
    sed -i "s|^${ENV_KEY}=.*|${ENV_KEY}=${key}|" "${ENV_FILE}"
  else
    printf '\n# Composio Connect MCP (dashboard.composio.dev)\n%s=%s\n' "${ENV_KEY}" "${key}" >> "${ENV_FILE}"
  fi
  chown 10000:10000 "${ENV_FILE}" 2>/dev/null || true
  chmod 600 "${ENV_FILE}"
}

patch_config() {
  local enabled="${1:-true}"
  local api_key="${2:-}"
  python3 - "${CFG}" "${ENV_KEY}" "${OAUTH_PORT}" "${enabled}" "${api_key}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
env_key = sys.argv[2]
oauth_port = int(sys.argv[3])
enabled = sys.argv[4].lower() in ("1", "true", "yes")
api_key = sys.argv[5] if len(sys.argv) > 5 else ""

cfg = yaml.safe_load(path.read_text()) or {}
mcp = cfg.get("mcp_servers")
if isinstance(mcp, list):
    fixed = {}
    for entry in mcp:
        if isinstance(entry, dict) and "name" in entry:
            e = dict(entry)
            name = e.pop("name")
            fixed[name] = e
    mcp = fixed
if not isinstance(mcp, dict):
    mcp = {}

# ak_ = project API key → x-api-key; ck_ = consumer → x-consumer-api-key
header_name = "x-api-key"
if api_key.startswith("ck_"):
    header_name = "x-consumer-api-key"

comp = mcp.setdefault("composio", {})
comp["url"] = "https://connect.composio.dev/mcp"
comp["auth"] = "oauth"
comp["enabled"] = enabled
comp["connect_timeout"] = comp.get("connect_timeout", 60)
comp["timeout"] = comp.get("timeout", 180)
comp["headers"] = {
    header_name: f"${{{env_key}}}",
}
comp["oauth"] = {
    "redirect_port": oauth_port,
    "client_name": "Hermes Agent AGLz CT188",
    "timeout": 600,
}
comp["connect_timeout"] = 600
comp["timeout"] = 600

cfg["mcp_servers"] = mcp
path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print(f"OK config.yaml composio enabled={enabled} header={header_name} redirect_port={oauth_port}")
PY
  chown 10000:10000 "${CFG}" 2>/dev/null || true
}

fix_token_perms() {
  install -d -m 700 -o 10000 -g 10000 "${TOKENS_DIR}"
  if [[ -d "${TOKENS_DIR}" ]]; then
    chown -R 10000:10000 "${TOKENS_DIR}"
    chmod 700 "${TOKENS_DIR}"
    find "${TOKENS_DIR}" -type f -exec chmod 600 {} \;
  fi
}

cmd_configure() {
  local disable_until_login=false
  for arg in "$@"; do
    [[ "${arg}" == "--disable-until-login" ]] && disable_until_login=true
  done

  require_root
  require_container
  test -f "${CFG}" || { fail "Falta ${CFG}"; exit 1; }

  if ! read_api_key; then
    fail "Definir COMPOSIO_API_KEY (export ou ${ENV_KEY} em ${ENV_FILE})."
    fail "Obter em: https://dashboard.composio.dev"
    exit 1
  fi

  save_api_key "${COMPOSIO_API_KEY}"
  local en="true"
  ${disable_until_login} && en="false"
  patch_config "${en}" "${COMPOSIO_API_KEY}"
  fix_token_perms

  ok "Composio configurado. API key em ${ENV_KEY} (não commitar)."
  if ${disable_until_login}; then
    info "composio.enabled=false — correr: $0 login && $0 enable"
  else
    info "Próximo passo: $0 login  (TTY interactivo)"
  fi
}

cmd_login() {
  require_root
  require_container

  if ! read_api_key; then
    fail "Correr primeiro: $0 configure (falta ${ENV_KEY})"
    exit 1
  fi

  if [[ ! -t 0 ]]; then
    fail "login requer TTY. Exemplo:"
    info "  docker exec -it -e HERMES_HOME=/opt/data ${HERMES_CONTAINER} hermes mcp login composio"
    exit 1
  fi

  info "A iniciar OAuth MCP (porta ${OAUTH_PORT} no contentor)..."
  info "Após autorizar no browser, colar a URL de redirect se o callback falhar."
  docker exec -it -e HERMES_HOME=/opt/data "${HERMES_CONTAINER}" \
    hermes mcp login composio
}

cmd_test() {
  require_root
  require_container
  docker exec -e HERMES_HOME=/opt/data "${HERMES_CONTAINER}" hermes mcp test composio
}

cmd_enable() {
  require_root
  read_api_key || true
  patch_config "true" "${COMPOSIO_API_KEY:-}"
  docker restart "${HERMES_CONTAINER}" >/dev/null
  sleep 15
  ok "Jarvis reiniciado com composio.enabled=true"
}

cmd_disable() {
  require_root
  read_api_key || true
  patch_config "false" "${COMPOSIO_API_KEY:-}"
  docker restart "${HERMES_CONTAINER}" >/dev/null
  sleep 10
  ok "Composio desactivado no gateway (sem spam OAuth)"
}

cmd_status() {
  require_root
  echo "=== config composio ==="
  python3 - "${CFG}" <<'PY' 2>/dev/null || true
import sys, yaml
from pathlib import Path
p = Path(sys.argv[1])
cfg = yaml.safe_load(p.read_text()) or {}
c = (cfg.get("mcp_servers") or {}).get("composio") or {}
print(yaml.safe_dump(c, sort_keys=False))
PY

  echo "=== tokens ==="
  ls -la "${TOKENS_DIR}/" 2>/dev/null || echo "(sem pasta)"
  if [[ -f "${TOKENS_DIR}/composio.json" ]]; then
    ok "composio.json presente (OAuth concluído)"
  else
    info "composio.json ausente — OAuth ainda não concluído"
  fi
  if [[ -f "${TOKENS_DIR}/composio.client.json" ]]; then
    info "composio.client.json (registo OAuth client dinâmico)"
  fi

  echo "=== env ==="
  if read_api_key; then
    ok "${ENV_KEY} definida"
  else
    fail "${ENV_KEY} em falta"
  fi

  echo "=== mcp list (contentor) ==="
  docker exec -e HERMES_HOME=/opt/data "${HERMES_CONTAINER}" hermes mcp list 2>/dev/null | head -20 || true
}

cmd_oauth_begin() {
  require_root
  require_container
  fix_token_perms

  local oauth_tmp="${HERMES_DATA}/.composio-oauth"
  local url_file="${oauth_tmp}/url"
  local cb_file="${oauth_tmp}/callback"
  local log_file="${oauth_tmp}/log"
  local pid_file="${oauth_tmp}/pid"

  install -d -m 700 -o 10000 -g 10000 "${oauth_tmp}"
  rm -f "${cb_file}"
  : > "${log_file}"

  # Libertar porta OAuth presa por tentativas anteriores (gateway ou probes zombie).
  docker exec "${HERMES_CONTAINER}" sh -c \
    "for p in \$(ss -tlnp 2>/dev/null | grep ':${OAUTH_PORT}' | grep -oP 'pid=\\K[0-9]+' | sort -u); do kill -9 \"\$p\" 2>/dev/null || true; done" || true
  sleep 1

  if [[ -f "${pid_file}" ]] && docker exec "${HERMES_CONTAINER}" kill -0 "$(tr -d '[:space:]' < "${pid_file}")" 2>/dev/null; then
    fail "Sessão OAuth já activa (PID $(cat "${pid_file}")). Usar: $0 oauth-finish '<url>'"
    [[ -f "${url_file}" ]] && cat "${url_file}"
    exit 1
  fi

  # Reason: hermes mcp test expira ~40s; probe directo com connect_timeout=600 + PTY para paste.
  docker exec -i -e HERMES_HOME=/opt/data "${HERMES_CONTAINER}" python3 - \
    "/opt/data/.composio-oauth/url" \
    "/opt/data/.composio-oauth/callback" \
    "/opt/data/.composio-oauth/log" \
    "/opt/data/.composio-oauth/pid" <<'PY' &
import os, pty, re, select, sys, time

url_file, cb_file, log_file, pid_file = sys.argv[1:5]
os.environ.setdefault("HERMES_HOME", "/opt/data")

log = open(log_file, "a", encoding="utf-8")

def log_write(s: str) -> None:
    log.write(s)
    log.flush()

def child_probe() -> None:
    from hermes_cli.mcp_config import _get_mcp_servers, _probe_single_server

    cfg = _get_mcp_servers()["composio"]
    oauth = dict(cfg.get("oauth") or {})
    oauth["timeout"] = 600
    cfg = dict(cfg)
    cfg["oauth"] = oauth
    _probe_single_server("composio", cfg, connect_timeout=600)

pid, fd = pty.fork()
if pid == 0:
    try:
        child_probe()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"PROBE_ERROR: {exc}", flush=True)
        sys.exit(1)
    sys.exit(0)

with open(pid_file, "w", encoding="utf-8") as f:
    f.write(str(pid))

buf = ""
auth_url = None
deadline = time.time() + 45
while time.time() < deadline and auth_url is None:
    r, _, _ = select.select([fd], [], [], 0.3)
    if not r:
        continue
    try:
        chunk = os.read(fd, 4096).decode(errors="replace")
    except OSError:
        break
    buf += chunk
    log_write(chunk)
    m = re.search(r"https://login\.composio\.dev/oauth2/authorize\?[^\s\r\n]+", buf)
    if m:
        auth_url = m.group(0)

if auth_url:
    with open(url_file, "w", encoding="utf-8") as f:
        f.write(auth_url + "\n")
    log_write("\n[oauth-begin] URL guardada em " + url_file + "\n")
else:
    log_write("\n[oauth-begin] ERRO: URL não encontrada\n")
    os.close(fd)
    os.waitpid(pid, 0)
    sys.exit(1)

deadline = time.time() + 900
callback = None
while time.time() < deadline and callback is None:
    if os.path.exists(cb_file):
        callback = open(cb_file, encoding="utf-8").read().strip()
        break
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try:
            chunk = os.read(fd, 4096).decode(errors="replace")
            log_write(chunk)
        except OSError:
            pass

if not callback:
    log_write("\n[oauth-begin] TIMEOUT à espera de callback\n")
    os.close(fd)
    os.kill(pid, 9)
    os.waitpid(pid, 0)
    sys.exit(1)

os.write(fd, (callback + "\n").encode())
log_write("\n[oauth-begin] Callback injectado\n")

deadline = time.time() + 180
while time.time() < deadline:
    r, _, _ = select.select([fd], [], [], 0.5)
    if r:
        try:
            chunk = os.read(fd, 4096).decode(errors="replace")
            log_write(chunk)
        except OSError:
            break
    if os.path.exists("/opt/data/mcp-tokens/composio.json"):
        break
    if os.waitpid(pid, os.WNOHANG)[0] != 0:
        break

os.waitpid(pid, 0)
log.close()
try:
    os.remove(pid_file)
except OSError:
    pass
PY
  local i=0
  while [[ $i -lt 30 && ! -f "${url_file}" ]]; do
    sleep 1
    i=$((i + 1))
  done

  if [[ ! -f "${url_file}" ]]; then
    fail "URL OAuth não apareceu a tempo — ver ${log_file}"
    exit 1
  fi

  ok "Sessão OAuth activa (aguarda callback até 10 min)"
  info "1) Abrir no browser:"
  cat "${url_file}"
  info "2) Após autorizar, enviar URL de redirect:"
  info "   $0 oauth-finish 'http://127.0.0.1:${OAUTH_PORT}/callback?code=...&state=...'"
}

cmd_oauth_finish() {
  require_root
  local callback="${1:-}"
  local oauth_tmp="${HERMES_DATA}/.composio-oauth"
  local cb_file="${oauth_tmp}/callback"
  local log_file="${oauth_tmp}/log"
  local pid_file="${oauth_tmp}/pid"

  if [[ -z "${callback}" ]]; then
    fail "Uso: $0 oauth-finish '<url_callback_completa>'"
    exit 1
  fi

  if [[ ! -f "${pid_file}" ]] || ! docker exec "${HERMES_CONTAINER}" kill -0 "$(tr -d '[:space:]' < "${pid_file}")" 2>/dev/null; then
    fail "Sem sessão oauth-begin activa. Correr primeiro: $0 oauth-begin"
    exit 1
  fi

  printf '%s\n' "${callback}" > "${cb_file}"
  ok "Callback recebido — a completar OAuth (ver ${log_file})"

  local i=0
  while [[ $i -lt 200 ]]; do
    if [[ -f /opt/agl-hermes/data/mcp-tokens/composio.json ]]; then
      chown 10000:10000 /opt/agl-hermes/data/mcp-tokens/composio.json
      chmod 600 /opt/agl-hermes/data/mcp-tokens/composio.json
      ok "composio.json criado — OAuth concluído"
      cmd_test
      cmd_enable
      return 0
    fi
    if ! docker exec "${HERMES_CONTAINER}" kill -0 "$(tr -d '[:space:]' < "${pid_file}")" 2>/dev/null; then
      break
    fi
    sleep 1
    i=$((i + 1))
  done

  fail "OAuth não concluído. Últimas linhas do log:"
  tail -30 "${log_file}" 2>/dev/null || true
  exit 1
}

cmd_tunnel_help() {
  cat <<EOF
Túnel para callback OAuth (opcional — colar URL é mais simples):

  # No CT188, enquanto login corre no contentor:
  docker run --rm -it --network container:${HERMES_CONTAINER} \\
    alpine/socat TCP-LISTEN:${OAUTH_PORT},bind=0.0.0.0,reuseaddr,fork TCP:127.0.0.1:${OAUTH_PORT}

  # No PC (outro terminal):
  ssh -N -L ${OAUTH_PORT}:127.0.0.1:${OAUTH_PORT} root@192.168.0.188

  Depois abrir a URL de authorize e deixar o browser redireccionar.
EOF
}

usage() {
  cat <<EOF
Uso: $0 <comando>

Comandos:
  configure [--disable-until-login]   API key + config.yaml (headers + oauth)
  login                             OAuth interactivo (docker exec -it)
  oauth-begin                       inicia sessão headless + imprime URL authorize
  oauth-finish '<callback_url>'     cola redirect na sessão activa (mesmo state/code)
  test                              hermes mcp test composio
  enable / disable                  activar/desactivar no gateway
  status                            estado config + tokens
  tunnel-help                       notas de port-forward

Variáveis: COMPOSIO_API_KEY, COMPOSIO_ENV_KEY, COMPOSIO_OAUTH_PORT, HERMES_CONTAINER
EOF
}

main() {
  local cmd="${1:-status}"
  shift || true
  case "${cmd}" in
    configure) cmd_configure "$@" ;;
    login)     cmd_login ;;
    oauth-begin) cmd_oauth_begin ;;
    oauth-finish) cmd_oauth_finish "${1:-}" ;;
    test)      cmd_test ;;
    enable)    cmd_enable ;;
    disable)   cmd_disable ;;
    status)    cmd_status ;;
    tunnel-help) cmd_tunnel_help ;;
    -h|--help) usage ;;
    *) fail "Comando desconhecido: ${cmd}"; usage; exit 1 ;;
  esac
}

main "$@"

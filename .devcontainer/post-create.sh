#!/usr/bin/env bash
# Pós-criação do devcontainer agl-hostman (idempotente; seguro em rebuild).
set -euo pipefail

WORKSPACE="${WORKSPACE_FOLDER:-${containerWorkspaceFolder:-$(pwd)}}"
TURBO_FLOW_REPO="${TURBO_FLOW_REPO:-https://github.com/marcuspat/turbo-flow}"
TURBO_FLOW_BRANCH="${TURBO_FLOW_BRANCH:-main}"

log() { echo "[devcontainer] $*"; }

install_os_packages() {
  if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update -qq
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y -qq \
    tmux htop jq unzip \
    >/dev/null
  fi
}

install_turbo_flow_devpods() {
  if [[ -f "${WORKSPACE}/devpods/setup.sh" ]]; then
    log "devpods/ já presente — a saltar clone turbo-flow"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' RETURN

  log "A obter devpods/ de ${TURBO_FLOW_REPO} (${TURBO_FLOW_BRANCH})"
  git clone -b "${TURBO_FLOW_BRANCH}" --depth 1 "${TURBO_FLOW_REPO}" "${tmp}/tf-src"
  cp -r "${tmp}/tf-src/devpods" "${WORKSPACE}/"
  chmod +x "${WORKSPACE}"/devpods/*.sh 2>/dev/null || true

  if [[ -x "${WORKSPACE}/devpods/setup.sh" ]]; then
    log "A executar devpods/setup.sh"
    (cd "${WORKSPACE}" && ./devpods/setup.sh)
  fi
}

configure_openclaw_zshrc() {
  local hook='[[ -f "$WORKSPACE_FOLDER/config/openclaw/zshrc-openclaw.env" ]] && source "$WORKSPACE_FOLDER/config/openclaw/zshrc-openclaw.env" && cclitellm'
  local zshrc_openclaw="${WORKSPACE}/config/openclaw/zshrc-openclaw.env"

  if [[ ! -f "${zshrc_openclaw}" ]]; then
    return 0
  fi

  for f in /home/vscode/.zshrc /root/.zshrc; do
    touch "${f}" 2>/dev/null || continue
    if ! grep -q 'zshrc-openclaw.env' "${f}" 2>/dev/null; then
      {
        echo ''
        echo '# Claude-Flow + LiteLLM (agl-hostman devcontainer)'
        echo "${hook}"
      } >>"${f}"
      log "Hook OpenClaw/LiteLLM adicionado a ${f}"
      break
    fi
  done
}

apply_litellm_defaults() {
  # Só define defaults se o utilizador não passou localEnv / devcontainer.env
  if [[ -z "${LITELLM_GATEWAY_URL:-}" ]]; then
    export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL_DEFAULT:-http://host.docker.internal:4000}"
    log "LITELLM_GATEWAY_URL=${LITELLM_GATEWAY_URL} (override: .devcontainer/devcontainer.env ou localEnv)"
  fi
  export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-${LITELLM_GATEWAY_URL}}"

  for f in /home/vscode/.zshrc /home/vscode/.bashrc; do
    touch "${f}" 2>/dev/null || continue
    if ! grep -q 'LITELLM_GATEWAY_URL' "${f}" 2>/dev/null; then
      {
        echo ''
        echo '# LiteLLM (override com devcontainer.env ou export antes do devpod up)'
        echo "export LITELLM_GATEWAY_URL=\"${LITELLM_GATEWAY_URL}\""
        echo "export ANTHROPIC_BASE_URL=\"${ANTHROPIC_BASE_URL}\""
      } >>"${f}"
      break
    fi
  done
}

install_js_deps() {
  if [[ -f "${WORKSPACE}/package.json" ]] && [[ ! -d "${WORKSPACE}/node_modules" ]]; then
    log "npm install (raiz)"
    (cd "${WORKSPACE}" && npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund)
  fi
  if [[ -f "${WORKSPACE}/src/package.json" ]] && [[ ! -d "${WORKSPACE}/src/node_modules" ]]; then
    log "npm install (src/)"
    (cd "${WORKSPACE}/src" && npm ci --no-audit --no-fund 2>/dev/null || npm install --no-audit --no-fund)
  fi
}

install_php_deps() {
  if [[ -f "${WORKSPACE}/src/composer.json" ]] && [[ ! -d "${WORKSPACE}/src/vendor" ]]; then
    log "composer install (src/)"
  (cd "${WORKSPACE}/src" && composer install --no-interaction --prefer-dist)
  fi
}

main() {
  log "post-create — workspace=${WORKSPACE}"
  install_os_packages
  install_turbo_flow_devpods
  configure_openclaw_zshrc
  apply_litellm_defaults
  install_js_deps
  install_php_deps
  log "post-create concluído"
}

main "$@"

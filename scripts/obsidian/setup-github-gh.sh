#!/usr/bin/env bash
# GitHub CLI (gh) para pull/push do llm-wiki no CT193 — substitui deploy key SSH.
set -euo pipefail

LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
GITHUB_REPO="${GITHUB_REPO:-AGLz/llm-wiki}"
INSTALL_ONLY="${INSTALL_ONLY:-0}"

log() { echo "[gh-setup] $*"; }

install_gh_wrapper() {
  local wrapper_src="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}/scripts/obsidian/gh-agl-wrapper.sh"
  if [[ ! -f "${wrapper_src}" ]]; then
    log "wrapper gh-agl não encontrado (${wrapper_src}) — skip"
    return 0
  fi
  install -m 0755 "${wrapper_src}" /usr/local/bin/gh
  log "wrapper gh → /usr/local/bin/gh (jump se api.github.com falhar)"
}

install_gh() {
  if command -v gh >/dev/null 2>&1; then
    log "gh já instalado: $(gh --version | head -1)"
    return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y curl ca-certificates gnupg
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list
  apt-get update
  apt-get install -y gh
  log "gh instalado: $(gh --version | head -1)"
}

has_gh_hosts_config() {
  [[ -f /root/.config/gh/hosts.yml ]] && grep -q 'oauth_token:' /root/.config/gh/hosts.yml 2>/dev/null
}

ensure_auth() {
  if gh auth status -h github.com &>/dev/null 2>&1; then
    log "gh autenticado ($(gh api user -q .login 2>/dev/null || echo unknown))"
    return 0
  fi
  if has_gh_hosts_config; then
    log "hosts.yml presente — usar credenciais locais (API GitHub pode estar bloqueada no CT)"
    return 0
  fi
  if [[ -n "${GH_TOKEN:-}" ]]; then
    printf '%s\n' "${GH_TOKEN}" | gh auth login --with-token
    log "gh autenticado via GH_TOKEN"
    return 0
  fi
  if [[ -f /root/.config/gh-token ]]; then
    gh auth login --with-token < /root/.config/gh-token
    log "gh autenticado via /root/.config/gh-token"
    return 0
  fi
  echo "ERRO: gh não autenticado." >&2
  echo "  Opção A (CT193): gh auth login -h github.com -p https -w" >&2
  echo "  Opção B (agldv03): bash scripts/obsidian/propagate-gh-auth-to-ct193.sh" >&2
  echo "  Opção C: GH_TOKEN=... bash $0" >&2
  echo "  Opção D (LAN AGL): auth no jump GCE — bash scripts/obsidian/propagate-gh-auth-to-jump.sh" >&2
  return 1
}

configure_git() {
  git config --global --add safe.directory "${LLM_WIKI_DIR}" 2>/dev/null || true
  gh auth setup-git -h github.com
  if [[ -d "${LLM_WIKI_DIR}/.git" ]]; then
    cd "${LLM_WIKI_DIR}"
    git remote set-url origin "https://github.com/${GITHUB_REPO}.git"
    log "remote origin → https://github.com/${GITHUB_REPO}.git"
  fi
}

verify_repo() {
  if [[ "${VERIFY_GH_REPO:-1}" == "0" ]]; then
    log "skip verify repo (VERIFY_GH_REPO=0)"
    return 0
  fi
  if gh repo view "${GITHUB_REPO}" --json name,visibility -q '"\(.name) (\(.visibility))"' 2>/dev/null; then
    log "acesso OK a ${GITHUB_REPO}"
    return 0
  fi
  log "AVISO: não foi possível verificar ${GITHUB_REPO} via API — testar git pull manualmente"
}

main() {
  local install_only=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --install-only) install_only=1; shift ;;
      -h|--help)
        sed -n '2,4p' "$0"
        echo "Uso: $0 [--install-only]"
        exit 0
        ;;
      *) echo "opção desconhecida: $1" >&2; exit 1 ;;
    esac
  done

  install_gh
  install_gh_wrapper
  if [[ "${install_only}" -eq 1 || "${INSTALL_ONLY}" == "1" ]]; then
    log "só instalação — auth manual depois"
    exit 0
  fi
  ensure_auth
  configure_git
  verify_repo
  log "OK — git pull/push usa credenciais gh"
}

main "$@"

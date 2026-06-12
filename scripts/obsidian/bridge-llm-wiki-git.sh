#!/usr/bin/env bash
# Ponte Git ↔ llm-wiki no CT193 (pull agentes, push edições humanas via inotify).
set -euo pipefail

LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
LOCK_FILE="${BRIDGE_LOCK_FILE:-/var/run/agl-llm-wiki-bridge.lock}"
DEBOUNCE_SEC="${BRIDGE_DEBOUNCE_SEC:-30}"
GIT_BRANCH="${BRIDGE_GIT_BRANCH:-main}"
COMMIT_AUTHOR_NAME="${BRIDGE_COMMIT_AUTHOR_NAME:-agl-obsidian}"
COMMIT_AUTHOR_EMAIL="${BRIDGE_COMMIT_AUTHOR_EMAIL:-agl-obsidian@agl.local}"

log() { echo "[bridge] $(date -Iseconds) $*"; }

acquire_lock() {
  exec 9>"${LOCK_FILE}"
  if ! flock -n 9; then
    log "lock ocupado — ignorar ciclo"
    return 1
  fi
  return 0
}

release_lock() {
  flock -u 9 2>/dev/null || true
}

ensure_github_auth() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERRO: gh não instalado — correr scripts/obsidian/setup-github-gh.sh" >&2
    exit 1
  fi
  if gh auth status -h github.com &>/dev/null 2>&1; then
    return 0
  fi
  if [[ -f /root/.config/gh/hosts.yml ]] && grep -q 'oauth_token:' /root/.config/gh/hosts.yml 2>/dev/null; then
    return 0
  fi
  echo "ERRO: gh não autenticado — gh auth login ou propagate-gh-auth-to-ct193.sh" >&2
  exit 1
}

ensure_repo() {
  git config --global --add safe.directory "${LLM_WIKI_DIR}" 2>/dev/null || true
  if [[ ! -d "${LLM_WIKI_DIR}/.git" ]]; then
    echo "ERRO: ${LLM_WIKI_DIR} não é repositório git" >&2
    exit 1
  fi
  if [[ ! -f "${LLM_WIKI_DIR}/wiki/index.md" ]]; then
    echo "ERRO: wiki/index.md inacessível em ${LLM_WIKI_DIR}" >&2
    exit 1
  fi
}

append_log_entry() {
  local msg="$1"
  local log_file="${LLM_WIKI_DIR}/wiki/log.md"
  [[ -f "${log_file}" ]] || return 0
  {
    echo ""
    echo "## [$(date +%Y-%m-%d)] maintenance | bridge"
    echo "- ${msg}"
  } >> "${log_file}"
}

cmd_pull() {
  ensure_github_auth
  ensure_repo
  acquire_lock || exit 0
  cd "${LLM_WIKI_DIR}"
  git config user.name "${COMMIT_AUTHOR_NAME}"
  git config user.email "${COMMIT_AUTHOR_EMAIL}"

  if ! git diff --quiet || ! git diff --cached --quiet; then
    log "working tree suja — skip pull (resolver manualmente)"
    release_lock
    exit 0
  fi

  if git pull --rebase origin "${GIT_BRANCH}"; then
    log "pull OK (${GIT_BRANCH})"
  else
    log "pull falhou — abort rebase"
    git rebase --abort 2>/dev/null || true
    append_log_entry "bridge pull falhou — conflito manual necessário"
    release_lock
    exit 1
  fi
  release_lock
}

cmd_push() {
  ensure_github_auth
  ensure_repo
  acquire_lock || exit 0
  cd "${LLM_WIKI_DIR}"
  git config user.name "${COMMIT_AUTHOR_NAME}"
  git config user.email "${COMMIT_AUTHOR_EMAIL}"

  git add wiki/ raw/ AGENTS.md 2>/dev/null || true
  if git diff --cached --quiet; then
    log "nada para commit"
    release_lock
    exit 0
  fi

  git commit -m "docs(wiki): sync from obsidian hub"
  if git push origin "${GIT_BRANCH}"; then
    log "push OK"
  else
    log "push falhou"
    append_log_entry "bridge push falhou — verificar gh auth / rede"
    release_lock
    exit 1
  fi
  release_lock
}

cmd_watch() {
  ensure_repo
  command -v inotifywait >/dev/null || { echo "ERRO: instalar inotify-tools" >&2; exit 1; }

  log "watch em wiki/ e raw/ (debounce ${DEBOUNCE_SEC}s)"
  while true; do
    inotifywait -r -e modify,create,delete,move \
      "${LLM_WIKI_DIR}/wiki" "${LLM_WIKI_DIR}/raw" 2>/dev/null || sleep 5
    sleep "${DEBOUNCE_SEC}"
    cmd_push || true
  done
}

usage() {
  sed -n '2,8p' "$0"
  echo "Uso: $0 pull|push|watch"
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    pull) cmd_pull ;;
    push) cmd_push ;;
    watch) cmd_watch ;;
    -h|--help|"") usage ;;
    *) echo "comando desconhecido: ${cmd}" >&2; usage; exit 1 ;;
  esac
}

main "$@"

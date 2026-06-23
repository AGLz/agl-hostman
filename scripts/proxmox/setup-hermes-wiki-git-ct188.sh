#!/usr/bin/env bash
# Git push llm-wiki a partir dos contentores Hermes (Curator e restantes agentes).
#
# Problema: git recusa "dubious ownership" (NFS nobody) e hermes não tem gh/credentials.
# Solução: safe.directory + user + credential store no perfil (/opt/data no contentor).
#
# Pré-requisito CT188: gh autenticado como root (gh auth login) com scope repo.
#
# Uso (root no CT188):
#   bash setup-hermes-wiki-git-ct188.sh
#   bash setup-hermes-wiki-git-ct188.sh --push   # após setup, git push origin main
#   bash setup-hermes-wiki-git-ct188.sh --test    # só valida git no contentor curator

set -euo pipefail

HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
HERMES_UID="${HERMES_UID:-10000}"
HERMES_GID="${HERMES_GID:-10000}"
WIKI_HOST="${WIKI_HOST:-/opt/agl-llm-wiki}"
WIKI_NFS="${WIKI_NFS:-/mnt/overpower/apps/dev/agl/llm-wiki}"
WIKI_CONTAINER="${WIKI_CONTAINER:-/opt/llm-wiki}"
GITHUB_LOGIN="${GITHUB_LOGIN:-}"
DO_PUSH=0
DO_TEST=0

AGENTS=(jarvis elon satya werner curator orion)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --push) DO_PUSH=1; shift ;;
    --test) DO_TEST=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0"
      exit 0
      ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

profile_dir() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data"
  else
    echo "${HERMES_ROOT}/profiles/${agent}"
  fi
}

require_gh() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "ERRO: gh não instalado no CT188" >&2
    exit 1
  fi
  if ! gh auth token >/dev/null 2>&1; then
    echo "ERRO: gh sem token — correr: gh auth login -h github.com" >&2
    exit 1
  fi
}

write_profile_git() {
  local agent="$1"
  local pdir token login
  pdir="$(profile_dir "${agent}")"
  [[ -d "${pdir}" ]] || return 0

  token="$(gh auth token)"
  login="${GITHUB_LOGIN:-$(gh api user -q .login 2>/dev/null || echo "agl-bot")}"

  cat >"${pdir}/.gitconfig" <<EOF
[safe]
	directory = ${WIKI_CONTAINER}
	directory = ${WIKI_HOST}
[user]
	name = Hermes ${agent^}
	email = ${agent}@agl.local
[credential]
	helper = store
EOF

  printf 'https://%s:%s@github.com\n' "${login}" "${token}" >"${pdir}/.git-credentials"

  chown "${HERMES_UID}:${HERMES_GID}" "${pdir}/.gitconfig" "${pdir}/.git-credentials"
  chmod 600 "${pdir}/.gitconfig" "${pdir}/.git-credentials"
  echo "OK git profile: ${agent} (${pdir})"
}

configure_host_safe_dirs() {
  for dir in "${WIKI_NFS}" "${WIKI_HOST}"; do
    if [[ -d "${dir}/.git" ]]; then
      git config --global --add safe.directory "${dir}" 2>/dev/null || true
    fi
  done
  echo "OK safe.directory (root) → ${WIKI_NFS}"
}

test_curator_git() {
  local container="${TEST_CONTAINER:-agl-hermes-curator}"
  docker exec -u hermes -e HOME=/opt/data "${container}" \
    git -C "${WIKI_CONTAINER}" status -sb
  docker exec -u hermes -e HOME=/opt/data "${container}" \
    git -C "${WIKI_CONTAINER}" config user.email
  echo "OK git test inside ${container}"
}

push_wiki() {
  local branch
  branch="$(git -C "${WIKI_NFS}" branch --show-current 2>/dev/null || echo main)"
  echo "=== push ${WIKI_NFS} origin ${branch} (host gh) ==="
  git -C "${WIKI_NFS}" push origin "${branch}"
  echo "=== push via curator container (hermes user) ==="
  docker exec -u hermes -e HOME=/opt/data agl-hermes-curator \
    git -C "${WIKI_CONTAINER}" push origin "${branch}"
}

main() {
  require_gh
  [[ -d "${WIKI_NFS}/.git" ]] || { echo "ERRO: ${WIKI_NFS} não é repo git" >&2; exit 1; }

  configure_host_safe_dirs
  gh auth setup-git -h github.com 2>/dev/null || true

  for agent in "${AGENTS[@]}"; do
    write_profile_git "${agent}"
  done

  if [[ "${DO_TEST}" -eq 1 ]] || [[ "${DO_PUSH}" -eq 0 ]]; then
    test_curator_git
  fi

  if [[ "${DO_PUSH}" -eq 1 ]]; then
    push_wiki
  fi

  echo "OK hermes wiki git — perfis configurados; push: ${DO_PUSH}"
}

main "$@"

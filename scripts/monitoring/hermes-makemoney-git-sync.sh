#!/usr/bin/env bash
# Commit + push automático makemoney01 → GitHub AGLz (após pipeline matinal).
set -euo pipefail

MAKEMONEY_DIR="${MAKEMONEY_DIR:-/mnt/overpower/apps/dev/agl/makemoney01}"
GITHUB_ORG="${GITHUB_ORG:-AGLz}"
GITHUB_REPO="${GITHUB_REPO:-makemoney01}"
GITHUB_BRANCH="${GITHUB_BRANCH:-main}"
HERMES_ENV="${HERMES_ENV:-/opt/data/.env}"
DATE="$(date '+%Y-%m-%d')"
GIT_USER_NAME="${MAKEMONEY_GIT_USER_NAME:-AGL Hermes}"
GIT_USER_EMAIL="${MAKEMONEY_GIT_USER_EMAIL:-hermes@agl.local}"

load_token() {
  local token=""
  token="${GITHUB_TOKEN:-${GH_TOKEN:-}}"
  if [[ -z "${token}" && -f "${HERMES_ENV}" ]]; then
    token="$(grep -E '^(GITHUB_TOKEN|GH_TOKEN)=' "${HERMES_ENV}" 2>/dev/null | tail -1 | cut -d= -f2- | tr -d '"' || true)"
  fi
  if [[ -z "${token}" ]] && command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
    token="$(gh auth token 2>/dev/null || true)"
  fi
  echo "${token}"
}

ensure_git_safe() {
  git config --global --add safe.directory "${MAKEMONEY_DIR}" 2>/dev/null || true
}

main() {
  [[ -d "${MAKEMONEY_DIR}/.git" ]] || {
    echo "SKIP: repo git em falta em ${MAKEMONEY_DIR}"
    exit 0
  }

  ensure_git_safe
  cd "${MAKEMONEY_DIR}"
  git config user.name "${GIT_USER_NAME}"
  git config user.email "${GIT_USER_EMAIL}"

  # Evitar conflitos se alguém pushou manualmente
  token="$(load_token)"
  if [[ -n "${token}" ]]; then
    git remote set-url origin "https://x-access-token:${token}@github.com/${GITHUB_ORG}/${GITHUB_REPO}.git" 2>/dev/null || \
      git remote add origin "https://x-access-token:${token}@github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
    git fetch origin "${GITHUB_BRANCH}" 2>/dev/null || true
    git pull --rebase origin "${GITHUB_BRANCH}" 2>/dev/null || true
  fi

  git add data/ wiki-ingest/ README.md data/dossiers/ 2>/dev/null || true
  git add -u data/ wiki-ingest/ data/dossiers/ 2>/dev/null || true

  if git diff --cached --quiet; then
    echo "[SILENT] makemoney01: sem alterações para commit"
    exit 0
  fi

  git commit -m "$(cat <<EOF
chore(makemoney): sync pipeline ${DATE}

Automático via Hermes cron (oportunidades, pipeline, wiki-ingest).
EOF
)"

  if [[ -z "${token}" ]]; then
    echo "AVISO: commit local OK; push ignorado (GITHUB_TOKEN em falta)"
    exit 0
  fi

  git push origin "${GITHUB_BRANCH}"
  echo "OK git push ${GITHUB_ORG}/${GITHUB_REPO}@${GITHUB_BRANCH} (${DATE})"
}

main "$@"

#!/usr/bin/env bash
# Migração canónica makemoney01: backfill Hermes → mount, symlinks, cleanup, GitHub.
#
# Uso (root no CT188):
#   bash migrate-makemoney-canonical-ct188.sh
#   bash migrate-makemoney-canonical-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman --dry-run
#
set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
DRY_RUN="${2:-}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
DATA="${HERMES_ROOT}/data"
MAKEMONEY_NFS="${MAKEMONEY_NFS:-/mnt/overpower/apps/dev/agl/makemoney01}"
MAKEMONEY_HOST="${MAKEMONEY_HOST:-/opt/agl-makemoney01}"
CRON_OUTPUT="${DATA}/cron/output"
GITHUB_ORG="${GITHUB_ORG:-AGLz}"
GITHUB_REPO="${GITHUB_REPO:-makemoney01}"

MAKEMONEY_JOB_IDS=(
  708fe1021f93
  052baa2c84ec
  397353f649f0
  d3aa78d4d071
)

run() {
  if [[ "${DRY_RUN}" == "--dry-run" ]]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

echo "=== 1/6 ensure makemoney01 mount ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/ensure-makemoney01-ct188.sh" "${AGL_HOSTMAN}"

echo "=== 2/6 backfill Hermes cron/output → makemoney01 ==="
run docker exec -u hermes -e HERMES_HOME=/opt/data agl-hermes-jarvis \
  python3 "/mnt/overpower/apps/dev/agl/makemoney01/scripts/backfill_from_hermes.py" /opt/data/cron/output

echo "=== 3/6 rebuild pipeline from archive ==="
if [[ "${DRY_RUN}" != "--dry-run" ]]; then
  latest_research="$(find "${MAKEMONEY_NFS}/data/hermes-archive/708fe1021f93" -name '*.md' 2>/dev/null | sort | tail -1 || true)"
  if [[ -n "${latest_research}" && -f "${MAKEMONEY_NFS}/scripts/update_pipeline.py" ]]; then
    day="$(echo "$(basename "${latest_research}")" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1)"
    cp -f "${latest_research}" "${MAKEMONEY_NFS}/data/cron-sync/${day}-research.md" 2>/dev/null || true
    python3 "${MAKEMONEY_NFS}/scripts/update_pipeline.py" "${MAKEMONEY_NFS}/data/cron-sync/${day}-research.md" "${day}" || true
  fi
fi

echo "=== 4/6 symlinks: wiki-ingest + env Hermes ==="
WIKI_INGEST_HOST="${DATA}/wiki-ingest"
WIKI_INGEST_MM="${MAKEMONEY_NFS}/wiki-ingest"
mkdir -p "${WIKI_INGEST_MM}"

if [[ -e "${WIKI_INGEST_HOST}" && ! -L "${WIKI_INGEST_HOST}" ]]; then
  if [[ -d "${WIKI_INGEST_HOST}" ]]; then
    run shopt -s dotglob nullglob
    for f in "${WIKI_INGEST_HOST}"/*; do
      [[ -e "${f}" ]] || continue
      base="$(basename "${f}")"
      [[ -e "${WIKI_INGEST_MM}/${base}" ]] || run cp -a "${f}" "${WIKI_INGEST_MM}/"
    done
  fi
  run rm -rf "${WIKI_INGEST_HOST}"
fi
run ln -sfn "${WIKI_INGEST_MM}" "${WIKI_INGEST_HOST}"
echo "OK ${WIKI_INGEST_HOST} → ${WIKI_INGEST_MM}"

JARVIS_ENV="${DATA}/.env"
touch "${JARVIS_ENV}"
grep -q '^MAKEMONEY_DIR=' "${JARVIS_ENV}" 2>/dev/null || echo "MAKEMONEY_DIR=${MAKEMONEY_NFS}" >>"${JARVIS_ENV}"
if grep -q '^MAKEMONEY_DIR=' "${JARVIS_ENV}" 2>/dev/null; then
  sed -i "s|^MAKEMONEY_DIR=.*|MAKEMONEY_DIR=${MAKEMONEY_NFS}|" "${JARVIS_ENV}"
fi
grep -q '^CURATOR_WIKI_INGEST=' "${JARVIS_ENV}" 2>/dev/null || \
  echo "CURATOR_WIKI_INGEST=${WIKI_INGEST_MM}" >>"${JARVIS_ENV}"
sed -i "s|^CURATOR_WIKI_INGEST=.*|CURATOR_WIKI_INGEST=${WIKI_INGEST_MM}|" "${JARVIS_ENV}" 2>/dev/null || true
echo "OK .env MAKEMONEY_DIR + CURATOR_WIKI_INGEST"

echo "=== 5/6 remover outputs antigos Hermes (canónico = mount) ==="
for job_id in "${MAKEMONEY_JOB_IDS[@]}"; do
  job_dir="${CRON_OUTPUT}/${job_id}"
  if [[ -d "${job_dir}" ]]; then
    count="$(find "${job_dir}" -name '*.md' 2>/dev/null | wc -l)"
    run find "${job_dir}" -name '*.md' -delete 2>/dev/null || true
    run find "${job_dir}" -type d -empty -delete 2>/dev/null || true
    echo "OK limpo ${job_id}: ${count} ficheiros (arquivo em makemoney01/data/hermes-archive/)"
  fi
done

echo "=== 6/6 GitHub ${GITHUB_ORG}/${GITHUB_REPO} ==="
cd "${MAKEMONEY_NFS}"
if [[ ! -d .git ]]; then
  run git init -b main
  run git config user.email "hermes@agl.local"
  run git config user.name "AGL Hermes"
fi

if ! gh repo view "${GITHUB_ORG}/${GITHUB_REPO}" >/dev/null 2>&1; then
  echo "A criar repo privado ${GITHUB_ORG}/${GITHUB_REPO}..."
  if [[ "${DRY_RUN}" != "--dry-run" ]]; then
    gh repo create "${GITHUB_ORG}/${GITHUB_REPO}" \
      --private \
      --description "makemoney01 — pipeline oportunidades IA AGLz (Hermes → mount → wiki)" \
      --source . \
      --remote origin \
      --push 2>/dev/null || {
      gh repo create "${GITHUB_ORG}/${GITHUB_REPO}" --private \
        --description "makemoney01 — pipeline oportunidades IA AGLz"
      git remote add origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git" 2>/dev/null || \
        git remote set-url origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
    }
  fi
else
  git remote add origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git" 2>/dev/null || \
    git remote set-url origin "https://github.com/${GITHUB_ORG}/${GITHUB_REPO}.git"
fi

if [[ "${DRY_RUN}" != "--dry-run" ]]; then
  git add -A
  git status --short | head -20
  git commit -m "$(cat <<'EOF'
chore: migração canónica Hermes → makemoney01

Backfill histórico cron/output, pipeline, wiki-ingest no mount NFS.
Hermes aponta para /mnt/overpower/apps/dev/agl/makemoney01.
EOF
)" 2>/dev/null || echo "AVISO: nada novo para commit ou commit já existe"
  git push -u origin main 2>/dev/null || git push -u origin master 2>/dev/null || echo "AVISO: push manual se necessário"
fi

echo "=== Reinstalar scripts Hermes + crons ==="
if [[ "${DRY_RUN}" != "--dry-run" ]]; then
  bash "${AGL_HOSTMAN}/scripts/proxmox/setup-makemoney-git-ct188.sh" 2>/dev/null || \
    echo "AVISO: setup-makemoney-git — correr manualmente no CT188" >&2
  bash "${AGL_HOSTMAN}/scripts/proxmox/evolve-hermes-crons-ct188.sh" "${AGL_HOSTMAN}" || true
fi

echo ""
echo "Concluído. Canónico: ${MAKEMONEY_NFS}"
echo "  GitHub: https://github.com/${GITHUB_ORG}/${GITHUB_REPO}"
echo "  Arquivo: ${MAKEMONEY_NFS}/data/hermes-archive/"
echo "  wiki-ingest: symlink ${WIKI_INGEST_HOST}"

#!/usr/bin/env bash
# Configura GitHub Secrets para pipeline CT134 (Harbor + health).
# Uso:
#   bash scripts/github/setup-ct134-github-secrets.sh
#   HARBOR_CREDS_FILE=/root/robot-ct134-credentials.txt bash scripts/github/setup-ct134-github-secrets.sh
#
# Requer: gh auth login, ssh AGLSRV1 CT182 para CA/creds
set -euo pipefail

REPO="${GITHUB_REPO:-AGLz/agl-hostman}"
AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
HARBOR_CREDS_FILE="${HARBOR_CREDS_FILE:-}"
CT134_HEALTH_URL="${CT134_HEALTH_URL:-https://ah.aglz.io/health/}"

log() { printf '[setup-ct134-secrets] %s\n' "$*"; }

if ! command -v gh >/dev/null; then
  echo "Erro: gh CLI não instalado" >&2
  exit 1
fi

if [[ -z "${HARBOR_CREDS_FILE}" ]]; then
  tmp="$(mktemp)" || { echo "Erro: mktemp falhou" >&2; exit 1; }
  ssh -o BatchMode=yes "${AGLSRV1}" "pct exec 182 -- cat /root/robot-ct134-credentials.txt" > "${tmp}"
  HARBOR_CREDS_FILE="${tmp}"
  trap 'rm -f "${tmp}"' EXIT
fi

[[ -f "${HARBOR_CREDS_FILE}" ]] || {
  echo "Erro: credenciais Harbor não encontradas" >&2
  exit 1
}

HARBOR_USERNAME="$(sed -n '1p' "${HARBOR_CREDS_FILE}" | tr -d '\r\n')"
HARBOR_PASSWORD="$(sed -n '2p' "${HARBOR_CREDS_FILE}" | tr -d '\r\n')"
if [[ "${HARBOR_USERNAME}" == HARBOR_USERNAME=* ]]; then
  HARBOR_USERNAME="${HARBOR_USERNAME#HARBOR_USERNAME=}"
fi
if [[ "${HARBOR_PASSWORD}" == HARBOR_PASSWORD=* ]]; then
  HARBOR_PASSWORD="${HARBOR_PASSWORD#HARBOR_PASSWORD=}"
fi

HARBOR_CA_CERT="$(ssh -o BatchMode=yes "${AGLSRV1}" "pct exec 182 -- base64 -w0 /opt/harbor-certs/ca.crt")"

[[ -n "${HARBOR_USERNAME}" && -n "${HARBOR_PASSWORD}" ]] || {
  echo "Erro: não foi possível parsear credenciais robot Harbor" >&2
  exit 1
}

log "Repo: ${REPO}"
# ponytail: pipe evita re-expansão de $ no nome robot$project+name
sed -n '1p' "${HARBOR_CREDS_FILE}" | tr -d '\r\n' | gh secret set HARBOR_USERNAME --repo "${REPO}"
sed -n '2p' "${HARBOR_CREDS_FILE}" | tr -d '\r\n' | gh secret set HARBOR_PASSWORD --repo "${REPO}"
gh secret set HARBOR_CA_CERT --repo "${REPO}" --body "${HARBOR_CA_CERT}"
gh secret set CT134_HEALTH_URL --repo "${REPO}" --body "${CT134_HEALTH_URL}"

if [[ -n "${DOKPLOY_PROD_WEBHOOK_URL:-}" ]]; then
  gh secret set DOKPLOY_PROD_WEBHOOK_URL --repo "${REPO}" --body "${DOKPLOY_PROD_WEBHOOK_URL}"
  log "DOKPLOY_PROD_WEBHOOK_URL definido"
else
  log "AVISO: DOKPLOY_PROD_WEBHOOK_URL não definido — passar env ou configurar manualmente"
fi

if [[ -n "${DOKPLOY_API_KEY:-}" ]]; then
  gh secret set DOKPLOY_API_KEY --repo "${REPO}" --body "${DOKPLOY_API_KEY}"
  log "DOKPLOY_API_KEY definido"
fi

if [[ -n "${DOKPLOY_URL:-}" ]]; then
  gh secret set DOKPLOY_URL --repo "${REPO}" --body "${DOKPLOY_URL}"
  log "DOKPLOY_URL definido"
fi

if [[ -n "${AGLSRV1_SSH_KEY:-}" ]]; then
  gh secret set AGLSRV1_SSH_KEY --repo "${REPO}" --body "${AGLSRV1_SSH_KEY}"
  log "AGLSRV1_SSH_KEY definido"
fi

log "Secrets Harbor + CT134_HEALTH_URL configurados em ${REPO}"

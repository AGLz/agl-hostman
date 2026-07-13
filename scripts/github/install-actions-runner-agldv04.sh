#!/usr/bin/env bash
# Instala GitHub Actions self-hosted runner para agl-hostman (rede AGL + Harbor).
#
# Pré-requisitos: gh autenticado, docker, ssh root@AGLSRV1
#
# Uso:
#   bash scripts/github/install-actions-runner-agldv04.sh
#   RUNNER_NAME=agldv04-agl-hostman bash scripts/github/install-actions-runner-agldv04.sh
set -euo pipefail

REPO="${GITHUB_REPO:-AGLz/agl-hostman}"
RUNNER_VERSION="${RUNNER_VERSION:-2.335.1}"
RUNNER_DIR="${RUNNER_DIR:-/home/github-runner/actions-runner-agl-hostman}"
RUNNER_NAME="${RUNNER_NAME:-agldv04-agl-hostman}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,Linux,agl-network,harbor,ct134,dokploy}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
AGLSRV1_SSH="${AGLSRV1_SSH:-root@100.107.113.33}"

log() { printf '[install-runner] %s\n' "$*"; }

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Executar como root (systemd + /opt)" >&2
  exit 1
fi

if ! id "${RUNNER_USER}" &>/dev/null; then
  useradd -m -s /bin/bash "${RUNNER_USER}"
fi
usermod -aG docker "${RUNNER_USER}" 2>/dev/null || true

# ponytail: runner valida permissões até / — LXC com / 700 bloqueia registo
if [[ -d / ]] && ! sudo -u "${RUNNER_USER}" test -x /; then
  chmod o+rx /
  log "Aplicado chmod o+rx / (requisito actions-runner em LXC)"
fi

command -v gh >/dev/null || { echo "gh CLI necessário" >&2; exit 1; }
command -v docker >/dev/null || { echo "docker necessário" >&2; exit 1; }

# ponytail: runner scripts usam ssh BatchMode para AGLSRV1/Harbor creds
RUNNER_SSH_KEY="/home/${RUNNER_USER}/.ssh/agl-hostman-deploy"
install -d -m 700 -o "${RUNNER_USER}" -g "${RUNNER_USER}" "/home/${RUNNER_USER}/.ssh"
if [[ ! -f "${RUNNER_SSH_KEY}" ]]; then
  sudo -u "${RUNNER_USER}" ssh-keygen -t ed25519 -N "" -f "${RUNNER_SSH_KEY}" -C "github-runner-agl-hostman"
  log "Chave deploy criada — adicionar a AGLSRV1 authorized_keys:"
  cat "${RUNNER_SSH_KEY}.pub"
  ssh -o BatchMode=yes "${AGLSRV1_SSH}" \
    "grep -qF \"$(cat ${RUNNER_SSH_KEY}.pub)\" /root/.ssh/authorized_keys 2>/dev/null || cat >> /root/.ssh/authorized_keys" \
    && log "Chave deploy registada em ${AGLSRV1_SSH}"
fi
ssh-keyscan -H 100.107.113.33 >> "/home/${RUNNER_USER}/.ssh/known_hosts" 2>/dev/null || true
chown "${RUNNER_USER}:${RUNNER_USER}" "/home/${RUNNER_USER}/.ssh/known_hosts" 2>/dev/null || true
chmod 600 "/home/${RUNNER_USER}/.ssh/known_hosts" 2>/dev/null || true
cat > "/home/${RUNNER_USER}/.ssh/config" <<CFG
Host 100.107.113.33 aglsrv1
  IdentityFile ${RUNNER_SSH_KEY}
  IdentitiesOnly yes
  BatchMode yes
CFG
chown "${RUNNER_USER}:${RUNNER_USER}" "/home/${RUNNER_USER}/.ssh/config"
chmod 600 "/home/${RUNNER_USER}/.ssh/config"

TOKEN="$(gh api "repos/${REPO}/actions/runners/registration-token" -X POST --jq .token)"
[[ -n "${TOKEN}" ]] || { echo "Falha ao obter registration token" >&2; exit 1; }

mkdir -p "${RUNNER_DIR}"
chown "${RUNNER_USER}:${RUNNER_USER}" "${RUNNER_DIR}"

if [[ ! -f "${RUNNER_DIR}/config.sh" ]]; then
  log "Download actions-runner v${RUNNER_VERSION}..."
  sudo -u "${RUNNER_USER}" -H bash -lc "set -euo pipefail
    cd '${RUNNER_DIR}'
    curl -fsSL -o actions-runner.tgz \
      'https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz'
    tar xzf actions-runner.tgz && rm -f actions-runner.tgz"
fi

if [[ -f "${RUNNER_DIR}/.runner" ]]; then
  log "Runner já configurado — a remover registo anterior..."
  REMOVE_TOKEN="$(gh api "repos/${REPO}/actions/runners/remove-token" -X POST --jq .token)"
  sudo -u "${RUNNER_USER}" -H bash -lc "cd '${RUNNER_DIR}' && ./config.sh remove --token '${REMOVE_TOKEN}'" || true
fi

log "Configurar runner ${RUNNER_NAME} (${RUNNER_LABELS})..."
sudo -u "${RUNNER_USER}" -H bash -lc "cd '${RUNNER_DIR}' && ./config.sh \
  --url 'https://github.com/${REPO}' \
  --token '${TOKEN}' \
  --name '${RUNNER_NAME}' \
  --labels '${RUNNER_LABELS}' \
  --unattended \
  --replace"

log "Instalar serviço systemd..."
cd "${RUNNER_DIR}"
./svc.sh install "${RUNNER_USER}"
./svc.sh start

sleep 3
gh api "repos/${REPO}/actions/runners" --jq '.runners[] | {name, status, labels: [.labels[].name]}'
log "OK: runner ${RUNNER_NAME} em ${RUNNER_DIR}"

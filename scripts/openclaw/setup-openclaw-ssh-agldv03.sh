#!/usr/bin/env bash
# Aplica SSH para GitHub no container OpenClaw a partir do host agldv03.
# Caminho canónico do repo: /mnt/overpower/apps/dev/agl/openclaw-repo (NFS / U:\… na wk45)
#
# Uso (root): bash scripts/openclaw/setup-openclaw-ssh-agldv03.sh
# Opcional: SSH_KEY_SOURCE=/root/.ssh GITHUB_SSH_KEY_NAME=id_rsa

set -euo pipefail

REPO_ROOT="${AGL_OPENCLAW_REPO:-/mnt/overpower/apps/dev/agl/openclaw-repo}"
SETUP="${REPO_ROOT}/scripts/setup-docker-ssh.sh"

if [ ! -x "$SETUP" ] && [ -f "$SETUP" ]; then
  chmod +x "$SETUP"
fi

if [ ! -f "$SETUP" ]; then
  echo "ERRO: não encontrei $SETUP" >&2
  exit 1
fi

export SSH_KEY_SOURCE="${SSH_KEY_SOURCE:-/root/.ssh}"
export GITHUB_SSH_KEY_NAME="${GITHUB_SSH_KEY_NAME:-id_rsa}"

echo "=== OpenClaw SSH (host $(hostname -s)) → docker-ssh-node ==="
echo "    OPENCLAW_REPO=$REPO_ROOT"
echo "    SSH_KEY_SOURCE=$SSH_KEY_SOURCE"
echo "    GITHUB_SSH_KEY_NAME=$GITHUB_SSH_KEY_NAME"
echo ""

bash "$SETUP"

cd "$REPO_ROOT"
docker compose up -d --force-recreate openclaw-gateway

echo ""
echo "=== Teste SSH no container (node) ==="
docker compose exec -u node openclaw-gateway ssh -T git@github.com 2>&1 || true

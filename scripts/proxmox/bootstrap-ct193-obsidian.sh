#!/usr/bin/env bash
# Bootstrap CT193 agl-obsidian: Docker, CouchDB, Obsidian hub, bridge Git, systemd.
# Executar dentro do CT193 como root (após pct-apply-agldv03-lxc-profile).
set -euo pipefail

REPO="${AGL_HOSTMAN_DIR:-/mnt/overpower/apps/dev/agl/agl-hostman}"
LLM_WIKI="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"

if [[ ! -d "${REPO}/scripts/obsidian" ]]; then
  echo "ERRO: agl-hostman não encontrado em ${REPO}" >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y curl git inotify-tools xvfb x11-xserver-utils ca-certificates gnupg util-linux libasound2

if ! command -v docker >/dev/null; then
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian bookworm stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update
  apt-get install -y docker-ce docker-ce-cli docker-compose-plugin
fi

test -f "${LLM_WIKI}/wiki/index.md" || {
  echo "ERRO: llm-wiki NFS inacessível (${LLM_WIKI})" >&2
  echo "  Correr primeiro: pct-apply-agldv03-lxc-profile.sh --with-apparmor 193" >&2
  exit 1
}

# Reason: vault em NFS com uid diferente do root do CT
git config --global --add safe.directory "${LLM_WIKI}" 2>/dev/null || true

COUCHDB_DATA_DIR="${COUCHDB_DATA_DIR:-/var/lib/agl-obsidian/couchdb}"
mkdir -p "${COUCHDB_DATA_DIR}"
cd "${REPO}/docker/obsidian"
if [[ ! -f .env ]]; then
  cp .env.example .env
  echo "AVISO: editar ${REPO}/docker/obsidian/.env — definir COUCHDB_PASSWORD forte" >&2
fi
# Garantir path local no .env se ainda apontar para NFS sem permissão
if grep -q '^COUCHDB_DATA_DIR=/mnt/storage' .env 2>/dev/null; then
  sed -i "s|^COUCHDB_DATA_DIR=.*|COUCHDB_DATA_DIR=${COUCHDB_DATA_DIR}|" .env
fi
docker compose -f docker-compose.couchdb.yml up -d

bash "${REPO}/scripts/obsidian/install-obsidian-hub.sh"
bash "${REPO}/scripts/obsidian/install-obsidian-cli-wrapper.sh"

bash "${REPO}/scripts/obsidian/setup-github-gh.sh" --install-only || true

if ! command -v tailscale >/dev/null 2>&1; then
  curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled
fi

ln -sfn "${REPO}" /opt/agl-hostman
chmod +x "${REPO}/scripts/obsidian/"*.sh "${REPO}/scripts/proxmox/"pct-create-agl-obsidian.sh 2>/dev/null || true

cp "${REPO}/config/systemd/obsidian-hub.service" /etc/systemd/system/
cp "${REPO}/config/systemd/agl-llm-wiki-bridge.service" /etc/systemd/system/
cp "${REPO}/config/systemd/agl-llm-wiki-bridge-pull.service" /etc/systemd/system/
cp "${REPO}/config/systemd/agl-llm-wiki-bridge.timer" /etc/systemd/system/
systemctl daemon-reload
systemctl enable obsidian-hub agl-llm-wiki-bridge agl-llm-wiki-bridge.timer

# Só arrancar hub se .env tiver password não-default
if grep -q '^COUCHDB_PASSWORD=change-me' .env 2>/dev/null; then
  echo "AVISO: COUCHDB_PASSWORD ainda é placeholder — arrancar serviços após editar .env" >&2
else
  # Reason: obsidian.json (cli=true) tem de ser lido no arranque do hub.
  systemctl stop obsidian-hub 2>/dev/null || true
  sleep 2
  systemctl start obsidian-hub agl-llm-wiki-bridge agl-llm-wiki-bridge.timer 2>/dev/null || true
  sleep 20
fi

echo ""
echo "OK bootstrap CT193."
echo "Manual obrigatório:"
echo "  1. Editar docker/obsidian/.env (COUCHDB_PASSWORD)"
echo "  2. docker compose -f ${REPO}/docker/obsidian/docker-compose.couchdb.yml up -d"
echo "  3. Abrir vault llm-wiki no Obsidian; activar CLI; plugin LiveSync → 127.0.0.1:5984"
echo "  4. Tailscale: no AGLSRV1 — bash ${REPO}/scripts/proxmox/pct-tailscale-up-ct193-obsidian.sh"
echo "     depois: bash ${REPO}/scripts/proxmox/pct-install-agl-lan-routes.sh 193"
echo "  5. GitHub (gh): bash ${REPO}/scripts/obsidian/setup-github-gh.sh"
echo "     ou no agldv03: bash ${REPO}/scripts/obsidian/propagate-gh-auth-to-ct193.sh"
echo "  6. bash ${REPO}/scripts/obsidian/verify-obsidian-ct.sh"

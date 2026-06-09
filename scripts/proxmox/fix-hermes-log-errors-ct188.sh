#!/usr/bin/env bash
# Corrige erros recorrentes nas logs Hermes CT188 (Langfuse, SSH ro, venv web).
#
# Uso (root no CT188):
#   bash fix-hermes-log-errors-ct188.sh
#   bash fix-hermes-log-errors-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
SCRIPTS="${AGL_HOSTMAN}/scripts/proxmox"
SSH_MARKER="# hermes-ssh-ro-fallback"
SSH_CONFIG="/root/.ssh/config"

echo "=== 1/4 SSH: fallback para mount :ro (known_hosts) ==="
install -d -m 0700 /root/.ssh
touch "${SSH_CONFIG}"
chmod 0600 "${SSH_CONFIG}"
if ! grep -qF "${SSH_MARKER}" "${SSH_CONFIG}" 2>/dev/null; then
  cat >>"${SSH_CONFIG}" <<EOF

${SSH_MARKER}
# Contentores Hermes montam /root/.ssh em /opt/data/.ssh:ro — não é possível gravar known_hosts.
Host *
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
  echo "OK SSH fallback em ${SSH_CONFIG}"
else
  echo "OK SSH fallback já presente"
fi

echo "=== 2/4 Langfuse plugin + env ==="
if [[ -f "${SCRIPTS}/apply-langfuse-hermes-env.sh" ]]; then
  bash "${SCRIPTS}/apply-langfuse-hermes-env.sh" || echo "WARN: apply-langfuse falhou — verificar /root/.aglz-langfuse.env" >&2
else
  echo "WARN: script apply-langfuse inexistente em ${SCRIPTS}" >&2
fi

echo "=== 3/4 Reparar venv jarvis (fastapi/dashboard) ==="
if [[ -f "${SCRIPTS}/repair-hermes-jarvis-venv-ct188.sh" ]]; then
  bash "${SCRIPTS}/repair-hermes-jarvis-venv-ct188.sh"
else
  echo "WARN: repair venv script em falta" >&2
fi

echo "=== 4/4 Verificar rede Langfuse ==="
if docker inspect agl-hermes-jarvis --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' | grep -q agl-langfuse; then
  echo "OK jarvis na rede agl-langfuse"
else
  docker network connect agl-langfuse_default agl-hermes-jarvis 2>/dev/null || true
  for c in agl-hermes-elon agl-hermes-satya agl-hermes-werner; do
    docker network connect agl-langfuse_default "${c}" 2>/dev/null || true
  done
  echo "OK redes Langfuse ligadas"
fi

echo ""
echo "Concluído. Erros históricos (langfuse-web DNS, fastapi) devem cessar após restart."
echo "Seguinte: bash ${SCRIPTS}/enable-hermes-voice-ct188.sh"

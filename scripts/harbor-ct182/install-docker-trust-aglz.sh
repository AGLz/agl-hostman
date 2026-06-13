#!/usr/bin/env bash
# Instala CA Harbor (harbor.aglz.io) no trust store Docker de um host/CT.
#
# Uso no AGLSRV1 (CT134 exemplo):
#   bash scripts/harbor-ct182/install-docker-trust-aglz.sh 134
#
# Uso local (agldv03):
#   bash scripts/harbor-ct182/install-docker-trust-aglz.sh local

set -euo pipefail

TARGET="${1:-local}"
HARBOR_HOST="${HARBOR_HOST:-harbor.aglz.io}"
CT182_VMID="${CT182_VMID:-182}"
CA_REMOTE="/opt/harbor-certs/ca.crt"

fetch_ca() {
  local dest="$1"
  ssh -o StrictHostKeyChecking=no root@100.107.113.33 \
    "pct exec ${CT182_VMID} -- cat ${CA_REMOTE}" > "${dest}"
}

install_ca() {
  local dest_dir="/etc/docker/certs.d/${HARBOR_HOST}"
  mkdir -p "${dest_dir}"
  cp "$1" "${dest_dir}/ca.crt"
  if command -v update-ca-certificates >/dev/null 2>&1; then
    mkdir -p /usr/local/share/ca-certificates
    cp "$1" "/usr/local/share/ca-certificates/harbor-aglz.crt"
    update-ca-certificates 2>/dev/null || true
  fi
  echo "Trust instalado: ${dest_dir}/ca.crt"
}

TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT
fetch_ca "${TMP}"

if [[ "${TARGET}" == "local" ]]; then
  install_ca "${TMP}"
else
  scp -o StrictHostKeyChecking=no "${TMP}" "root@100.107.113.33:/tmp/harbor-ca.crt"
  ssh root@100.107.113.33 "pct exec ${TARGET} -- mkdir -p /etc/docker/certs.d/${HARBOR_HOST}"
  ssh root@100.107.113.33 "pct push ${TARGET} /tmp/harbor-ca.crt /tmp/harbor-ca.crt"
  ssh root@100.107.113.33 "pct exec ${TARGET} -- bash -s" <<EOF
set -euo pipefail
cp /tmp/harbor-ca.crt /etc/docker/certs.d/${HARBOR_HOST}/ca.crt
mkdir -p /usr/local/share/ca-certificates
cp /tmp/harbor-ca.crt /usr/local/share/ca-certificates/harbor-aglz.crt
update-ca-certificates 2>/dev/null || true
sed -i '/harbor\\.aglsrv1\\.local/d;/harbor\\.aglz\\.io/d' /etc/hosts
echo "${HARBOR_IP:-192.168.0.182} ${HARBOR_HOST} harbor.aglsrv1.local" >> /etc/hosts
systemctl restart docker
EOF
fi

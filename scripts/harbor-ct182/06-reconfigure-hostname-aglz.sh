#!/usr/bin/env bash
# Reconfigura Harbor CT182: hostname harbor.aglz.io + certificado SAN.
# Executar DENTRO do CT182 como root (ou: ssh AGLSRV1 'pct exec 182 -- bash -s' < script).
#
# Uso:
#   HARBOR_HOSTNAME=harbor.aglz.io HARBOR_IP=192.168.0.182 bash 06-reconfigure-hostname-aglz.sh
#
# Após execução, nos clientes Docker:
#   mkdir -p /etc/docker/certs.d/harbor.aglz.io
#   scp CT182:/opt/harbor-certs/ca.crt /etc/docker/certs.d/harbor.aglz.io/ca.crt
#   docker login harbor.aglz.io

set -euo pipefail

HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.aglz.io}"
HARBOR_IP="${HARBOR_IP:-192.168.0.182}"
CERT_DIR="${CERT_DIR:-/opt/harbor-certs}"
HARBOR_DIR="${HARBOR_DIR:-/opt/harbor}"
HARBOR_YML="${HARBOR_DIR}/harbor.yml"

log() { echo "[harbor-aglz] $*"; }

[[ -f "${HARBOR_YML}" ]] || {
  log "ERRO: ${HARBOR_YML} não encontrado"
  exit 1
}

log "Hostname: ${HARBOR_HOSTNAME} · IP: ${HARBOR_IP} · certs: ${CERT_DIR}"

mkdir -p "${CERT_DIR}"
cd "${CERT_DIR}"

if [[ ! -f ca.key ]]; then
  log "Gerar CA (primeira vez)..."
  openssl genrsa -out ca.key 4096
  openssl req -x509 -new -nodes -sha512 -days 3650 \
    -subj "/C=BR/ST=SP/L=SaoPaulo/O=AGL/OU=Infra/CN=Harbor CA" \
    -key ca.key -out ca.crt
fi

log "Gerar certificado servidor..."
openssl genrsa -out server.key 4096
openssl req -sha512 -new \
  -subj "/C=BR/ST=SP/L=SaoPaulo/O=AGL/OU=Infra/CN=${HARBOR_HOSTNAME}" \
  -key server.key -out server.csr

cat > v3.ext <<EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${HARBOR_HOSTNAME}
DNS.2=harbor.aglsrv1.local
DNS.3=harbor
IP.1=${HARBOR_IP}
IP.2=127.0.0.1
EOF

openssl x509 -req -sha512 -days 3650 \
  -extfile v3.ext \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -in server.csr -out server.crt

openssl x509 -inform PEM -in server.crt -out server.cert
chmod 600 server.key
chmod 644 server.crt server.cert ca.crt

log "Actualizar ${HARBOR_YML}..."
sed -i "s/^hostname:.*/hostname: ${HARBOR_HOSTNAME}/" "${HARBOR_YML}"

log "Harbor prepare + restart..."
cd "${HARBOR_DIR}"
./prepare
docker compose up -d
docker compose up -d --force-recreate proxy

log "Verificar certificado..."
echo | openssl s_client -connect "127.0.0.1:443" -servername "${HARBOR_HOSTNAME}" 2>/dev/null \
  | openssl x509 -noout -subject -ext subjectAltName 2>/dev/null || true

log "OK — UI/registry: https://${HARBOR_HOSTNAME}"
log "CA para clientes: ${CERT_DIR}/ca.crt"

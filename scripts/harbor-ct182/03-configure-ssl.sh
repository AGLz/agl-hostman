#!/bin/bash
################################################################################
# Harbor CT182 - SSL Configuration Script
# Phase 3: Generate self-signed certificates for Harbor
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
HARBOR_HOSTNAME="${HARBOR_HOSTNAME:-harbor.aglz.io}"
HARBOR_IP="${HARBOR_IP:-192.168.0.182}"
CERT_DIR="/data/cert"

log_info "Starting SSL certificate generation..."
log_info "Hostname: $HARBOR_HOSTNAME"
log_info "IP: $HARBOR_IP"

# Create certificate directory
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

# Generate CA certificate
log_info "Generating CA certificate..."
openssl genrsa -out ca.key 4096

openssl req -x509 -new -nodes -sha512 -days 3650 \
    -subj "/C=BR/ST=State/L=City/O=AGL/OU=IT/CN=Harbor CA" \
    -key ca.key \
    -out ca.crt

# Generate server certificate
log_info "Generating server certificate..."
openssl genrsa -out server.key 4096

openssl req -sha512 -new \
    -subj "/C=BR/ST=State/L=City/O=AGL/OU=IT/CN=${HARBOR_HOSTNAME}" \
    -key server.key \
    -out server.csr

# Create v3 extension file
cat > v3.ext <<-EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1=${HARBOR_HOSTNAME}
DNS.2=harbor.aglsrv1.local
DNS.3=harbor.aglz.io
DNS.4=harbor
IP.1=${HARBOR_IP}
IP.2=127.0.0.1
EOF

# Sign server certificate
log_info "Signing server certificate..."
openssl x509 -req -sha512 -days 3650 \
    -extfile v3.ext \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -in server.csr \
    -out server.crt

# Convert for Docker
log_info "Converting certificates for Docker..."
openssl x509 -inform PEM -in server.crt -out server.cert

# Set permissions
chmod 600 server.key
chmod 644 server.crt server.cert ca.crt

# Copy CA cert to system trust store
log_info "Installing CA certificate to system trust store..."
mkdir -p /usr/local/share/ca-certificates/
cp ca.crt /usr/local/share/ca-certificates/harbor-ca.crt
update-ca-certificates

# Create Docker cert directory
log_info "Configuring Docker to trust Harbor certificates..."
mkdir -p /etc/docker/certs.d/${HARBOR_HOSTNAME}
mkdir -p /etc/docker/certs.d/${HARBOR_IP}

cp server.cert /etc/docker/certs.d/${HARBOR_HOSTNAME}/
cp server.key /etc/docker/certs.d/${HARBOR_HOSTNAME}/
cp ca.crt /etc/docker/certs.d/${HARBOR_HOSTNAME}/

cp server.cert /etc/docker/certs.d/${HARBOR_IP}/
cp server.key /etc/docker/certs.d/${HARBOR_IP}/
cp ca.crt /etc/docker/certs.d/${HARBOR_IP}/

log_info "SSL certificates generated successfully!"
log_info "Certificate location: $CERT_DIR"
log_info "CA cert: $CERT_DIR/ca.crt"
log_info "Server cert: $CERT_DIR/server.crt"
log_info "Server key: $CERT_DIR/server.key"

log_warn "⚠️  PRODUCTION NOTE: These are self-signed certificates!"
log_warn "For production use, replace with certificates from:"
log_warn "  - Let's Encrypt (free, automated)"
log_warn "  - Corporate CA (enterprise)"

exit 0

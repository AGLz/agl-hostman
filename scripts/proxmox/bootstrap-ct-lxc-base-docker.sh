#!/usr/bin/env bash
# Base Debian: Docker + utilitários (executar dentro do CT como root).
# Tailscale: instalar binário; `tailscale up` requer TAILSCALE_AUTHKEY ou login manual.
#
# Uso: bash bootstrap-ct-lxc-base-docker.sh

set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

echo "=== locales (en_US.UTF-8) ==="
apt-get update -qq
apt-get install -y -qq locales ca-certificates curl git gnupg python3 python3-yaml python3-pip
if ! locale -a 2>/dev/null | grep -qi 'en_US.utf-8'; then
  sed -i '/en_US.UTF-8/s/^# //' /etc/locale.gen 2>/dev/null || echo 'en_US.UTF-8 UTF-8' >>/etc/locale.gen
  locale-gen en_US.UTF-8 2>/dev/null || true
fi
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 2>/dev/null || true
export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

if ! command -v docker >/dev/null 2>&1; then
  echo "=== Docker (get.docker.com) ==="
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker 2>/dev/null || true
fi

if ! command -v tailscale >/dev/null 2>&1; then
  echo "=== Tailscale ==="
  curl -fsSL https://tailscale.com/install.sh | sh
  systemctl enable --now tailscaled 2>/dev/null || true
fi

docker --version
tailscale version 2>/dev/null | head -1 || true
echo "OK: base docker+tailscale instalados"

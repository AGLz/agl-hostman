#!/usr/bin/env bash
# Bootstrap OpenHuman no CT190 (Debian + dependências + install oficial).
# OpenHuman é UI-first (Tauri); em LXC headless usar para dados/API ou X11 forwarding.
#
# Uso:
#   bash bootstrap-ct190-openhuman.sh [http://IP_CT186:4000]
#
# Doc: https://tinyhumans.gitbook.io/openhuman/developing/getting-set-up
# Repo: https://github.com/tinyhumansai/openhuman

set -euo pipefail

LITELLM_BASE_URL="${1:-http://192.168.0.186:4000}"

export DEBIAN_FRONTEND=noninteractive

echo "=== Pacotes base (OpenHuman / build opcional) ==="
apt-get update -qq
apt-get install -y -qq \
  ca-certificates curl git \
  build-essential cmake ninja-build pkg-config \
  libssl-dev libgtk-3-dev libwebkit2gtk-4.1-dev librsvg2-dev \
  libasound2-dev libpulse-dev

install -d -m 0755 /opt/openhuman
cd /opt/openhuman

if [[ ! -d /opt/openhuman/openhuman/.git ]]; then
  echo "=== Clone openhuman (shallow) ==="
  git clone --depth 1 https://github.com/tinyhumansai/openhuman.git /opt/openhuman/upstream
fi

echo "=== Instalar runtime via script oficial (binário) ==="
if ! command -v openhuman >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/tinyhumansai/openhuman/main/scripts/install.sh | bash || {
    echo "AVISO: install.sh falhou (ambiente headless). Compilar a partir de upstream:" >&2
    echo "  cd /opt/openhuman/upstream && pnpm install && pnpm --filter openhuman-app build" >&2
  }
fi

install -d -m 0700 /var/lib/openhuman
cat >/var/lib/openhuman/litellm-gateway.url <<EOF
# Gateway AGL (CT186) — configurar no OpenHuman settings / config.toml
${LITELLM_BASE_URL}
EOF

echo "OK: CT190 preparado. OpenHuman requer UI ou cloud deploy para uso completo."
echo "     Dados locais: ~/.config/openhuman ou /var/lib/openhuman"
echo "     LiteLLM sugerido: ${LITELLM_BASE_URL}"

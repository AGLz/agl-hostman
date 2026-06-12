#!/usr/bin/env bash
# Instala Obsidian Linux em /opt/obsidian (CT193 headless hub).
set -euo pipefail

OBSIDIAN_VERSION="${OBSIDIAN_VERSION:-}"
OBSIDIAN_VERSION_FALLBACK="${OBSIDIAN_VERSION_FALLBACK:-v1.12.4}"
INSTALL_DIR="${OBSIDIAN_INSTALL_DIR:-/opt/obsidian}"
ARCH="${OBSIDIAN_ARCH:-amd64}"

resolve_version() {
  if [[ -n "${OBSIDIAN_VERSION}" ]]; then
    echo "${OBSIDIAN_VERSION}"
    return
  fi
  local tag gh_cmd
  gh_cmd="$(command -v gh 2>/dev/null || true)"
  if [[ -n "${gh_cmd}" ]]; then
    tag="$("${gh_cmd}" api repos/obsidianmd/obsidian-releases/releases/latest -q .tag_name 2>/dev/null || true)"
    if [[ -n "${tag}" ]]; then
      echo "${tag}"
      return 0
    fi
  fi
  tag="$(curl -fsSL --max-time 45 --retry 2 https://api.github.com/repos/obsidianmd/obsidian-releases/releases/latest \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -1)" || true
  if [[ -n "${tag}" ]]; then
    echo "${tag}"
  else
    echo "AVISO: API GitHub indisponível — fallback ${OBSIDIAN_VERSION_FALLBACK}" >&2
    echo "${OBSIDIAN_VERSION_FALLBACK}"
  fi
}

main() {
  local version deb_url tmp_deb
  version="$(resolve_version)"
  deb_url="https://github.com/obsidianmd/obsidian-releases/releases/download/${version}/obsidian_${version#v}_${ARCH}.deb"
  tmp_deb="$(mktemp /tmp/obsidian.XXXXXX.deb)"

  echo "=== Obsidian ${version} → ${INSTALL_DIR} ==="
  curl -fsSL --max-time 300 --retry 3 -o "${tmp_deb}" "${deb_url}"

  apt-get install -y xauth xvfb x11-xserver-utils libgtk-3-0 libnotify4 libnss3 libxss1 libxtst6 \
    libsecret-1-0 libgbm1 libasound2 2>/dev/null || apt-get install -y xauth xvfb x11-xserver-utils libasound2

  dpkg-deb -x "${tmp_deb}" /tmp/obsidian-extract
  install -d "${INSTALL_DIR}"
  if [[ -f /tmp/obsidian-extract/opt/Obsidian/obsidian ]]; then
    cp -a /tmp/obsidian-extract/opt/Obsidian/. "${INSTALL_DIR}/"
  elif [[ -f /tmp/obsidian-extract/usr/bin/obsidian ]]; then
    cp -a /tmp/obsidian-extract/usr/bin/obsidian "${INSTALL_DIR}/obsidian"
  else
    echo "ERRO: estrutura .deb inesperada" >&2
    find /tmp/obsidian-extract -name obsidian -type f 2>/dev/null | head -5 >&2
    exit 1
  fi
  chmod +x "${INSTALL_DIR}/obsidian"
  ln -sfn "${INSTALL_DIR}/obsidian" /usr/local/bin/obsidian-app

  rm -f "${tmp_deb}"
  rm -rf /tmp/obsidian-extract

  echo "OK: Obsidian em ${INSTALL_DIR}/obsidian"
  echo "Nota: activar CLI no Obsidian (Settings → Command line interface) após primeiro arranque com vault."
  echo "systemd: config/systemd/obsidian-hub.service"
}

main "$@"

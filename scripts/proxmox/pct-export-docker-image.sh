#!/usr/bin/env bash
# Exporta imagem Docker de um CT e importa noutro (mesmo nó Proxmox).
# Uso: pct-export-docker-image.sh <src_vmid> <image:tag> <dst_vmid>
set -euo pipefail
SRC="${1:?src vmid}"; IMG="${2:?image:tag}"; DST="${3:?dst vmid}"
command -v pct >/dev/null
echo "=== ${IMG}: CT${SRC} → CT${DST} ==="
pct exec "${SRC}" -- docker image inspect "${IMG}" >/dev/null
pct exec "${SRC}" -- docker save "${IMG}" | pct exec "${DST}" -- docker load
echo "OK"

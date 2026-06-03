#!/usr/bin/env bash
# FGSRV7: 4 vCPU em CT243 (fg-legacy) e CT235 (mysql7).

set -euo pipefail

EXPECT_HOSTNAME="${EXPECT_HOSTNAME:-fgsrv7}"
CORES="${CORES:-4}"

if ! command -v pct >/dev/null 2>&1; then
    echo "Erro: pct não encontrado." >&2
    exit 1
fi

if [[ -n "${EXPECT_HOSTNAME}" ]] && [[ "$(hostname -s)" != "${EXPECT_HOSTNAME}" ]]; then
    echo "Erro: hostname ($(hostname -s)) != EXPECT_HOSTNAME=${EXPECT_HOSTNAME}" >&2
    exit 1
fi

for vmid in 243 235; do
    echo "==> pct set ${vmid} -cores ${CORES}"
    pct set "${vmid}" -cores "${CORES}"
    pct exec "${vmid}" -- nproc
done

echo "OK cores=${CORES} em CT243 e CT235"

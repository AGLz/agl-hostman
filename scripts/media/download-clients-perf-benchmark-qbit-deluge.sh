#!/usr/bin/env bash
# Benchmark comparativo qBit CT121 vs Deluge CT157 — download fresco Debian netinst.
#
# Uso:
#   bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh
#   bash scripts/media/download-clients-perf-benchmark-qbit-deluge.sh --skip-optimize

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export TORRENT_URL="${TORRENT_URL:-https://cdimage.debian.org/debian-cd/current/amd64/bt-cd/debian-13.5.0-amd64-netinst.iso.torrent}"
export TORRENT_NAME="${TORRENT_NAME:-debian-13.5.0-amd64-netinst.iso}"
export BENCHMARK_ONLY_TORRENT=1

args=()
[[ "${1:-}" == --skip-optimize ]] && args+=(--skip-optimize)

exec bash "$REPO_ROOT/scripts/media/download-clients-perf-benchmark.sh" "${args[@]}"

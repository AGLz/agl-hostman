#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
docker compose -f "$DIR/docker-compose.yml" down

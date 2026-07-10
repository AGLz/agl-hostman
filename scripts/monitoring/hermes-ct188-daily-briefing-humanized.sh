#!/usr/bin/env bash
# Wrapper cron Jarvis — briefing consolidado (fleet + infra).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/hermes-ct188-daily-briefing-fleet.sh"

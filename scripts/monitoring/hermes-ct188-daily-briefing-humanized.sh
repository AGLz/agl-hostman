#!/usr/bin/env bash
# Wrapper cron Jarvis — briefing humanizado (delega ao script operacional).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/hermes-ct188-daily-briefing.sh"

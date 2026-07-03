#!/usr/bin/env bash
# ponytail: smoke — eval pack QA/DevSecOps existe e verify passa
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
exec bash "$ROOT/scripts/skills/eval-agl-qa-devsecops-skills.sh"

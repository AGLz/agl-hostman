#!/usr/bin/env bash
# Alinha openclaw.json no host com o repo (modo direct): patch de defaults + providers Moonshot/DashScope.
# Ordem: merge profundo de openclaw-patch.json → apply-openclaw-direct-providers.py (ambos com backup).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1

# Opções avançadas (--target, --dry-run, --agent-id): invocar os .py separadamente.
python3 "${ROOT}/scripts/openclaw/merge-openclaw-json-patch.py"
python3 "${ROOT}/scripts/openclaw/apply-openclaw-direct-providers.py"

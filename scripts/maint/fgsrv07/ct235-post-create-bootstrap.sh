#!/usr/bin/env bash
# Pós-criação / recriação do CT235 (mysql7): apenas timezone America/Sao_Paulo.
# Correr no guest ou via pct-bootstrap-fg-stack-locale.sh --ct 235

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ct-set-timezone-sao-paulo.sh
source "${SCRIPT_DIR}/lib/ct-set-timezone-sao-paulo.sh"

echo "OK ct235 timezone (sem locale pt-BR — servidor MariaDB)"

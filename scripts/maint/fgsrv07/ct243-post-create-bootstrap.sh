#!/usr/bin/env bash
# Pós-criação / recriação do CT243 (fg-legacy): GMT-3 + pt-BR (SO + PHP 5.6).
# Correr no guest: bash ct243-post-create-bootstrap.sh
# Ou no host FGSRV7: bash scripts/maint/fgsrv07/pct-bootstrap-fg-stack-locale.sh --ct 243

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/ct-set-timezone-sao-paulo.sh
source "${SCRIPT_DIR}/lib/ct-set-timezone-sao-paulo.sh"
# shellcheck source=lib/ct243-locale-php-pt-br.sh
source "${SCRIPT_DIR}/lib/ct243-locale-php-pt-br.sh"

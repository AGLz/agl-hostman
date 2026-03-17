#!/bin/bash
# ========================================
# Locaweb VPS API Configuration
# ========================================
# Source this file in other scripts: source /path/to/config.sh"

#
# API Configuration
export LW_API_URL="https://api-servidores.locaweb.com.br/v1"
export LW_API_TOKEN="cfadcdc252c769e5ef66f3c7a867c3731fc590de3c78fdefd5062d6a"
export LW_API_USER="adminfalg"

#
# VPS IDs (consistent naming: VPS_FGSRVxx)
export VPS_FGSRV03="vps14419"
export VPS_FGSRV04="vps22826"
export VPS_FGSRV05="vps24136"
export VPS_FGSRV06="vps41772"
export VPS_FGSRV07="vps64306"

#
# Base curl command with proper headers
lw_curl() {
    curl -s \
        -H "X-User-Token: $LW_API_TOKEN" \
        -H "X-User-Login: $LW_API_USER" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$@"
}

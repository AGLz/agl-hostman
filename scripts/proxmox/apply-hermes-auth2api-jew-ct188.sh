#!/usr/bin/env bash
# Compat: JEW → fleet completo (todos os agents Plus/Pro; aux=glm).
# Ver apply-hermes-auth2api-fleet-ct188.sh
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply-hermes-auth2api-fleet-ct188.sh" "$@"

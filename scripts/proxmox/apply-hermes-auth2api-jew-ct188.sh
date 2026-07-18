#!/usr/bin/env bash
# Compat: JEW → fleet completo (todos Plus/Pro; aux=glm; Jarvis=Fable5).
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/apply-hermes-auth2api-fleet-ct188.sh" "$@"

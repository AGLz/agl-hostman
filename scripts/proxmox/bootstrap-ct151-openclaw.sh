#!/usr/bin/env bash
# Compat: CT151 foi substituído por CT187 no runbook AGLSRV1.
echo "AVISO: use bootstrap-ct187-openclaw.sh (CT187). Este wrapper delega." >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-ct187-openclaw.sh" "$@"

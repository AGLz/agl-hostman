#!/usr/bin/env bash
# Compat: CT150 foi substituído por CT186 no runbook AGLSRV1 (150/151 = VMs QEMU).
echo "AVISO: use bootstrap-ct186-litellm.sh (CT186). Este wrapper delega." >&2
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bootstrap-ct186-litellm.sh" "$@"

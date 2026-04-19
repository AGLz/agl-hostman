#!/usr/bin/env bash
# Propaga ~/.openclaw/openclaw.json desde agldv03 para hosts satélite.
# Nunca altera ~/.openclaw/cron/ (cada host mantém os seus schedulers).
#
# Satélites com LiteLLM em localhost (ex. fgsrv06): aplica fgsrv06-litellm.jq após a cópia.
# Demais satélites: aplica openclaw-litellm-client.jq + litellm-gateway-client.env.
#
# Uso (a partir de máquina com SSH+Tailscale aos hosts):
#   bash scripts/openclaw/propagate-openclaw-from-agldv03.sh
#   DRY_RUN=1 bash scripts/openclaw/propagate-openclaw-from-agldv03.sh
#
# Variáveis:
#   OPENCLAW_PROPAGATE_SOURCE   default root@100.94.221.87 (agldv03)
#   SKIP_GATEWAY_RESTART        se 1, não reinicia openclaw-gateway nos destinos Linux
#   AGLWK45_VIA_AGLSRV1         se 1, após satélites: SSH AGLSRV1 + guest agent VM104 (openclaw.json)

set -euo pipefail

OPENCLAW_SSH=(ssh -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)
OPENCLAW_SCP=(scp -o ProxyCommand="tailscale nc %h %p" -o BatchMode=yes -o ConnectTimeout=25 -o StrictHostKeyChecking=accept-new)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE="${OPENCLAW_PROPAGATE_SOURCE:-root@100.94.221.87}"
REMOTE_JSON="~/.openclaw/openclaw.json"

CLIENT_JQ="$REPO_ROOT/config/openclaw/openclaw-litellm-client.jq"
FGSRV_JQ="$REPO_ROOT/config/openclaw/fgsrv06-litellm.jq"
CLIENT_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-client.env"
ZSHRC_ENV="$REPO_ROOT/config/openclaw/zshrc-openclaw.env"
SYNC_ENV_SCRIPT="$REPO_ROOT/scripts/openclaw/sync-systemd-openclaw-env.sh"

# Formato: "user@tailscale-ip|mode"  mode = client | local_litellm
# agldv07 = Archon CT183; agldv12 = clone dev (INFRA.md)
SATELLITES=(
  "root@100.113.9.98|client"    # agldv04
  "root@100.119.41.63|client"   # agldv05
  "root@100.80.30.59|client"    # agldv07 (archon)
  "root@100.71.217.115|client"  # agldv12
  "root@100.83.51.9|local_litellm"  # fgsrv06 (LiteLLM local)
)

if [[ ! -f "$CLIENT_JQ" || ! -f "$FGSRV_JQ" ]]; then
  echo "Erro: ficheiros .jq em config/openclaw/ em falta."
  exit 1
fi

if [[ "${DRY_RUN:-0}" == "1" ]]; then
  echo "=== DRY_RUN: origem $SOURCE → openclaw.json (pasta cron/ intacta em cada destino) ==="
  printf '  %s\n' "${SATELLITES[@]}"
  echo "aglwk45 (VM104): AGLWK45_VIA_AGLSRV1=1 → SSH AGLSRV1 + qemu guest agent (scripts/openclaw/propagate-openclaw-to-aglwk45-qemu.sh)."
  exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== Origem: $SOURCE (openclaw.json) ==="

"${OPENCLAW_SCP[@]}" -q "$SOURCE:$REMOTE_JSON" "$TMP_DIR/openclaw-src.json"
if [[ ! -s "$TMP_DIR/openclaw-src.json" ]]; then
  echo "Erro: não foi possível ler openclaw.json em $SOURCE"
  exit 1
fi

for entry in "${SATELLITES[@]}"; do
  host="${entry%%|*}"
  mode="${entry##*|}"
  ip="${host#*@}"

  echo ""
  echo "=== Destino: $host (modo $mode) — cron/ não é tocado ==="

  "${OPENCLAW_SSH[@]}" "$host" "mkdir -p ~/.openclaw && cp -a ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak.propagate-$(date +%Y%m%d%H%M%S) 2>/dev/null || true"

  if [[ "$mode" == "client" ]]; then
    jq -f "$CLIENT_JQ" "$TMP_DIR/openclaw-src.json" > "$TMP_DIR/openclaw-out.json"
    "${OPENCLAW_SCP[@]}" -q "$TMP_DIR/openclaw-out.json" "$host:$REMOTE_JSON"
    "${OPENCLAW_SCP[@]}" -q "$CLIENT_ENV" "$host:~/.openclaw/litellm-gateway.env"
  else
    cp "$TMP_DIR/openclaw-src.json" "$TMP_DIR/openclaw-pre-fgsrv.json"
    jq -f "$FGSRV_JQ" "$TMP_DIR/openclaw-pre-fgsrv.json" > "$TMP_DIR/openclaw-out.json"
    "${OPENCLAW_SCP[@]}" -q "$TMP_DIR/openclaw-out.json" "$host:$REMOTE_JSON"
    # fgsrv06: manter env local LiteLLM (deploy-openclaw-config.sh já usava litellm-gateway-local.env)
    LITELLM_LOCAL_ENV="$REPO_ROOT/config/openclaw/litellm-gateway-local.env"
    if [[ -f "$LITELLM_LOCAL_ENV" ]]; then
      "${OPENCLAW_SCP[@]}" -q "$LITELLM_LOCAL_ENV" "$host:~/.openclaw/litellm-gateway.env"
    fi
  fi

  "${OPENCLAW_SCP[@]}" -q "$ZSHRC_ENV" "$host:~/.openclaw/zshrc-openclaw.env" 2>/dev/null || true
  "${OPENCLAW_SCP[@]}" -q "$SYNC_ENV_SCRIPT" "$host:/tmp/sync-systemd-openclaw-env.sh"
  "${OPENCLAW_SSH[@]}" "$host" "chmod +x /tmp/sync-systemd-openclaw-env.sh && bash /tmp/sync-systemd-openclaw-env.sh"

  if [[ "${SKIP_GATEWAY_RESTART:-0}" != "1" ]]; then
    "${OPENCLAW_SSH[@]}" "$host" 'systemctl --user daemon-reload && systemctl --user restart openclaw-gateway 2>/dev/null' \
      && echo "  gateway: reiniciado" || echo "  gateway: restart ignorado ou serviço ausente"
  fi
  echo "  OK: $host"
done

echo ""
echo "=== aglwk45 (Windows, VM104) ==="
if [[ "${AGLWK45_VIA_AGLSRV1:-0}" == "1" ]]; then
  jq -f "$CLIENT_JQ" "$TMP_DIR/openclaw-src.json" > "$TMP_DIR/openclaw-wk45.json"
  export OPENCLAW_WK45_JSON_PREPARED="$TMP_DIR/openclaw-wk45.json"
  bash "$REPO_ROOT/scripts/openclaw/propagate-openclaw-to-aglwk45-qemu.sh"
  unset OPENCLAW_WK45_JSON_PREPARED || true
else
  echo "Para empurrar openclaw.json via SSH ao AGLSRV1 + QEMU guest agent (sem tocar em cron/):"
  echo "  AGLWK45_VIA_AGLSRV1=1 bash scripts/openclaw/propagate-openclaw-from-agldv03.sh"
  echo "Ou só a VM104 (reutiliza download se já tiveres JSON preparado):"
  echo "  bash scripts/openclaw/propagate-openclaw-to-aglwk45-qemu.sh"
  echo "Variáveis: AGLSRV1_HOST (default root@100.107.113.33), AGLWK45_VMID (default 104)."
fi
echo ""
echo "=== Concluído (satélites Linux + opcional wk45) ==="

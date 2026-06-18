#!/usr/bin/env bash
# Clona CT570 cloudflared7 → CT575 cloudflared6 (túnel aglsrv5e migrado do FGSRV6).
# Padrão idêntico a provision-cloudflared7b-from-170.sh: clone --full, IP novo,
# desinstalar cloudflared herdado, service install com token do túnel aglsrv5e.
#
# Uso no host Proxmox FGSRV7 (root):
#   export CF_TUNNEL_TOKEN='(token JWT "cloudflared service install" — aglsrv5e; não commitar)'
#   bash /caminho/agl-hostman/scripts/maint/fgsrv07/provision-cloudflared6-from-570.sh
#
# Após provisionar: actualizar ingress Zero Trust (n8n5e → n8n7, etc.) — ver
# docs/maint/FGSRV6-DNS-CHECKLIST.md e scripts/cloudflare/update-fgsrv7b-tunnel-fg-legacy-ingress.sh
#
# Variáveis opcionais:
#   SOURCE_VMID=570 NEW_VMID=575 NEW_HOSTNAME=cloudflared6
#   NEW_IP=192.168.70.249 GATEWAY=192.168.70.1 BRIDGE=vmbr70
#   EXPECT_HOSTNAME=fgsrv7

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-cloudflared-envfile-install.sh
source "${SCRIPT_DIR}/lib-cloudflared-envfile-install.sh"

SOURCE_VMID="${SOURCE_VMID:-570}"
NEW_VMID="${NEW_VMID:-575}"
NEW_HOSTNAME="${NEW_HOSTNAME:-cloudflared6}"
NEW_IP="${NEW_IP:-192.168.70.249}"
GATEWAY="${GATEWAY:-192.168.70.1}"
BRIDGE="${BRIDGE:-vmbr70}"

if [[ -z "${CF_TUNNEL_TOKEN:-}" ]]; then
    echo 'Erro: defina CF_TUNNEL_TOKEN (token JWT do instalador do túnel aglsrv5e na Cloudflare).' >&2
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    echo 'Erro: pct não encontrado — correr como root no nó Proxmox FGSRV7.' >&2
    exit 1
fi

if [[ -n "${EXPECT_HOSTNAME:-}" ]] && [[ "$(hostname -s)" != "${EXPECT_HOSTNAME}" ]]; then
    echo "Erro: hostname do nó ($(hostname -s)) != EXPECT_HOSTNAME=${EXPECT_HOSTNAME}" >&2
    exit 1
fi

if pct status "${NEW_VMID}" &>/dev/null; then
    echo "Erro: VMID ${NEW_VMID} já existe. Ajuste NEW_VMID ou remova o CT." >&2
    exit 1
fi

echo "==> Clonar CT ${SOURCE_VMID} -> ${NEW_VMID} (hostname ${NEW_HOSTNAME})"
_snap_name="snap-clone-${NEW_VMID}-$$"
if pct status "${SOURCE_VMID}" 2>&1 | grep -qi running; then
    if pct snapshot "${SOURCE_VMID}" "${_snap_name}" 2>/dev/null; then
        echo "==> Clone completo a partir do snapshot ${_snap_name}"
        pct clone "${SOURCE_VMID}" "${NEW_VMID}" --hostname "${NEW_HOSTNAME}" --full --snapshot "${_snap_name}"
        pct delsnapshot "${SOURCE_VMID}" "${_snap_name}"
    else
        echo "==> Snapshot indisponível neste storage: parar CT ${SOURCE_VMID} para clone --full (interrupção breve do túnel fgsrv7)."
        pct stop "${SOURCE_VMID}"
        if ! pct clone "${SOURCE_VMID}" "${NEW_VMID}" --hostname "${NEW_HOSTNAME}" --full; then
            echo "Erro: clone falhou; a reiniciar CT fonte ${SOURCE_VMID}." >&2
            pct start "${SOURCE_VMID}"
            exit 1
        fi
        pct start "${SOURCE_VMID}"
    fi
else
    pct clone "${SOURCE_VMID}" "${NEW_VMID}" --hostname "${NEW_HOSTNAME}" --full
fi

echo "==> Rede CT ${NEW_VMID}: ${NEW_IP}/24 gw ${GATEWAY} (${BRIDGE})"
pct set "${NEW_VMID}" -net0 "name=eth0,bridge=${BRIDGE},ip=${NEW_IP}/24,gw=${GATEWAY},type=veth"

echo "==> Iniciar CT ${NEW_VMID}"
pct start "${NEW_VMID}"
sleep 6

echo "==> Ajustar hostname no guest (idempotente)"
pct exec "${NEW_VMID}" -- hostnamectl set-hostname "${NEW_HOSTNAME}" 2>/dev/null || true

echo "==> Parar serviço cloudflared herdado do clone (túnel fgsrv7)"
pct exec "${NEW_VMID}" -- systemctl stop cloudflared 2>/dev/null || true
pct exec "${NEW_VMID}" -- systemctl disable cloudflared 2>/dev/null || true

echo "==> Desinstalar unidade systemd cloudflared herdada"
if ! pct exec "${NEW_VMID}" -- cloudflared service uninstall 2>/dev/null; then
    echo "==> uninstall não concluiu: remover unidades manualmente"
    pct exec "${NEW_VMID}" -- bash -c 'systemctl stop cloudflared 2>/dev/null; systemctl disable cloudflared 2>/dev/null; rm -f /etc/systemd/system/cloudflared.service /etc/systemd/system/cloudflared-update.service /etc/systemd/system/cloudflared-update.timer; systemctl daemon-reload'
fi

echo "==> Remover credenciais/config do túnel fgsrv7"
pct exec "${NEW_VMID}" -- bash -c 'rm -f /etc/cloudflared/*.json /etc/cloudflared/config.yml /etc/default/cloudflared 2>/dev/null; rm -rf /etc/systemd/system/cloudflared.service.d 2>/dev/null; systemctl daemon-reload 2>/dev/null || true'

ENV_TMP="$(mktemp)"
trap 'rm -f "$ENV_TMP"' EXIT
printf 'TUNNEL_TOKEN=%s\n' "${CF_TUNNEL_TOKEN}" >"$ENV_TMP"
chmod 600 "$ENV_TMP"
unset CF_TUNNEL_TOKEN

echo "==> Instalar cloudflared (EnvironmentFile + pct push — sem token em ps)"
cloudflared_install_from_envfile "${NEW_VMID}" "$ENV_TMP" "cloudflared tunnel aglsrv5e (FGSRV7)"

echo "==> Estado do serviço (não activar cutover até ingress actualizado)"
pct exec "${NEW_VMID}" -- systemctl --no-pager --full status cloudflared || true

echo
echo "Concluído CT575 cloudflared6 @ ${NEW_IP}"
echo "Próximo: Zero Trust → túnel aglsrv5e (863fd93d-…) → ingress para n8n7/fg-apis;"
echo "         parar cloudflared Docker no FGSRV6; validar 4 conn CF antes de DNS público."

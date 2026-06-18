#!/usr/bin/env bash
# Clona CT570 cloudflared7 (antes CT170) para CT571 cloudflared7b (antes CT171)
# e reinstala o cloudflared com token Zero Trust (túnel gerido na consola).
#
# Motivo: evitar colisão de IP (.170) e credenciais do túnel antigo no clone.
# Clone --full com CT origem a correr: tenta snapshot; se o storage não suportar (ex.: dir), para a fonte o tempo do clone e volta a arrancar.
#
# Uso no host Proxmox FGSRV7 (root):
#   export CF_TUNNEL_TOKEN='(token de "cloudflared service install" — não commitar)'
#   bash /caminho/agl-hostman/scripts/maint/fgsrv07/provision-cloudflared7b-from-170.sh
#
# Variáveis opcionais:
#   SOURCE_VMID=570 NEW_VMID=571 NEW_HOSTNAME=cloudflared7b
#   NEW_IP=192.168.70.171 GATEWAY=192.168.70.1 BRIDGE=vmbr70
#   EXPECT_HOSTNAME=fgsrv7   # se definido, hostname -s tem de coincidir (segurança)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib-cloudflared-envfile-install.sh
source "${SCRIPT_DIR}/lib-cloudflared-envfile-install.sh"

SOURCE_VMID="${SOURCE_VMID:-570}"
NEW_VMID="${NEW_VMID:-571}"
NEW_HOSTNAME="${NEW_HOSTNAME:-cloudflared7b}"
NEW_IP="${NEW_IP:-192.168.70.171}"
GATEWAY="${GATEWAY:-192.168.70.1}"
BRIDGE="${BRIDGE:-vmbr70}"

if [[ -z "${CF_TUNNEL_TOKEN:-}" ]]; then
    echo 'Erro: defina CF_TUNNEL_TOKEN (token JWT do instalador do túnel na Cloudflare).' >&2
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
        echo "==> Snapshot indisponível neste storage: parar CT ${SOURCE_VMID} para clone --full (interrupção breve do túnel original)."
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

echo "==> Parar serviço cloudflared herdado do clone"
pct exec "${NEW_VMID}" -- systemctl stop cloudflared 2>/dev/null || true
pct exec "${NEW_VMID}" -- systemctl disable cloudflared 2>/dev/null || true

echo "==> Desinstalar unidade systemd cloudflared herdada (necessário antes de service install)"
if ! pct exec "${NEW_VMID}" -- cloudflared service uninstall 2>/dev/null; then
    echo "==> uninstall não concluiu (ex.: timer ausente): remover unidades manualmente"
    pct exec "${NEW_VMID}" -- bash -c 'systemctl stop cloudflared 2>/dev/null; systemctl disable cloudflared 2>/dev/null; rm -f /etc/systemd/system/cloudflared.service /etc/systemd/system/cloudflared-update.service /etc/systemd/system/cloudflared-update.timer; systemctl daemon-reload'
fi

echo "==> Remover credenciais/config do túnel antigo"
pct exec "${NEW_VMID}" -- bash -c 'rm -f /etc/cloudflared/*.json /etc/cloudflared/config.yml /etc/default/cloudflared 2>/dev/null; rm -rf /etc/systemd/system/cloudflared.service.d 2>/dev/null; systemctl daemon-reload 2>/dev/null || true'

ENV_TMP="$(mktemp)"
trap 'rm -f "$ENV_TMP"' EXIT
printf 'TUNNEL_TOKEN=%s\n' "${CF_TUNNEL_TOKEN}" >"$ENV_TMP"
chmod 600 "$ENV_TMP"
unset CF_TUNNEL_TOKEN

echo "==> Instalar cloudflared (EnvironmentFile + pct push — sem token em ps)"
cloudflared_install_from_envfile "${NEW_VMID}" "$ENV_TMP" "cloudflared tunnel (cloudflared7b)"

echo "==> Estado do serviço"
pct exec "${NEW_VMID}" -- systemctl --no-pager --full status cloudflared || true

echo
echo "Concluído. Verificar na Cloudflare Zero Trust que o connector aparece online."
echo "LAN do novo CT: ${NEW_IP} (ajustar rotas publicadas e DNS conforme necessário)."

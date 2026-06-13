#!/usr/bin/env bash
# Configura eth0 estático (192.168.15.0/24) + eth1 vmbr1 (192.168.30.0/24) em CTs/VMs do AGLSRV3.
# Uso: bash scripts/proxmox/aglsrv3-dual-lan-static.sh [--check-only|--apply]
set -euo pipefail

AGLSRV3_SSH="${AGLSRV3_SSH:-root@100.123.5.81}"
GW_15="${AGLSRV3_GW_15:-192.168.15.1}"
DNS="${AGLSRV3_DNS:-192.168.15.117}"
MODE="${1:---check-only}"

# Formato CT: vmid|hostname|eth0_ip|eth0_mac|eth1_ip
CT_ROWS=(
  "304|cloudflared3a|192.168.15.104/24|BC:24:11:D7:06:39|192.168.30.104/24"
  "306|cloudflared3b|192.168.15.106/24|BC:24:11:88:2B:5D|192.168.30.106/24"
  "317|pihole3|192.168.15.117/24|BC:24:11:3C:B8:40|192.168.30.117/24"
  "318|aglsrv3-pbs|192.168.15.118/24|BC:24:11:AB:0C:5D|192.168.30.118/24"
  "338|aglfs3|192.168.15.138/24|BC:24:11:F6:88:CA|192.168.30.138/24"
)

# VM310: cloud-init; restantes com net1 já existente ou OS próprio (Windows/opnsense/TrueNAS)
VM310_NET1_IP="192.168.30.210/24"
VM305_NET1_IP="192.168.30.105/24"

run_remote() {
  ssh -o BatchMode=yes "$AGLSRV3_SSH" "$@"
}

apply_ct() {
  local vmid="$1" name="$2" ip0="$3" mac0="$4" ip1="$5"
  local net0 net1
  net0="name=eth0,bridge=vmbr0,hwaddr=${mac0},ip=${ip0},gw=${GW_15},type=veth"
  net1="name=eth1,bridge=vmbr1,ip=${ip1},type=veth"

  echo "CT${vmid} (${name}): eth0=${ip0} eth1=${ip1}"
  if [[ "$MODE" == "--apply" ]]; then
    run_remote "pct set ${vmid} -net0 '${net0}' -net1 '${net1}'"
    if run_remote "pct status ${vmid}" | grep -q running; then
      run_remote "pct reboot ${vmid}" || true
    fi
  fi
}

apply_vm310() {
  echo "VM310: net1=${VM310_NET1_IP} ipconfig1"
  if [[ "$MODE" == "--apply" ]]; then
    run_remote "qm set 310 -net1 'virtio,bridge=vmbr1' -ipconfig1 'ip=${VM310_NET1_IP}'"
    run_remote "qm cloudinit update 310 2>/dev/null || true"
    if run_remote "qm status 310" | grep -q running; then
      run_remote "qm guest exec 310 -- ip -4 addr add ${VM310_NET1_IP} dev eth1 2>/dev/null || true"
    fi
  fi
}

apply_vm305() {
  echo "VM305: add net1 bridge=vmbr1 (IP no guest macOS)"
  if [[ "$MODE" == "--apply" ]]; then
    if ! run_remote "qm config 305" | grep -q '^net1:'; then
      run_remote "qm set 305 -net1 'virtio,bridge=vmbr1'"
    else
      echo "  VM305 net1 já existe — skip"
    fi
  fi
}

echo "=== AGLSRV3 dual LAN (${MODE}) host=${AGLSRV3_SSH} ==="
echo "vmbr0: 192.168.15.0/24 gw=${GW_15}"
echo "vmbr1: 192.168.30.0/24 (OVS, sem gateway nos CTs)"
echo

for row in "${CT_ROWS[@]}"; do
  IFS='|' read -r vmid name ip0 mac0 ip1 <<< "$row"
  apply_ct "$vmid" "$name" "$ip0" "$mac0" "$ip1"
done

apply_vm310
apply_vm305

echo
echo "VMs 301/302/303/308: net1 vmbr1 já presente — IP 192.168.30.x configurado no SO guest."
if [[ "$MODE" == "--check-only" ]]; then
  echo
  echo "Dry-run. Aplicar: $0 --apply"
fi

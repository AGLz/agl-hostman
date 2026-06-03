# AGLSRV3 — Cloudflared HA (CT104 + CT106)

Dois contentores no **aglsrv3** correm **cloudflared** em paralelo no mesmo túnel Cloudflare. Quando um CT está parado para **vzdump** ou manutenção, o outro conector mantém **man3.aglz.io** (e regras associadas) disponível.

| VMID | Hostname | Rede | Papel |
|------|----------|------|--------|
| **106** | cloudflared3 | DHCP `vmbr0` | Conector principal (migrado 2025-11-19) |
| **104** | cloudflared | DHCP `vmbr0` (MAC `BC:24:11:5D:44:DD`) | Conector secundário / failover backup |

**Não desactivar** um dos túneis salvo manutenção planeada nos dois.

---

## Incidente CT104 — arranque falhava (2026-06-03)

**Sintoma:** `startup for container '104' failed` em cada boot; lock `mounted` após `pct mount` abandonado.

**Causa:** `chattr +i` em `/etc/resolv.conf` dentro do rootfs — o hook Proxmox `PVE::LXC::Setup::pre_start_hook` não consegue actualizar DNS:

```text
close (rename) atomic file '/etc/resolv.conf' failed: Operation not permitted
```

**Correcção:**

```bash
pct mount 104
chattr -i /var/lib/lxc/104/rootfs/etc/resolv.conf
pct unmount 104
```

**Rede legada:** CT104 tinha `192.168.0.104/24` + gw `192.168.0.1` enquanto o site AGLFG usa `192.168.15.0/24`. Passar a **DHCP** em `vmbr0` (como CT106).

---

## Script de configuração

No host (ou `ssh root@100.123.5.81`):

```bash
cd /path/to/agl-hostman   # ou copiar script
bash scripts/proxmox/pct-cloudflared-dual-tunnel-aglsrv3.sh
bash scripts/proxmox/pct-cloudflared-dual-tunnel-aglsrv3.sh --check-only
```

---

## Verificação manual

```bash
pct list | grep -E '104|106'
pct exec 106 -- systemctl is-active cloudflared
pct exec 104 -- systemctl is-active cloudflared
pct exec 104 -- ip -4 addr show eth0
pct exec 106 -- ip -4 addr show eth0
```

Ambos devem reportar `active` e IP em `192.168.15.0/24`.

---

## Backup / vzdump

- Incluir **106** e **104** em janelas de backup escalonadas se possível, ou aceitar breve overlap com um conector activo.
- Após restore de um CT: repetir `chattr -i` em `resolv.conf` se o clone tiver flag imutável; confirmar `cloudflared` enabled.

---

## Referências

- Host: [`HOSTS.md`](HOSTS.md) — secção AGLSRV3
- CT117 Pi-hole local: DNS host `192.168.15.102`
- Padrão semelhante: [`docs/ct200-gpu-setup-summary.md`](ct200-gpu-setup-summary.md) (resolv.conf imutável)

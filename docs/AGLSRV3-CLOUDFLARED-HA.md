# AGLSRV3 — Cloudflared HA (CT304 + CT306)

Dois contentores no **aglsrv3** correm **cloudflared** em paralelo no mesmo túnel Cloudflare. Quando um CT está parado para **vzdump** ou manutenção, o outro conector mantém **man3.aglz.io** (e regras associadas) disponível.

| VMID    | Hostname      | Rede                       | Papel                                 |
| ------- | ------------- | -------------------------- | ------------------------------------- |
| **306** | cloudflared3b | estático `vmbr0` + `vmbr1` | Conector principal                    |
| **304** | cloudflared3a | estático `vmbr0` + `vmbr1` | Conector secundário / failover backup |

**Não desactivar** um dos túneis salvo manutenção planeada nos dois.

---

## IPs (2026-06)

| VMID              | eth0 (192.168.15.x) | eth1 (192.168.30.x) |
| ----------------- | ------------------- | ------------------- |
| 304 cloudflared3a | .104                | .104                |
| 306 cloudflared3b | .106                | .106                |

Script: `scripts/proxmox/aglsrv3-dual-lan-static.sh`

---

## Incidente CT104 — arranque falhava (2026-06-03)

**Sintoma:** `startup for container '104' failed` em cada boot; lock `mounted` após `pct mount` abandonado.

**Causa:** `chattr +i` em `/etc/resolv.conf` dentro do rootfs — o hook Proxmox `PVE::LXC::Setup::pre_start_hook` não consegue actualizar DNS:

```text
close (rename) atomic file '/etc/resolv.conf' failed: Operation not permitted
```

**Correcção:**

```bash
pct mount 304
chattr -i /var/lib/lxc/304/rootfs/etc/resolv.conf
pct unmount 304
```

**Rede legada:** CT104 tinha `192.168.0.104/24` + gw `192.168.0.1` enquanto o site AGLFG usa `192.168.15.0/24`. Passar a **IP estático** em `vmbr0` (como CT306).

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
pct list | grep -E '304|306'
pct exec 306 -- systemctl is-active cloudflared
pct exec 304 -- systemctl is-active cloudflared
pct exec 304 -- ip -4 -br addr show eth0 eth1
pct exec 306 -- ip -4 -br addr show eth0 eth1
```

Ambos devem reportar `active` e IPs em `192.168.15.0/24` e `192.168.30.0/24`.

---

## Backup / vzdump

- Incluir **306** e **304** em janelas de backup escalonadas se possível, ou aceitar breve overlap com um conector activo.
- Após restore de um CT: repetir `chattr -i` em `resolv.conf` se o clone tiver flag imutável; confirmar `cloudflared` enabled.

---

## Monitorização e alertas

Checks automáticos desde **agldv03** (CT179), a cada **5 min**:

```bash
# Instalar cron + env Telegram (uma vez, no agldv03)
sudo bash scripts/monitoring/install-aglsrv3-monitor-cron.sh
sudo nano /etc/agl-hostman/monitor.env   # ou deixar vazio: install sincroniza de /root/.zshrc (TELEGRAM_BOT_TOKEN)

# Manual
bash scripts/monitoring/aglsrv3-health-check.sh
bash scripts/monitoring/aglsrv3-health-check.sh --json
```

**Verifica:** ping/SSH host · CT304/306/317/318/338 · VM310 · `man3.aglz.io` · Ollama TS · ZFS · Pi-hole DNS · `local-lvm`.

**Anti-flap:** 2 falhas consecutivas antes de Telegram; repetição mínima 30 min.

Alvos: `config/monitoring/aglsrv3-health-targets.json` · Log: `/var/log/hostman/aglsrv3-health.log`

---

## Referências

- Host: [`HOSTS.md`](HOSTS.md) — secção AGLSRV3
- CT317 Pi-hole local: DNS host `192.168.15.117`
- Padrão semelhante: [`docs/ct200-gpu-setup-summary.md`](ct200-gpu-setup-summary.md) (resolv.conf imutável)

# Incidente AGLSRV1 — WebUI Proxmox bloqueada por NFS (2026-05-25)

> **Host**: algsrv1 (AGLSRV1)  
> **Tailscale**: `100.107.113.33` | **LAN**: `192.168.0.245`  
> **WebUI**: `https://192.168.0.245:8006`  
> **Data**: 2026-05-25  
> **Estado**: ✅ Resolvido (sem reboot do host)

---

## Resumo

Impossibilidade de login na WebUI do Proxmox no AGLSRV1, com SSH a funcionar normalmente. A página de login carregava (HTTP 200), mas o submit falhava. Inicialmente parecia erro de credenciais; após reset de password, o sintoma mudou para timeout/HTTP 500.

**Causa raiz**: workers do `pvedaemon` bloqueados em I/O NFS (`D` state) à espera do peer WireGuard **`10.6.0.20`** (CT111 / aluzdivina), inacessível. Com todos os workers presos, pedidos de autenticação não eram processados.

---

## Sintomas

| Sintoma | Detalhe |
|---------|---------|
| WebUI carrega | `GET /` → HTTP 200 |
| Login falha | `POST /api2/extjs/access/ticket` → HTTP **596** (auth failure) ou **500** (timeout) |
| SSH OK | `root@192.168.0.245` / Tailscale com mesma password |
| API estática OK | `GET /api2/json/access/domains` → 200 |
| POST login pendurado | `curl` ao endpoint `/access/ticket` timeout 20s+ |

Realm correto para login: **Linux PAM standard authentication** (`root@pam`). O realm **Proxmox VE authentication server** (`pve`) está vazio (`/etc/pve/priv/shadow.cfg` inexistente) — qualquer tentativa nesse realm falha sempre.

---

## Linha temporal

1. Utilizador reporta falha de login via IP LAN e SSH OK.
2. Verificação: `pveproxy` ativo, porta 8006 aberta, firewall desativado.
3. Logs iniciais: HTTP **596** (falha de autenticação) — suspeita de realm/password.
4. Reset de password: `pveum passwd root@pam` + `passwd root` — problema persiste.
5. Logs passam a HTTP **500** + `pveproxy: proxy detected vanished client connection`.
6. Diagnóstico: **3× `pvedaemon worker` em estado `D`** desde 20/May; stack kernel em `nfs4_proc_getattr` / `rpc_wait_bit_killable`.
7. **`10.6.0.20`**: 100% packet loss; `ls /mnt/pve/ct111-*` hang.
8. Correção aplicada; login HTTP **200** confirmado (`192.168.0.192`).

---

## Causa raiz

### NFS hard mount inacessível

Storage Proxmox configurado em `/etc/pve/storage.cfg`:

| ID | Path | Origem |
|----|------|--------|
| `ct111-shares` | `/mnt/pve/ct111-shares` | `10.6.0.20:/mnt/shares` |
| `ct111-sistema` | `/mnt/pve/ct111-sistema` | `10.6.0.20:/mnt/sistema` |

Mounts com opção **`hard`** (via `_netdev` em fstab). Quando CT111 (AGLSRV6, WG `10.6.0.20`) está offline, operações NFS bloqueiam indefinidamente.

### Workers presos

```text
pvedaemon worker  →  wchan: rpc_wait_bit_killable
                 →  nfs4_proc_getattr / __nfs_revalidate_inode
```

Também afetado: **`pvestatd`** em `D` desde 20/May (656+ horas de CPU acumulada em wait).

### Por que SSH funcionava e a WebUI não?

- SSH usa PAM directo no shell — não passa pelo pool de workers do `pvedaemon`.
- Login WebUI: `pveproxy` → IPC → **`pvedaemon worker`** → PAM (`proxmox-ve-auth`).
- Com workers bloqueados, autenticação WebUI nunca completava.

---

## Resolução aplicada (2026-05-25 ~21:25 BRT)

```bash
ssh root@100.107.113.33   # ou root@192.168.0.245

# 1. Reiniciar serviços API (liberta workers presos)
systemctl restart pvedaemon pveproxy

# 2. Desmontar NFS morto (lazy unmount — não bloqueia se o mount já hung)
umount -l /mnt/pve/ct111-shares
umount -l /mnt/pve/ct111-sistema

# 3. Reiniciar estatísticas (pvestatd também estava em D)
systemctl restart pvestatd
```

**Verificação pós-fix**:

```bash
# Workers saudáveis (estado S, não D)
ps aux | grep 'pvedaemon worker'

# Login API responde rápido (401 com password errada = OK)
curl -sk --max-time 8 -d 'username=root@pam&password=wrong' \
  https://127.0.0.1:8006/api2/json/access/ticket

# Última linha do access log deve ser 401 ou 200, não 500
tail -3 /var/log/pveproxy/access.log
```

---

## Runbook — WebUI não deixa logar (SSH OK)

```bash
HOST="root@100.107.113.33"

# 1. Serviços e workers
ssh $HOST 'systemctl is-active pveproxy pvedaemon pvestatd; ps aux | awk "\$8 ~ /D/ && /pve(daemon|statd)/ {print}"'

# 2. NFS / storage hung
ssh $HOST 'ping -c 2 -W 2 10.6.0.20; timeout 3 ls /mnt/pve/ct111-shares 2>&1 | head -1'

# 3. Logs de login
ssh $HOST 'grep access/ticket /var/log/pveproxy/access.log | tail -10'

# 4. Se workers em D + NFS morto → fix rápido
ssh $HOST 'systemctl restart pvedaemon pveproxy; umount -l /mnt/pve/ct111-shares /mnt/pve/ct111-sistema 2>/dev/null; systemctl restart pvestatd'

# 5. Testar WebUI: realm Linux PAM, user root
```

---

## Ações preventivas recomendadas

1. **CT111 / 10.6.0.20**: garantir CT111 online no AGLSRV6 ou remover storage `ct111-*` do Proxmox enquanto estiver em manutenção.
2. **Storage offline**: considerar desactivar entradas `ct111-shares` e `ct111-sistema` em Datacenter → Storage quando o peer WG estiver down (evita re-bloqueio após remount automático).
3. **Mounts NFS**: avaliar `soft` ou timeouts mais agressivos para storages não-críticos — trade-off entre integridade (`hard`) e disponibilidade da API.
4. **MCE**: ~2800 eventos `Machine check` em 24h no host — investigar hardware (RAM/CPU) independentemente deste incidente.
5. **Não confundir códigos HTTP Proxmox**:
   - **596 / 401**: credencial ou realm errado
   - **500 + vanished client**: worker bloqueado / timeout — investigar `D` state e NFS

---

## Referências cruzadas

- [`docs/AGLSRV1-TROUBLESHOOTING.md`](AGLSRV1-TROUBLESHOOTING.md) — secção «WebUI login bloqueada»
- [`docs/aglsrv1-key-findings.md`](aglsrv1-key-findings.md) — entrada 2026-05-25
- [`docs/INFRA.md`](INFRA.md) — storage CT111 / WireGuard `10.6.0.20`
- CT111: host AGLSRV6, Tailscale `100.65.189.83`

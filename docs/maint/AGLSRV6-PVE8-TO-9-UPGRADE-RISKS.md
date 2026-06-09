# AGLSRV6 (man6) — Upgrade PVE 8.4 → 9.x: riscos e plano dentro de 8 h

> **Host:** man6 · Tailscale `100.98.108.66` · WG `10.6.0.12`  
> **Estado actual:** PVE **8.4.16** · Debian **12 (bookworm)** · **UEFI** · 14 CTs + 6 VMs  
> **Revisão:** 2026-06-03  
> **Constraint operacional:** janela máxima **8 h** — host crítico (cloudflared, NFS, PBS, agldv06)

---

## Resumo para decisão

| Cenário | Probabilidade* | Tempo típico | Cabe em 8 h? |
|---------|----------------|--------------|--------------|
| Upgrade limpo (happy path) | Alta se pré-checks OK | **2–3 h** | ✅ Sim |
| Falha GRUB / UEFI (boot) | Média em UEFI+LVM | **0,5–2 h** | ✅ Sim (ISO rescue) |
| `apt`/`dpkg` a meio do dist-upgrade | Baixa | **1–3 h** | ✅ Sim (rescue shell) |
| Host arranca mas PVE/corosync partido | Baixa | **1–4 h** | ⚠️ Depende |
| Restauro completo via PBS (todos CTs/VMs) | Muito baixa se backup OK | **4–12+ h** | ❌ Pode exceder 8 h |
| Reinstalação Proxmox + restore PBS | Último recurso | **8–24 h** | ❌ Excede janela |

\*Probabilidade **após** corrigir bloqueadores do `pve8to9` e seguir wiki oficial.

**Conclusão:** A janela de 8 h é **realista** para upgrade + validação se **não** for necessário restore massivo de PBS. O risco que estoura 8 h é **perda total de boot + restore completo** — mitigado com backup PBS verificado, ISO PVE 9 à mão, e correções pré-upgrade abaixo.

---

## Bloqueadores detectados no man6 (`pve8to9 --full`)

### 🔴 FAIL — `systemd-boot` instalado

```
FAIL: systemd-boot meta-package installed. This will cause problems on upgrades
```

**O que pode acontecer:** conflito com `grub-efi-amd64` durante upgrade; GRUB não actualizado no ESP → **máquina não arranca** após reboot.

**Acção obrigatória antes da janela:**

```bash
# No man6 — seguir wiki: https://pve.proxmox.com/wiki/Upgrade_from_8_to_9#sd-boot-warning
apt remove systemd-boot
# Confirmar que proxmox-boot-tool / grub-efi-amd64 estão correctos
proxmox-boot-tool status
```

**Tempo:** ~15 min · **Sem downtime** (só reboot posterior na janela).

---

### 🟡 WARN — storage `bb` offline + CT104

- Storage CIFS `bb` **inactive**
- CT104 (`luzdivina`, stopped) referencia `/mnt/pve/bb` inexistente

**O que pode acontecer:** warnings durante upgrade; CT104 não monta; não bloqueia o host.

**Acção:** desactivar/remover storage `bb` da config ou restabelecer CIFS; migrar ou apagar CT104 se obsoleto.

---

### 🟡 WARN — `intel-microcode` em falta

**Risco:** CPU sem microcode recente (segurança); **não** impede upgrade.

```bash
# sources: componente non-free-firmware
apt install intel-microcode
```

---

### 🟡 WARN — LVM autoactivation (local-lvm)

Informativo PVE 9; volumes existentes em `local-lvm` continuam a funcionar. Opcional:

```bash
/usr/share/pve-manager/migrations/pve-lvm-disable-autoactivation
```

---

## Riscos por fase do upgrade

### Fase A — Pré-upgrade (sem downtime, dias antes)

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Backup PBS incompleto | Restore demorado / perda dados | Backup **todos** CTs/VMs; testar restore de 1 CT pequeno |
| Disco `/` 78% cheio | `apt` falha a meio | Libertar ≥5 GB (`apt clean`, logs, kernels antigos) |
| ZFS `rpool` 93% | stress durante upgrade | Não expandir ZFS na janela; monitorizar; evitar snapshots grandes |
| PBS datastore 90% | backups falham na véspera | Limpar retenção ou expandir antes |

---

### Fase B — `apt dist-upgrade` bookworm → trixie (downtime inicia)

| O que pode correr mal | Sintoma | Recuperação | Tempo est. |
|------------------------|---------|-------------|------------|
| Pacote quebrado / conflito de dependências | `dpkg` para a meio, erros `unmet dependencies` | **Não rebootar.** `dpkg --configure -a`, `apt -f install`, consola local/SSH | 30 min – 2 h |
| Perda de rede durante upgrade | SSH cai | Consola IPMI/física ou Tailscale após reboot parcial | variável |
| Serviços PVE param | UI :8006 down | Esperado; concluir upgrade | — |

**Rollback nativo Debian/PVE 8→9:** **não existe** “downgrade” limpo. Se o sistema arrancar em trixie com PVE parcialmente instalado, ou repara-se ou restaura-se de backup.

---

### Fase C — Reboot (ponto crítico)

| O que pode correr mal | Sintoma | Recuperação | Tempo est. |
|------------------------|---------|-------------|------------|
| **GRUB/UEFI** (caso mais frequente PVE 9) | “Welcome to GRUB”, loop BIOS, `grub>` | ISO PVE 9 → Advanced → **Rescue boot**; ou boot manual kernel; depois `grub-install` + `update-grub` | **30 min – 2 h** |
| Entrada EFI errada | Boot para `BOOTx64.EFI` antigo | Escolher entrada **“proxmox”** no BIOS; `efibootmgr` | 15–45 min |
| Kernel panic / módulos ZFS | não monta rpool | Boot kernel anterior no menu GRUB; `zfs import` manual | 1–2 h |
| Initramfs corrupto | drop to initramfs shell | `update-initramfs -u -k all` desde rescue | 30–60 min |

**Pré-fix UEFI recomendado** (wiki Proxmox, **antes** do reboot pós-upgrade):

```bash
[ -d /sys/firmware/efi ] && echo "UEFI OK"
echo 'grub-efi-amd64 grub2/force_efi_extra_removable boolean true' | debconf-set-selections -v -u
apt install --reinstall grub-efi-amd64
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=proxmox --recheck
update-grub
proxmox-boot-tool status
```

**Estado actual man6:** UEFI activo; `grubx64.efi` dated **2025-09-05** — executar comandos acima **na janela**, imediatamente antes do reboot final.

---

### Fase D — Pós-boot (serviços críticos)

| Serviço | VMID | Risco pós-upgrade | Nota |
|---------|------|-------------------|------|
| cloudflared6 / 6b | 101, 114 | Túneis Cloudflare caem | Failover entre CTs; testar HTTPS man6c |
| aluzdivina NFS | 111 | clientes NFS | Arrancar CT cedo na sequência |
| man6-pbs | 113 | backups indisponíveis | lock `backup` — esperar jobs terminarem |
| wireguard hub | 121 | mesh 10.6.0.x | Crítico para outros hosts |
| agldv06 | 108 | dev parado | Menor prioridade operacional |

**Ordem sugerida de arranque:** 121 (WG) → 117 (pihole6) → 111 (NFS) → 101/114 (cloudflared) → restantes.

**Tempo arranque + smoke tests:** 30–60 min.

---

## Plano de tempo dentro de 8 h

| Minuto | Actividade |
|--------|------------|
| 0 | Comunicar início; parar CTs não críticos; confirmar último backup PBS OK |
| 0–30 | Correcções finais: remover `systemd-boot`, GRUB pre-fix, `pve8to9` sem FAIL |
| 30–120 | `apt update` + dist-upgrade para trixie + metapackage `proxmox-ve` 9.x |
| 120–150 | GRUB reinstall + `proxmox-boot-tool`; reboot |
| 150–180 | Boot; UI :8006; `pveversion`; arranque CTs críticos |
| 180–240 | Testes: cloudflared, NFS, TS, 2–3 CTs amostra |
| **240–480 reserva** | Buffer para GRUB rescue / `dpkg` repair |

Se às **4 h** o host não estiver operacional com CTs críticos, activar **plano B** (abaixo).

---

## Plano B — se exceder expectativa (dentro das 8 h)

1. **T+2h — boot parcial:** ISO rescue, corrigir GRUB (não formatar discos).
2. **T+4h — PVE up mas instável:** manter CTs críticos em **man6c/man6d** temporariamente (migrar CT101 clone?) — só se cluster ainda não existir, usar backup/restore CT individual no man6c.
3. **T+6h — host irrecuperável na janela:** **abortar** upgrade na janela; restore PBS do host inteiro **fica para janela seguinte** (provavelmente >8 h). Alternativa: manter man6 em bookworm se ainda arrancar kernel 6.8 antigo (só se **não** se completou dist-upgrade trixie).

> **Importante:** Se o dist-upgrade **completou** e trixie está parcialmente instalado, voltar a PVE 8 **não é** opção rápida. Por isso o backup PBS antes da janela é mandatório.

---

## Checklist pré-janela (obrigatório)

- [ ] `pve8to9 --full` → **0 FAIL** (remover `systemd-boot`)
- [ ] Backup PBS recente de **todos** CTs/VMs (<24 h)
- [ ] Restore testado (1 CT) documentado
- [ ] ISO **Proxmox VE 9.x** em USB (rescue boot testado)
- [ ] Acesso **consola física/IPMI** confirmado
- [ ] ≥5 GB livres em `/`
- [ ] GRUB pre-fix executado **antes** do reboot final
- [ ] Comunicação utilizadores + plano failover cloudflared (CT114)
- [ ] Janela **8 h** com ponto de go/no-go às **4 h**

---

## Referências

- [Upgrade from 8 to 9](https://pve.proxmox.com/wiki/Upgrade_from_8_to_9)
- [Recover From Grub Failure](https://pve.proxmox.com/wiki/Recover_From_Grub_Failure)
- [`docs/PROXMOX-CLUSTER-PLAN.md`](../PROXMOX-CLUSTER-PLAN.md) — Fase 0B / 5
- [`docs/CLUSTER-RISKS-AND-MAINTENANCE.md`](../CLUSTER-RISKS-AND-MAINTENANCE.md)

---

## man6c + man6d (referência — Fase 0A concluída 2026-06-03)

| Nó | Antes | Depois |
|----|-------|--------|
| man6c | 9.0.11 | **9.1.19** |
| man6d | 9.1.5 | **9.1.19** |

Build idêntico: `pve-manager/9.1.19/076d7c3c108f0346`. Prontos para Fase 2 (`pvecm create`).

**Nota man6d:** repo `pve-enterprise` estava activo sem subscrição — desactivado (`Enabled: false`) para permitir `apt update`.

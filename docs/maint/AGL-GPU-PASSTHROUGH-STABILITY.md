# Estabilidade GPU passthrough — VM110 + VM310

> **Fonte de verdade (wiki):** [[AGL GPU Passthrough Estabilidade]] em `llm-wiki`. Este ficheiro é pointer operacional no repo.

> Auditoria profunda **2026-07-18**. Problema: GPU fica inacessível após algum tempo; migração CT→VM **não resolveu** (causa é reset/D3cold do dispositivo, não LXC vs QEMU).

## Veredicto rápido

| VM | Host | GPU | Estado agora | Backup? |
|----|------|-----|--------------|---------|
| **VM110** | AGLSRV1 | GTX 1650 `05:00.0` | **FAIL** — D3cold (config `0xFF`), sem `hostpci`, Ollama **100% CPU** | **Não** está nos jobs vzdump → backups **não** são a causa actual |
| **VM310** | AGLSRV3 | RX580 `02:00.0` | **OK** — guest vê AMD, Ollama **100% GPU**, `size_vram>0` | Snapshot diário 04:15 (**não** reseta PCI; fs-freeze + dirty-bitmap) |

**Conclusão backups:** o mode `snapshot` do PBS na VM310 **não** faz `qm stop` nem FLR da GPU (log: `guest-agent fs-freeze` → QMP backup → thaw). A GTX 1650 da VM110 **não** entra em nenhum job activo. A perda de GPU correlaciona com **stop/start/reboot da VM ou do host**, reset vfio falhado, e bug conhecido NVIDIA sem FLR fiável — não com o backup em si.

## Evidência (2026-07-18)

### VM110 — D3cold clássico

```text
Host lspci: 05:00.0 NVIDIA GTX 1650, Kernel driver: vfio-pci
!!! Unknown header type 7f
PCI config space: ffff ffff ... (16+ bytes)
qm config 110: SEM hostpci0 (só vga: virtio)
Guest: só Virtio 1.0 GPU; nvidia-smi FAIL
ollama ps: qwen3:4b 100% CPU, size_vram=0
```

Config PCI `0xFF` = dispositivo **morto no barramento** até reboot do host (às vezes `remove`+`rescan` no hook ajuda; muitas vezes não).

### VM310 — saudável apesar de resets históricos

```text
hostpci0: 0000:02:00.0,pcie=1,rombar=0
hostpci1: 0000:02:00.1,pcie=1,rombar=0   # áudio HDMI da mesma placa
Guest: 01:00.0 AMD RX 580; Vulkan RADV; ollama 100% GPU
dmesg host: vários "vfio-pci resetting" em 8–10 Jul (manutenção/reboot VM), não às 04:15
Backup 17 Jul: mode=snapshot, ~54s, GPU manteve-se
```

Só **1× RX580** no host (slot `03:00` inexistente).

## Porquê a migração CT→VM não resolveu

| Mito | Realidade |
|------|-----------|
| “LXC partilha mal a GPU” | Em CT o problema era bind-mount + driver host; em VM o problema é **reset PCI / D3cold** |
| “QEMU isola e estabiliza” | Isola bem **enquanto o device não morre**; GTX 1650 sem FLR continua a falhar após `qm stop` |
| “Backups matam a GPU” | Snapshot vivo **não** desliga o device; `mode=stop` sim — evitar em VMs GPU |

Referência NVIDIA/Proxmox: após stop, muitos Turing consumer cards ficam em estado inválido (`header type 7f`) até **reboot do host**.

## Estabilização (política)

### Regras operacionais

1. **Nunca** `qm stop` / `qm shutdown` da VM110 sem planear **reboot AGLSRV1** a seguir se a GPU não reenumerar.
2. Preferir **`qm reboot`** (guest reboot com device preso) a stop+start em NVIDIA.
3. Manter **`hostpci0` sempre** na config — se o start falhar por GPU ausente, **não** apagar `hostpci` para “fazer a VM arrancar”; corrigir o host.
4. Hook `vm110-gpu-hook.sh` (`post-stop` remove+rescan) — manter; se falhar → reboot host.
5. VM310: snapshot PBS OK; **não** mudar para `mode=stop` sem janela.
6. `pcie_aspm=off` (AGLSRV1) e `iommu=pt` (AGLSRV3) — manter.
7. `rombar=0`, `vga: virtio` (headless) — manter.

### Recuperação VM110 (janela)

Ver [`docs/AGL-OLLAMA-VM110.md`](../AGL-OLLAMA-VM110.md) § Janela de manutenção.

Checklist mínimo:

```bash
# Host — GPU viva?
xxd -l 16 /sys/bus/pci/devices/0000:05:00.0/config   # NÃO pode ser só ffff
# Se ffff → reboot AGLSRV1, depois:
bash scripts/aglsrv1/finish-vm110-gpu-passthrough.sh
# Guest
nvidia-smi && curl -s localhost:11434/api/ps | jq '.models[].size_vram'
```

### Backup — recomendações

| VM | Política |
|----|----------|
| VM110 | Continuar **fora** dos jobs snapshot até GPU estável; backup manual em janela (`mode=stop` aceite) |
| VM310 | Manter **snapshot** diário; monitorizar pós-backup com `check-agl-gpu-health.sh` |

## Monitorização

Script: `scripts/monitoring/check-agl-gpu-health.sh`

```bash
# Manual
bash scripts/monitoring/check-agl-gpu-health.sh

# Cron (ex. cada 15 min no agldv03 / CT com SSH aos hosts)
*/15 * * * * root bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/monitoring/check-agl-gpu-health.sh --notify >>/var/log/hostman/gpu-health.log 2>&1
```

Checks: `hostpci` · PCI D3cold · guest `lspci` · Ollama `size_vram`.

Integração existente (parcial): `scripts/infra/verify-agl-health.sh` → `vm110_gpu_check` (só nvidia-smi).

## Próximos passos

- [ ] Janela: recuperar GTX 1650 (ou instalar RX580 8GB) + repor `hostpci0`
- [ ] Instalar cron `--notify` num host estável (agldv03 / CT186)
- [ ] Após RX580 na VM110: alinhar stack amdgpu (como VM310) e aposentar NVIDIA
- [ ] Opcional: excluir explicitamente `110` de qualquer job `all: 1` futuro

## Comando de auditoria one-shot

```bash
bash scripts/monitoring/check-agl-gpu-health.sh
```

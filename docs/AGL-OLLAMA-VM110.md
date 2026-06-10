# VM110 agl-ollama — Migração Ollama (CT200 → VM)

**Data:** 2026-05-18  
**Host:** AGLSRV1 (`192.168.0.245`, Tailscale `100.107.113.33`)  
**VM:** 110 — `agl-ollama`  
**IP:** `192.168.0.200/24` (mesmo MAC/IP do CT200)  
**Modelo:** `qwen3:4b` (único, `OLLAMA_MAX_LOADED_MODELS=1`)  
**GPU:** NVIDIA GTX 1650 — **exclusiva VM110** (passthrough vfio-pci)

---

## Resumo da migração

| Item | Antes (CT200) | Depois (VM110) |
|------|---------------|----------------|
| Tipo | LXC 200 `ollama` | **QEMU VM 110** `agl-ollama` |
| RAM | 16 GB | 16 GB + **balloon 32 GB** |
| Disco | ~196 GB ZFS | **240 GB** ZFS |
| SO | Ubuntu (LXC) | **Ubuntu 24.04 LTS** (cloud image) |
| GPU | bind-mount `/dev/nvidia*` (partilhada) | **PCI passthrough** (exclusiva) |
| Ollama API | `:11434` | `:11434` (sem mudar LiteLLM LAN) |
| CT200 | `onboot 1` | **parado, `onboot 0`, GPU removida** |

---

## GPU — exclusividade no AGLSRV1

### CTs/VMs limpos (2026-05-18)

GPU removida de:

- **CTs:** 161, 174, 178, 179, 181, 185, 186, 187, **200**
- **VM:** 300 (`nobara-gaming` — `hostpci0 05:00` removido)

Backup Proxmox: `/root/gpu-migration-backup-20260518-204255/`

### Host — vfio-pci

Ficheiro: `/etc/modprobe.d/vfio-gpu.conf` (fonte: `scripts/aglsrv1/vfio-gpu.conf`)

```ini
options vfio-pci ids=10de:1f82,10de:10fa disable_vga=1
softdep nvidia pre: vfio-pci
softdep nvidia_drm pre: vfio-pci
softdep nvidia_modeset pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
```

**Nota:** não usar `disable_idle_d3=1` — piora reset da GTX 1650 em PVE 9 / QEMU 10.

**Importante:** não manter `/etc/modprobe.d/blacklist-vfio-gpu.conf` com `blacklist vfio-pci` — impede passthrough.

**Preparação (antes do reboot):** `bash scripts/aglsrv1/prepare-gpu-passthrough-host.sh`  
Referência: [Proxmox forum — GPU passthrough NVIDIA 2025](https://forum.proxmox.com/threads/2025-proxmox-pcie-gpu-passthrough-with-nvidia.169543/)

**Reboot do AGLSRV1** obrigatório se a GPU ficou em D3cold ou `05:00.0` não aparece em `lspci`.

Verificar após reboot:

```bash
lspci -k -s 05:00.0   # Kernel driver in use: vfio-pci
grep -rE 'hostpci.*05:00|lxc\.mount.*nvidia' /etc/pve/lxc/*.conf /etc/pve/qemu-server/*.conf | grep -v 110.conf
# (sem resultados activos excepto VM110)
```

---

## VM110 — especificação

```text
VMID:     110
Nome:     agl-ollama
CPU:      8 cores, host (hidden=1 após tentativa GPU)
RAM:      16384 MB, balloon 32768
Disco:    local-zfs:240G
Rede:     vmbr0, MAC BC:24:11:BA:72:22, IP 192.168.0.200
BIOS:     OVMF (UEFI)
SO:       Ubuntu 24.04 Noble (cloud-init)
User:     agladmin (SSH keys do host Proxmox)
GPU:      hostpci0 05:00 (após finish-vm110-gpu-passthrough.sh)
NUMA:     0 — GPU em `05:00.0` = **socket 0** (`numa_node` 0), não socket 1
          affinity: 0-13,28-41
          numa0: cpus=0-7,hostnodes=0,memory=16384,policy=bind
```

**NUMA (2026-06-06):** ao contrário da VM104 (NVMe em socket 1), a GTX 1650 está no **primeiro CPU**. Pin em `numa: 0` alinha vCPUs/RAM à GPU e evita tráfego QPI cross-socket. **Não** usar `numa: 1` nesta VM.

**Recuperação GPU:** após `qm stop`/`qm start` falhado, a GTX pode ficar em D3cold e desaparecer de `lspci` — **reboot do AGLSRV1** + `qm start 110`. Hook: `local:snippets/vm110-gpu-hook.sh` (`post-stop` reenumera).

---

## Ollama — override systemd

Ficheiro na VM: `/etc/systemd/system/ollama.service.d/override.conf`  
Fonte repo: `scripts/aglsrv1/vm110-ollama-override.conf`

```ini
OLLAMA_MAX_LOADED_MODELS=1
OLLAMA_NUM_PARALLEL=1
OLLAMA_KEEP_ALIVE=30m
OLLAMA_NUM_GPU=999
OLLAMA_GPU_MEMORY_FRACTION=0.95
```

---

## Scripts (repo)

| Script | Onde correr | Função |
|--------|-------------|--------|
| `strip-gpu-from-aglsrv1.sh` | AGLSRV1 root | Remove GPU de CTs/VMs; para CT200 |
| `enable-vfio-gpu-host.sh` | AGLSRV1 root | vfio-gpu.conf + bind vfio |
| `setup-vm110-agl-ollama.sh` | AGLSRV1 root | Cria VM110 + cloud-init |
| `prepare-gpu-passthrough-host.sh` | AGLSRV1 root | vfio + initramfs **antes** do reboot |
| `finish-vm110-gpu-passthrough.sh` | AGLSRV1 root | Reanexa GPU **após** reboot |
| `install-vm110-ollama-guest.sh` | VM110 root | NVIDIA + Ollama + pull qwen3:4b |

Cópia rápida para o host:

```bash
scp scripts/aglsrv1/{strip-gpu,enable-vfio,setup-vm110,finish-vm110,install-vm110}*.sh \
  scripts/aglsrv1/vm110-ollama-override.conf \
  AGLSRV1:/root/agl-ollama-migrate/
```

---

## Estado actual (2026-05-18 — verificação remota)

- **VM110:** **stopped** — `qm start 110` falha: `no PCI device found for 0000:05:00.0`
- **GPU host:** **ausente** em `lspci` (slot `02.3-[05]` vazio) — **D3cold**; rescan/bridge reset **não recuperaram**
- **Acção necessária:** **reboot AGLSRV1** → `lspci -k -s 05:00.0` (vfio-pci) → `qm start 110` ou `finish-vm110-gpu-passthrough.sh`
- **Config Proxmox OK:** `onboot: 1`, `hookscript`, `hostpci0 05:00.0`, `numa0` socket 0
- **Ollama API:** offline (`192.168.0.200:11434`, TS `100.116.57.111`)

### Estado operacional (2026-06-05 — última vez GPU activa)

- **VM110:** running, Ubuntu 24.04, GPU passthrough **activo**
- **GPU:** GTX 1650 em `01:00.0` (guest), driver NVIDIA 580, `nvidia-smi` OK
- **Secure Boot (VM):** desactivado — `efidisk0` com `pre-enrolled-keys=0`
- **Ollama:** `http://192.168.0.200:11434`, `qwen3:4b` — **~80% GPU** (~3.2 GB VRAM)
- **LiteLLM:** `agl-primary` → `192.168.0.200:11434` **sem alteração** de IP
- **CT200:** stopped, `onboot 0`, GPU removida — **descontinuado**
- **Kernel host:** `6.8.12-1-pve` (pin); `pcie_aspm=off` em `/etc/kernel/cmdline`
- **Passthrough:** `hostpci0: 0000:05:00.0,pcie=1,rombar=0` + `vga: virtio` (headless)
- **Hook:** `/var/lib/vz/snippets/vm110-gpu-hook.sh` — reenumera GPU no `post-stop` (evita `pci_irq_handler` no 2.º `qm start`)

### Config GPU validada

```text
hostpci0: 0000:05:00.0,pcie=1,rombar=0   # só VGA; áudio HDMI no host
vga: virtio
efidisk0: ...,pre-enrolled-keys=0         # Secure Boot OFF
hookscript: local:snippets/vm110-gpu-hook.sh
```

### Reaplicar passthrough (se necessário)

```bash
# AGLSRV1 — GPU em vfio-pci
lspci -k -s 05:00.0 | grep vfio-pci

bash /root/agl-ollama-migrate/finish-vm110-gpu-passthrough.sh

# Verificar na guest
ssh agladmin@192.168.0.200
nvidia-smi
HOME=/root ollama ps    # PROCESSOR: X%/Y% CPU/GPU
```

**Após `qm stop`/`start`:** o hook reenumera a GPU; se falhar, reboot do host antes de `qm start`.

### Próximo passo GPU (legado — concluído 2026-06-05)

<details>
<summary>Passos históricos de troubleshooting</summary>

```bash
# No AGLSRV1 — ANTES do reboot
bash /root/agl-ollama-migrate/prepare-gpu-passthrough-host.sh
reboot

lspci -k -s 05:00.0 | grep vfio-pci
bash /root/agl-ollama-migrate/finish-vm110-gpu-passthrough.sh

# Secure Boot: recriar efidisk com pre-enrolled-keys=0 se modprobe nvidia falhar
ssh agladmin@192.168.0.200
nvidia-smi && ollama ps
```

</details>

**BIOS host:** VT-d activo, Secure Boot desactivado (recomendado).  
**VM110:** OVMF, q35, CPU host, passthrough headless, ballooning 16 GB + 32 GB.

### ⚠️ NÃO fazer downgrade de kernel

O pool ZFS `rpool` usa features (ex. `vdev_zaps_v2`) incompatíveis com kernels antigos (ex. `6.2.16-5-pve`).  
**Nunca** executar `proxmox-boot-tool kernel pin 6.2.16-5-pve` — o host falha ao importar `rpool` com *unsupported feature*.

Manter kernel **≥ 6.11** (actual recomendado: `6.14.8-2-pve`). Para GPU passthrough usar hookscript + `rombar=0`, **não** downgrade de kernel.

**Recuperação se o pin 6.2.16 ficou activo:** no menu GRUB escolher `6.14.8-2-pve` ou `6.11.0-2-pve`, depois:

```bash
proxmox-boot-tool kernel pin 6.14.8-2-pve
proxmox-boot-tool refresh
```

---

## CT200 — descontinuação

- Não apagar imediatamente — manter parado 1–2 semanas como fallback
- Modelos antigos em CT200 ZFS: `pct mount 200` ou backup em `/var/lib/lxc/200`
- Quando VM110 GPU estiver validado:

```bash
pct stop 200
pct set 200 -onboot 0
# opcional: pct destroy 200 (após backup)
```

---

## Verificação LiteLLM

```bash
# De agldv03 ou host com LiteLLM
bash scripts/litellm/test-chat-model.sh agl-primary
curl -sf http://192.168.0.200:11434/api/tags

# Benchmark comparativo providers (latência, capacidade, limites)
python3 scripts/litellm/benchmark-provider-comparison.py
# Resultado: docs/LITELLM-PROVIDER-BENCHMARK.md
```

---

## Referências

- `docs/ct200-gpu-setup-summary.md` — histórico LXC (legado)
- `docs/ct200-model-performance.md` — benchmarks
- `config/litellm/config.yaml` — `agl-primary` / `ollama-qwen3-4b`

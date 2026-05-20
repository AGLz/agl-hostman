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
options vfio-pci ids=10de:1f82,10de:10fa disable_vga=1 disable_idle_d3=1
softdep nvidia pre: vfio-pci
softdep nvidia_drm pre: vfio-pci
softdep nvidia_modeset pre: vfio-pci
softdep snd_hda_intel pre: vfio-pci
```

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
```

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

## Estado actual (2026-05-18)

- **VM110:** running, Ubuntu 24.04, `cloud-init done`
- **Ollama:** activo em `http://192.168.0.200:11434`, modelo `qwen3:4b` instalado
- **LiteLLM:** `agl-primary` → `192.168.0.200:11434` **sem alteração** de IP
- **CT200:** stopped, `onboot 0`, GPU removida — **descontinuado**
- **GPU passthrough:** após reboot com vfio OK, arranque com `hostpci` falhou com `vfio: Unable to power on device, stuck in D3` (2026-05-20). Mitigação: `disable_idle_d3=1` em `vfio-gpu.conf` + `update-initramfs` e novo reboot antes de repetir `finish-vm110-gpu-passthrough.sh`. VM110 em **CPU** com `vga: virtio` até passthrough estável.

### Próximo passo GPU (operador)

```bash
# No AGLSRV1 — ANTES do reboot
bash /root/agl-ollama-migrate/prepare-gpu-passthrough-host.sh
# Verificar: não existe blacklist vfio-pci; disable_vga=1 em vfio-gpu.conf
reboot

# Após reboot — ambas as funções em vfio-pci
lspci -nn | grep -i nvidia   # 05:00.0 VGA + 05:00.1 Audio
lspci -k -s 05:00.0 | grep vfio-pci
lspci -k -s 05:00.1 | grep vfio-pci
bash /root/agl-ollama-migrate/finish-vm110-gpu-passthrough.sh

# Na VM (após passthrough OK): desactivar Secure Boot na UEFI (consola Proxmox → ESC → Device Manager → Secure Boot → Disabled). Sem isto: `Key was rejected by service` no modprobe nvidia.
ssh agladmin@192.168.0.200
sudo ubuntu-drivers install --gpgpu
# ou: sudo apt install nvidia-driver-570-open
sudo reboot

# Verificar VRAM
nvidia-smi
ollama run qwen3:4b "teste gpu"
ollama ps   # size_vram > 0, layers na GPU
```

**BIOS host:** VT-d activo, Secure Boot desactivado (recomendado no tutorial).  
**VM110:** OVMF, q35, CPU host, `hostpci0 05:00,pcie=1,x-vga=1`, `vga none`, **ballooning activo** (16 GB + balloon 32 GB — não desactivar para respeitar limites do host). Se o arranque com GPU falhar, ver log QEMU antes de considerar `balloon 0` só como teste.

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
```

---

## Referências

- `docs/ct200-gpu-setup-summary.md` — histórico LXC (legado)
- `docs/ct200-model-performance.md` — benchmarks
- `config/litellm/config.yaml` — `agl-primary` / `ollama-qwen3-4b`

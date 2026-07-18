# VM110 agl-ollama — Migração Ollama (CT200 → VM)

> **⚠️ Legado / offline (2026-06-11).** Ollama primário canónico está na **VM310** (AGLSRV3) — **suspenso até reboot AGLSRV3 (segunda).**  
> **Janela 23h (2026-05-18):** **Plan C** — `gemma4-qat` text-only (GGUF QAT HF) na **VM110** GTX 1650 4 GB. Ver secção [Plan C](#plan-c--gemma-4-qat-gtx-1650-4-gb) abaixo.

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
CPU:      16 cores, host (hidden=1), NUMA0 socket 0
RAM:      16384 MB, balloon 32768
Disco:    local-zfs:240G
Rede:     vmbr0, MAC BC:24:11:BA:72:22, IP 192.168.0.200
BIOS:     OVMF (UEFI)
SO:       Ubuntu 24.04 Noble (cloud-init)
User:     agladmin (SSH keys do host Proxmox)
GPU:      hostpci0 05:00 (após finish-vm110-gpu-passthrough.sh)
NUMA:     0 — GPU em `05:00.0` = **socket 0** (`numa_node` 0), não socket 1
          affinity: 0-15,28-43
          numa0: cpus=0-15,hostnodes=0,memory=16384,policy=bind
```

**CPU (2026-07-10):** revertido de 48 → **16 vCPUs** (`tune-vm110-cpu-cores.sh`) — escalar para 48 cores não melhorou inferência; pin NUMA0 junto à GPU.

**GPU futura:** **RX580 8GB** na janela de manutenção (substitui GTX 1650); até lá GTX 1650 + Plan C.

**NUMA (2026-06-06):** ao contrário da VM104 (NVMe em socket 1), a GTX 1650 está no **primeiro CPU**. Pin em `numa: 0` alinha vCPUs/RAM à GPU e evita tráfego QPI cross-socket. **Não** usar `numa: 1` nesta VM.

**Recuperação GPU:** após `qm stop`/`qm start` falhado, a GTX pode ficar em D3cold e desaparecer de `lspci` — **reboot do AGLSRV1** + `qm start 110`. Hook: `local:snippets/vm110-gpu-hook.sh` (`post-stop` reenumera).

---

## Janela de manutenção GPU (2026-07-10)

> **Wiki (fonte de verdade):** [[AGL GPU Passthrough Estabilidade]] · pointer repo: [`docs/maint/AGL-GPU-PASSTHROUGH-STABILITY.md`](maint/AGL-GPU-PASSTHROUGH-STABILITY.md). Monitor: `scripts/monitoring/check-agl-gpu-health.sh`.

> **Estado verificado 2026-07-10 ~00:07 UTC-3** — usar este bloco como runbook na janela.

### Snapshot actual (antes da janela)

| Item | Estado |
|------|--------|
| VM110 | **running**, 16 vCPUs, balloon 32 GB |
| `hostpci0` | **Ausente** — GPU não passada à VM |
| Host `lspci` `05:00` | **Vazio** (GTX 1650 em D3cold / não enumerada) |
| Guest GPU | Só **Virtio** — `nvidia-smi` falha |
| Ollama | **active**, `qwen3:4b` carregado, **`100% CPU`** (`size_vram: 0`) |
| API | `http://100.74.118.51:11434` (TS), `192.168.0.200:11434` (LAN) |
| LiteLLM alias | `agl-primary-vm110` (failover; primário = VM310) |

**Conclusão:** o modelo **está a correr**, mas **sem GPU**. Não confundir API OK com inferência acelerada.

### Pré-requisitos da janela

- [ ] Janela com **reboot do AGLSRV1** (obrigatório se `05:00` ausente em `lspci`)
- [ ] Backup Proxmox VM110 (`vzdump 110`) ou snapshot ZFS
- [ ] Scripts no host: `git pull` em `/root/agl-hostman` ou `PHASE=preflight bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh`
- [ ] Avisar consumidores: Hermes/LiteLLM failover `agl-primary-vm110` ficará offline ~15–30 min
- [ ] **Não** fazer pin de kernel &lt; 6.11 (ZFS `rpool` / `vdev_zaps_v2`)

### Cenário A — Repor GTX 1650 (hardware actual)

Ordem **estrita** (documentado após incidente D3cold + `hostpci` removido):

```bash
# === 1. Preflight (agldv03 ou workstation) ===
PHASE=preflight bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh

# === 2. AGLSRV1 (root) — enumerar GPU ===
ssh root@100.107.113.33
lspci -nn | grep -i nvidia          # deve mostrar 10de:1f82 em 05:00.0
# Se vazio:
bash /root/agl-hostman/scripts/aglsrv1/prepare-gpu-passthrough-host.sh
reboot
# Após boot:
lspci -k -s 05:00.0 | grep vfio-pci   # Kernel driver: vfio-pci

# === 3. Passthrough VM110 ===
bash /root/agl-hostman/scripts/aglsrv1/finish-vm110-gpu-passthrough.sh
# Reaplica: hostpci0 0000:05:00.0,pcie=1,rombar=0 + vga virtio

# === 4. Guest — driver NVIDIA ===
ssh root@100.74.118.51
nvidia-smi                            # GTX 1650 visível
systemctl restart ollama
HOME=/root ollama ps                  # PROCESSOR: ~80–100% GPU (não 100% CPU)
curl -s http://127.0.0.1:11434/api/ps | jq '.models[].size_vram'  # > 0

# === 5. Smoke LiteLLM (CT186) ===
ssh root@100.125.249.8
source /opt/agl-litellm/.env
bash /opt/agl-litellm/scripts/test-ollama-litellm-content.sh agl-primary-vm110
```

**Critérios de aceite (GTX 1650):**

| Check | Esperado |
|-------|----------|
| `qm config 110` | `hostpci0: 0000:05:00.0,pcie=1,rombar=0` |
| `nvidia-smi` | Driver OK, ~4 GB VRAM |
| `ollama ps` | `qwen3:4b` com uso **GPU** |
| `size_vram` em `/api/ps` | **&gt; 0** |
| Inferência curta (`num_predict=16`) | &lt; 5 s (ordem de grandeza GPU) |

### Cenário B — Upgrade RX580 8GB (substituir GTX 1650)

> Aguardar hardware + mesma janela. **Stack diferente** (AMD amdgpu, não NVIDIA).

1. **Físico:** remover GTX 1650, instalar RX580 8GB no slot `05:00` (confirmar `lspci` no host após reboot).
2. **Host vfio:** actualizar `/etc/modprobe.d/vfio-gpu.conf` — trocar IDs NVIDIA (`10de:1f82,10de:10fa`) pelos IDs AMD da RX580 (ex. `1002:67df` — **confirmar com `lspci -nn` no host**).
3. **Proxmox mapping:** seguir padrão VM310 — `hostpci0 mapping=RX580,pcie=1,rombar=0` se resource mappings existirem no AGLSRV1; senão BDF directo.
4. **Guest:** remover stack NVIDIA; instalar `linux-modules-extra`, `amdgpu`, drivers Vulkan/Mesa (ver `scripts/aglsrv3/install-vm310-ollama-guest.sh` como referência).
5. **Ollama:** override em `vm110-ollama-override.conf` — `OLLAMA_VULKAN=1`, `OLLAMA_LLM_LIBRARY` amdgpu; modelos: `qwen3:4b` / `gemma4-qat` (Plan C).
6. **Referência cruzada:** [`AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md), `scripts/aglsrv3/restore-vm310-from-vm110.sh` (histórico migração inversa).

**Nota:** após RX580, `nvidia-smi` deixa de aplicar — validar com `ollama ps` + `size_vram` + benchmark `scripts/aglsrv1/benchmark-ollama-gpu.sh`.

### Rollback

```bash
# LiteLLM — voltar a não depender de VM110 local
bash scripts/litellm/restore-litellm-groq-failover.sh

# VM110 sem GPU — manter Ollama CPU (degradado)
qm set 110 --delete hostpci0
qm reboot 110
```

### Comandos rápidos de diagnóstico

```bash
# Host
ssh root@100.107.113.33 'lspci -nn | grep -iE "nvidia|amd|vga"; qm config 110 | grep -E hostpci|vga|cores'

# Guest
ssh root@100.74.118.51 'lspci | grep -iE "vga|3d|display"; nvidia-smi 2>&1 | head -2; curl -s localhost:11434/api/ps | jq'
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
| `setup-vm110-agl-ollama.sh` | AGLSRV1 root | Cria VM110 + cloud-init (16 cores default) |
| `tune-vm110-cpu-cores.sh` | AGLSRV1 root | Ajusta vCPUs/NUMA (default 16; evita oversubscribe) |
| `prepare-gpu-passthrough-host.sh` | AGLSRV1 root | vfio + initramfs **antes** do reboot |
| `finish-vm110-gpu-passthrough.sh` | AGLSRV1 root | Reanexa GPU **após** reboot |
| `install-vm110-ollama-guest.sh` | VM110 root | NVIDIA + Ollama + pull qwen3:4b |
| `install-vm110-gemma4-qat-plan-c.sh` | VM110 root | **Plan C:** HF GGUF QAT + `ollama create gemma4-qat` |
| `verify-vm110-gemma4-qat.sh` | VM110 / remoto | Smoke gemma4-qat + qwen3:4b + VRAM |
| `runbook-vm110-maintenance-23h.sh` | agldv03 | Orquestração preflight / host / guest / litellm |

Cópia rápida para o host:

```bash
scp scripts/aglsrv1/{strip-gpu,enable-vfio,setup-vm110,finish-vm110,install-vm110}*.sh \
  scripts/aglsrv1/vm110-ollama-override.conf \
  AGLSRV1:/root/agl-ollama-migrate/
```

---

## Estado actual (histórico)

> **Runbook vigente:** secção [Janela de manutenção GPU (2026-07-10)](#janela-de-manutenção-gpu-2026-07-10).

### 2026-07-10 — GPU inactiva, Ollama em CPU

- **VM110:** running, 16 cores, **sem `hostpci0`**
- **GTX 1650:** ausente no host e na guest
- **Ollama:** `qwen3:4b` em **100% CPU** — API online, inferência lenta

### 2026-05-18 — verificação remota (legado)

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
- **LiteLLM:** na altura `agl-primary` → `192.168.0.200:11434` (substituído por **VM310** — ver [`AGL-OLLAMA-VM310.md`](AGL-OLLAMA-VM310.md))
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

## Plan C — Gemma 4 QAT (GTX 1650 4 GB)

**Objectivo:** `agl-primary` = `gemma4-qat` local na VM110 durante indisponibilidade da VM310 (AGLSRV3).

| Item | Valor |
|------|--------|
| Modelo | `google/gemma-4-E2B-it-qat-q4_0-gguf` → **só** `gemma-4-E2B_q4_0-it.gguf` (~3,35 GB) |
| **Não usar** | `gemma-4-E2B-it-mmproj.gguf` (~987 MB) nem `gemma4:e2b-it-qat` do registry Ollama (multimodal → OOM) |
| Alias Ollama | `gemma4-qat` |
| Fallback guest | `qwen3:4b` (~3,2 GB VRAM, já validado) |
| ctx | 8192 (se OOM → `OLLAMA_CONTEXT_LENGTH=4096`) |
| API | LAN `192.168.0.200:11434`, TS `100.116.57.111:11434` |

### Sequência janela ~23h

```bash
# Agora (agldv03) — preflight + sync scripts para AGLSRV1
PHASE=preflight bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh

# AGLSRV1 — se vfio não activo
bash /root/agl-hostman/scripts/aglsrv1/prepare-gpu-passthrough-host.sh
reboot

# Após boot (agldv03) — host + guest + LiteLLM
PHASE=all bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh
```

Fases individuais: `PHASE=host|guest|litellm`.

**LiteLLM (CT186):** `bash scripts/litellm/apply-litellm-vm110-plan-c.sh`  
**Rollback Groq:** `bash scripts/litellm/restore-litellm-groq-failover.sh`

### Verificação Plan C

```bash
OLLAMA_HOST=http://100.116.57.111:11434 bash scripts/aglsrv1/verify-vm110-gemma4-qat.sh
bash scripts/litellm/test-ollama-litellm-content.sh agl-primary
```

---

## Referências

- `docs/ct200-gpu-setup-summary.md` — histórico LXC (legado)
- `docs/ct200-model-performance.md` — benchmarks
- `config/litellm/config.yaml` — `agl-primary` / `ollama-qwen3-4b`

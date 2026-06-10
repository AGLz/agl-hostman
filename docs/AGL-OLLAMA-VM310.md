# VM310 agl-ollama — AGLSRV3 (RX 580)

**Data:** 2026-06-09 (actualizado pós-destroy pool)  
**Host:** AGLSRV3 (`192.168.15.247`, Tailscale `100.123.5.81`)  
**VM:** 310 — `agl-ollama`  
**LAN:** `192.168.15.210/24`  
**Modelo:** `qwen3:8b` (`OLLAMA_MAX_LOADED_MODELS=1`) — ~6.2 GB VRAM, 100% GPU na RX580  
**GPU:** AMD RX 580 2048SP — **8 GB VRAM**, passthrough exclusivo (substitui VM301 AGLHQ10 teste)

> **2026-06-09:** Discos VM310 perdidos com `zpool destroy` (migração não correu a tempo).  
> **Plano:** recriar após PVE 9 + pool novo, clonando **VM110** (AGLSRV1) como template OS/Ollama base; depois `ollama pull` + Tailscale de novo.

---

## Recriar VM310 (pós-upgrade)

| Passo | Acção |
|-------|--------|
| 1 | Concluir rebuild: PVE 9 + `aglsrv3-tb` raidz1 5×1TB |
| 2 | `STORAGE=aglsrv3-tb bash scripts/aglsrv3/restore-vm310-from-vm110.sh --full` |
| 3 | Na guest: `tailscale up` (novo IP TS) |
| 4 | `ollama pull qwen3:8b` (+ modelos do benchmark) |
| 5 | Actualizar LiteLLM (`config/litellm/config.yaml`) se IP TS mudar |

Alternativa instalação limpa (sem clone VM110): `STORAGE=aglsrv3-tb bash scripts/aglsrv3/setup-vm310-agl-ollama.sh` + `install-vm310-ollama-guest.sh`.

**Template VM110 (AGLSRV1):** VMID 110, `local-zfs`, 240G, Ollama + cloud-init `agladmin`, GPU GTX 1650 (substituir por `mapping=RX580` no restore).

---

## Resumo

| Item | Valor |
|------|--------|
| VM301 AGLHQ10 | **Parada**, `onboot 0`, GPU removida |
| Storage VM310 | **`aglsrv3-tb`** (após rebuild) ou `local-lvm` |
| RAM VM310 | 16 GB (balloon 24 GB) |
| LiteLLM | TS guest (ex. `100.86.209.11:11434`) — actualizar após novo `tailscale up` |
| Aliases | `agl-primary`, `ollama-qwen3-4b`, `openai/ollama-qwen3-4b` |

---

## GPU (AMD ROCm)

- Passthrough: `hostpci0 mapping=RX580,pcie=1,rombar=0`
- Guest: `linux-firmware` + `linux-modules-extra-$(uname -r)` + `modprobe amdgpu`
- Ollama override: `HSA_OVERRIDE_GFX_VERSION=10.3.0` (Polaris gfx803)
- Verificar: `ollama ps` → **`100% GPU`**

---

## Scripts

| Script | Onde |
|--------|------|
| `scripts/aglsrv3/restore-vm310-from-vm110.sh` | **Restore VM310 ← backup VM110** (pós-upgrade) |
| `scripts/aglsrv3/setup-vm310-agl-ollama.sh` | Cria VM310 do zero (cloud-init) |
| `scripts/aglsrv3/install-vm310-ollama-guest.sh` | Ollama + GPU na guest |
| `scripts/aglsrv3/ollama-tailscale-nat.sh` | NAT TS `:11434` → VM310 |
| `scripts/aglsrv3/vm310-ollama-override.conf` | systemd ollama |
| `scripts/aglsrv3/benchmark-ollama-models.sh` | Benchmark multi-modelo (8 GB VRAM) |

---

## Benchmark de modelos (8 GB)

Lista curada e script de comparação (latência, tokens/s, `ollama ps` GPU vs CPU):

```bash
# Na VM310 ou via Tailscale (default API: http://100.86.209.11:11434)
PULL=1 bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only

# Desde agldv03 (sem SSH)
OLLAMA_BENCH_MODELS="qwen3:8b qwen3:4b" bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only

# SSH na guest
VM310_HOST=agladmin@100.86.209.11 bash scripts/aglsrv3/benchmark-ollama-models.sh --remote --pull
```

Saída CSV: `/tmp/ollama-vm310-bench.csv`. Objetivo na RX580: **`100% GPU`** em `ollama ps`.

Modelos default no script: `qwen3:8b`, `qwen3.5:9b`, `llama3.1:8b`, `gemma2:9b`, `deepseek-r1:8b`, `qwen2.5-coder:7b`, `command-r7b`, `granite3.3:8b`. (`mistral:7b` removido — performance anómala na RX580.)

**Benchmark 2026-06-09 (Tailscale API, 8 GB VRAM):** CSV `/tmp/ollama-vm310-bench-full.csv` — primário `qwen3:8b` ~25 tok/s; rápido `qwen3:4b` ~42 tok/s; JSON `llama3.1:8b` / `qwen2.5-coder:7b` ~1s.

---

**Tailscale:** `100.86.209.11` (hostname `aglsrv3-ollama`) — LiteLLM usa esta IP directamente.

NAT legado no host (`100.123.5.81:11434`) pode ser removido; script `ollama-tailscale-nat.sh` só necessário se a VM não tiver TS próprio.

---

## VM110 (AGLSRV1)

Permanece **parada** (GTX 1650 instável). Ollama primário migrou para AGLSRV3.

Ver histórico: [`docs/AGL-OLLAMA-VM110.md`](AGL-OLLAMA-VM110.md).

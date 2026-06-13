# VM310 agl-ollama — AGLSRV3 (2× RX 580)

**Data:** 2026-06-12 (tiering agl-primary + dual-GPU)  
**Host:** AGLSRV3 (`192.168.15.247`, Tailscale `100.123.5.81`)  
**VM:** 310 — `agl-ollama`  
**LAN:** `192.168.15.210/24`  
**Primário:** `gemma4-qat` @ GPU0 `:11434` — alias LiteLLM **`agl-primary`** (~46 tok/s JSON)  
**Secundário:** `qwen3:8b` @ GPU1 `:11435` (planeado) — alias **`agl-primary-strong`** (~26 tok/s)  
**Fallback:** `qwen3:4b` @ `:11434` — alias **`ollama-qwen3-4b-fast`**  
**GPU:** 2× AMD RX 580 2048SP — passthrough `hostpci0` + `hostpci1` (`rombar=0`)

> **2026-06-12:** **AGLSRV3 travado** — host indisponível até reboot (segunda-feira). LiteLLM desviado para Groq/OpenRouter; restaurar Ollama após VM310 online.

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
| LiteLLM | TS guest `100.67.253.52:11434` (GPU0), `:11435` (GPU1 quando VBIOS OK) |
| Aliases LiteLLM | **`agl-primary`** (gemma4-qat), **`agl-primary-strong`** (qwen3:8b), **`ollama-qwen3-4b-fast`**, `ollama-gemma4-qat` (legado), `ollama-qwen3-8b`, `ollama-llama31-8b`; `ollama-gemma3-4b` → redireccionado para gemma4-qat |
| **Modelos em disco (2026-06-12)** | `gemma4-qat`, `qwen3:8b`, `qwen3:4b`, `llama3.1:8b` (4 modelos, ~15 GB) |

---

## GPU (AMD — Vulkan, 2× RX 580)

- Passthrough: `hostpci0 mapping=RX580` + `hostpci1 mapping=RX580_2`, `pcie=1,rombar=0`
- Host: `vfio-pci ids=1002:6fdf,1002:aaf0` em `/etc/modprobe.d/vfio.conf`
- Guest: `linux-modules-extra`, `linux-firmware`, `modprobe amdgpu`
- Ollama GPU0 (`scripts/aglsrv3/vm310-ollama-override.conf`): `:11434`, `GGML_VK_VISIBLE_DEVICES=0`, `MAX_LOADED_MODELS=1`
- Ollama GPU1 (`vm310-ollama-gpu1-override.conf` + `ollama-gpu1.service`): `:11435`, `GGML_VK_VISIBLE_DEVICES=1` — **só activo se** `dmesg` mostrar `Initialized amdgpu` @ `02:00.0`
- Aplicar: `bash scripts/aglsrv3/apply-vm310-ollama-optimize.sh`
- Pre-warm: `bash scripts/aglsrv3/prewarm-vm310-dual-ollama.sh` (não aquece qwen3:8b em `:11434` se GPU1 inactiva — evita eviction do primário)
- Prune: `bash scripts/aglsrv3/prune-vm310-ollama-models.sh`

### Blocker dual-residency (2026-06-12)

A 2.ª RX580 (`0000:02:00.0`) **não inicializa amdgpu** na guest (`Invalid PCI ROM header` / `error -22`). Com uma instância Ollama, carregar 2.º modelo **evicta** o 1.º. Até fix VBIOS:

| Porta | GPU | Modelo residente |
|-------|-----|------------------|
| `:11434` | RX580 #1 (OK) | `gemma4-qat` (primário) |
| `:11435` | — (desactivado) | — |

**Próximo passo infra:** ROM válida para `RX580_2` → `hostpci1 rombar=1,romfile=…` → validar `02:00.0` → activar `ollama-gpu1` → apontar `agl-primary-strong` / `ollama-qwen3-8b` para `:11435`.

### Multi-GPU — expectativas (Ollama docs + prática)

| Cenário | Comportamento |
|---------|----------------|
| Modelo ≤8 GB (ex. `qwen3:8b`) | **1 GPU** — melhor tok/s por pedido |
| Modelo >8 GB (ex. `command-r7b`) | **Split** Vulkan0 + Vulkan1 |
| 2 pedidos paralelos | Até **2 modelos** carregados (1 por GPU) com `NUM_PARALLEL=2` |
| `OLLAMA_SCHED_SPREAD=1` | Espalha camadas em todas as GPUs — **não** acelera um único completion |

---

## Scripts

| Script | Onde |
|--------|------|
| `scripts/aglsrv3/restore-vm310-from-vm110.sh` | **Restore VM310 ← backup VM110** (pós-upgrade) |
| `scripts/aglsrv3/setup-vm310-agl-ollama.sh` | Cria VM310 do zero (cloud-init) |
| `scripts/aglsrv3/install-vm310-ollama-guest.sh` | Ollama + GPU na guest |
| `scripts/aglsrv3/ollama-tailscale-nat.sh` | NAT TS `:11434` → VM310 |
| `scripts/aglsrv3/vm310-ollama-override.conf` | systemd ollama GPU0 |
| `scripts/aglsrv3/vm310-ollama-gpu1-override.conf` | systemd ollama-gpu1 |
| `scripts/aglsrv3/apply-vm310-ollama-optimize.sh` | Deploy overrides + gpu1 condicional |
| `scripts/aglsrv3/prewarm-vm310-dual-ollama.sh` | Pre-warm gemma4 (+ qwen3 se GPU1) |
| `scripts/aglsrv3/prune-vm310-ollama-models.sh` | Remover modelos obsoletos |
| `scripts/aglsrv3/verify-vm310-gpu1-ready.sh` | Exit 0 se GPU1 amdgpu OK |
| `scripts/aglsrv3/benchmark-ollama-models.sh` | Benchmark multi-modelo (8 GB VRAM) |

---

## Benchmark de modelos (2× RX 580 — 16 GB VRAM)

Lista curada e script de comparação (latência, tokens/s, `ollama ps` GPU vs CPU):

```bash
# API Tailscale (obrigatório fora da VM310)
OLLAMA_HOST=http://100.67.253.52:11434 bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only

OLLAMA_HOST=http://100.67.253.52:11434 \
  OLLAMA_BENCH_MODELS="gemma4-qat qwen3:8b" \
  bash scripts/aglsrv3/benchmark-ollama-models.sh --api-only \
  --output /tmp/ollama-vm310-bench-gemma4-qat.csv
```

Saída CSV: `/tmp/ollama-vm310-bench-gemma4-qat.csv` (ou `--output`). Objetivo: **`100% GPU`** em `ollama ps`.

Modelos default (benchmark): `qwen3:4b`, `qwen3:8b`, `llama3.1:8b`, `gemma4-qat`.

**Removidos da VM310 (2026-06-12, prune):** `gemma3:4b` (redundante vs gemma4-qat), mais legados anteriores. Script: `scripts/aglsrv3/prune-vm310-ollama-models.sh`.

**Benchmark 2026-06-12 (2× RX580, `think: false`, TS `100.67.253.52`, 5 modelos produção):**

CSV: `/tmp/ollama-vm310-bench-gemma4-qat.csv`.

| Modelo | tok/s (chat quente) | tok/s (JSON quente) | VRAM | Notas |
|--------|---------------------|---------------------|------|-------|
| gemma4-qat | **~43** | **~46** | ~4.4 GB | **`agl-primary`** (primário AGL) |
| qwen3:4b | ~38 | ~38 | ~5.0 GB | **`ollama-qwen3-4b-fast`** (fallback) |
| qwen3:8b | **~25** | **~26** | ~7.2 GB | **`agl-primary-strong`** (secundário) |
| llama3.1:8b | ~19 | ~20 | ~7.0 GB | JSON/structured |

**Smoke LiteLLM CT186 (2026-06-11):** aliases Ollama activos OK. `request_timeout` global **240s**.

**Porque o benchmark anterior mostrava ~2 tok/s em qwen3:8b / qwen3.5:9b**

1. **Thinking activo por defeito** nos modelos Qwen3 — o script não passava `think: false`; com `num_predict=128` quase todos os tokens iam para o campo `thinking` e `content` ficava vazio → tok/s aparente ~2–3.
2. **LiteLLM já desactiva thinking** via callback (`agl_glm_flash_params.py`) — produção OK; só o benchmark estava errado.
3. **Tempo de load** (~60–80 s) ao trocar modelos entre testes inflava `wall_ms` (corrigido medindo com modelo quente).

Comparação thinking ON vs OFF (`qwen3:8b`, mesmo prompt):

| Modo | wall | content |
|------|------|---------|
| default (think ON) | ~117 s | vazio (128 tokens em thinking) |
| `think: false` | **~8 s** | resposta PT completa (~28 tok/s) |

---

**Tailscale:** `100.67.253.52` (`aglsrv3-ollama`) — LiteLLM usa este IP directamente.

NAT legado no host (`100.123.5.81:11434`) pode ser removido; script `ollama-tailscale-nat.sh` só necessário se a VM não tiver TS próprio.

---

## VM110 (AGLSRV1)

Permanece **parada** (GTX 1650 instável). Ollama primário migrou para AGLSRV3.

Ver histórico: [`docs/AGL-OLLAMA-VM110.md`](AGL-OLLAMA-VM110.md).

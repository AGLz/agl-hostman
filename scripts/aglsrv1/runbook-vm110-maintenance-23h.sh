#!/usr/bin/env bash
# Runbook — janela manutenção VM110 Plan C (AGLSRV1 ~23h).
# Orquestração desde agldv03 ou workstation com SSH aos hosts AGL.
#
# Fases:
#   preflight   — agora: checks + sync scripts (sem reboot)
#   host        — AGLSRV1: finish GPU passthrough + start VM110
#   guest       — VM110: NVIDIA + Plan C install + verify
#   litellm     — CT186: patch config + smoke agl-primary
#   all         — host → guest → litellm (após reboot manual do host)
#
# Uso:
#   PHASE=preflight bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh
#   # ~23h: reboot AGLSRV1 manualmente, depois:
#   PHASE=all bash scripts/aglsrv1/runbook-vm110-maintenance-23h.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
PHASE="${PHASE:-preflight}"

AGLSRV1="${AGLSRV1:-root@100.107.113.33}"
VM110="${VM110:-agladmin@192.168.0.200}"
VM110_ROOT="${VM110_ROOT:-root@192.168.0.200}"
VM110_TS="${VM110_TS:-100.116.57.111}"
CT186="${CT186:-root@100.125.249.8}"
REMOTE_REPO="${REMOTE_REPO:-/root/agl-hostman}"

log() { echo "[runbook-vm110] $*"; }

ssh_ok() {
  ssh -o BatchMode=yes -o ConnectTimeout=8 "$1" "true" 2>/dev/null
}

preflight() {
  log "=== Preflight Plan C (VM110 Gemma4 QAT text-only) ==="
  log "Repo local: $REPO"

  for host in "$AGLSRV1" "$CT186"; do
    if ssh_ok "$host"; then
      log "SSH OK: $host"
    else
      log "AVISO: SSH indisponível: $host"
    fi
  done

  if ping -c1 -W2 "$VM110_TS" >/dev/null 2>&1; then
    log "Ping OK: VM110 TS $VM110_TS"
  else
    log "Esperado: VM110 offline até reboot AGLSRV1 (~23h)"
  fi

  log "Sync scripts → AGLSRV1:$REMOTE_REPO"
  if ssh_ok "$AGLSRV1"; then
    ssh "$AGLSRV1" "mkdir -p $REMOTE_REPO/scripts/aglsrv1 $REMOTE_REPO/scripts/litellm $REMOTE_REPO/config/litellm"
    scp -q "$REPO/scripts/aglsrv1/"{vm110-gemma4-qat-modelfile,install-vm110-gemma4-qat-plan-c.sh,verify-vm110-gemma4-qat.sh,finish-vm110-gpu-passthrough.sh,prepare-gpu-passthrough-host.sh,vm110-ollama-override.conf} \
      "$AGLSRV1:$REMOTE_REPO/scripts/aglsrv1/"
    scp -q "$REPO/scripts/litellm/"{patch_config_vm110_plan_c.py,apply-litellm-vm110-plan-c.sh,restore-litellm-groq-failover.sh,deploy-litellm-callbacks-ct186.sh} \
      "$AGLSRV1:$REMOTE_REPO/scripts/litellm/" 2>/dev/null || true
    log "Scripts copiados para AGLSRV1"
  fi

  log "HF GGUF (sem mmproj): google/gemma-4-E2B-it-qat-q4_0-gguf / gemma-4-E2B_q4_0-it.gguf (~3,35 GB)"
  curl -sfI "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B_q4_0-it.gguf" | head -3 || log "AVISO: HF inacessível daqui"

  log ""
  log "=== Checklist 23h (manual) ==="
  log "1. AGLSRV1: bash $REMOTE_REPO/scripts/aglsrv1/prepare-gpu-passthrough-host.sh  (se vfio ainda não activo)"
  log "2. AGLSRV1: reboot"
  log "3. Após boot: PHASE=host bash runbook-vm110-maintenance-23h.sh"
  log "4. Guest NVIDIA (se necessário): ssh $VM110 → ubuntu-drivers install --gpgpu && reboot"
  log "5. PHASE=guest bash runbook..."
  log "6. PHASE=litellm bash runbook..."
  log ""
  log "Rollback LiteLLM: bash scripts/litellm/restore-litellm-groq-failover.sh"
}

phase_host() {
  log "=== Host AGLSRV1 — GPU passthrough VM110 ==="
  ssh "$AGLSRV1" "bash $REMOTE_REPO/scripts/aglsrv1/finish-vm110-gpu-passthrough.sh"
}

phase_guest() {
  log "=== Guest VM110 — Plan C install ==="
  local staging="/tmp/agl-plan-c"
  local target=""
  for cand in "$VM110_ROOT" "$VM110"; do
    if ssh_ok "$cand"; then
      target="$cand"
      break
    fi
  done
  if [[ -z "$target" ]]; then
    log "ERRO: SSH indisponível para VM110 ($VM110 / $VM110_ROOT)"
    exit 1
  fi
  ssh "$target" "mkdir -p $staging"
  scp -q "$REPO/scripts/aglsrv1/"{vm110-gemma4-qat-modelfile,install-vm110-gemma4-qat-plan-c.sh,verify-vm110-gemma4-qat.sh,vm110-ollama-override.conf} \
    "$target:$staging/"
  if [[ "$target" == *"@192.168.0.200" ]] && [[ "$target" != root* ]]; then
    ssh "$target" "sudo bash $staging/install-vm110-gemma4-qat-plan-c.sh && sudo bash $staging/verify-vm110-gemma4-qat.sh"
  else
    ssh "$target" "bash $staging/install-vm110-gemma4-qat-plan-c.sh && bash $staging/verify-vm110-gemma4-qat.sh"
  fi
}

phase_litellm() {
  log "=== LiteLLM CT186 — VM110 Plan C ==="
  log "Verificar Ollama remoto..."
  curl -sf "http://${VM110_TS}:11434/api/tags" >/dev/null || {
    log "ERRO: Ollama indisponível em ${VM110_TS}:11434"
    exit 1
  }
  VM110_OLLAMA_BASE="http://${VM110_TS}:11434" bash "$REPO/scripts/litellm/apply-litellm-vm110-plan-c.sh"
  OLLAMA_HOST="http://${VM110_TS}:11434" bash "$REPO/scripts/aglsrv1/verify-vm110-gemma4-qat.sh"
}

case "$PHASE" in
  preflight) preflight ;;
  host) phase_host ;;
  guest) phase_guest ;;
  litellm) phase_litellm ;;
  all)
    phase_host
    sleep 30
    phase_guest
    phase_litellm
    ;;
  *)
    echo "PHASE inválida: $PHASE (preflight|host|guest|litellm|all)" >&2
    exit 1
    ;;
esac

log "Fase $PHASE concluída."

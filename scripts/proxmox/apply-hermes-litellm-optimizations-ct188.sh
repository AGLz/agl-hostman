#!/usr/bin/env bash
# Orquestra optimizações LiteLLM + Hermes CT188 (modelos paid, max_tokens, crons).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

SKIP_LITELLM="${SKIP_LITELLM:-0}"
SKIP_HERMES="${SKIP_HERMES:-0}"
SKIP_OLLAMA="${SKIP_OLLAMA:-0}"
DRY_RUN="${DRY_RUN:-0}"

log() { printf '[apply-hermes-opt] %s\n' "$*"; }

main() {
  cd "$REPO_ROOT"

  if [[ "$SKIP_OLLAMA" != "1" ]]; then
    log "=== Ollama VM310 context ==="
    bash scripts/aglsrv3/apply-vm310-ollama-context.sh || log "WARN: VM310 offline — configs repo actualizados"
  fi

  if [[ "$SKIP_LITELLM" != "1" ]]; then
    log "=== LiteLLM patches ==="
    python3 scripts/litellm/patch-litellm-paid-output-limits.py config/litellm/config.yaml
    python3 scripts/litellm/patch_config_vm310_ollama.py \
      config/litellm/config.yaml config/litellm/config.yaml
    if [[ "$DRY_RUN" != "1" ]] && [[ -x scripts/litellm/deploy-litellm-callbacks-ct186.sh ]]; then
      bash scripts/litellm/deploy-litellm-callbacks-ct186.sh
    else
      log "DRY_RUN ou deploy script ausente — config.yaml local actualizado"
    fi
  fi

  if [[ "$SKIP_HERMES" != "1" ]]; then
    log "=== Hermes CT188 (OpenRouter free + local — sem paid/Z.AI swarm) ==="
    bash scripts/proxmox/hermes-openrouter-free-ct188.sh
    CRON_MODEL="${CRON_MODEL:-or-owl-alpha}" CRON_FALLBACK="${CRON_FALLBACK:-groq-llama-31-8b}" \
      bash scripts/proxmox/fix-hermes-max-tokens-ct188.sh
    CRON_MODEL="${CRON_MODEL:-or-owl-alpha}" CRON_FALLBACK="${CRON_FALLBACK:-groq-llama-31-8b}" \
      bash scripts/proxmox/fix-hermes-cron-models-ct188.sh
    if [[ "$DRY_RUN" != "1" ]]; then
      ssh -o ConnectTimeout=20 root@100.107.113.33 \
        "pct exec 188 -- bash -lc 'cd /opt/agl-hermes && docker compose restart agl-hermes-jarvis agl-hermes-elon agl-hermes-satya agl-hermes-werner agl-hermes-curator agl-hermes-orion 2>/dev/null || docker compose restart'"
    fi
  fi

  log "Concluído."
}

main "$@"

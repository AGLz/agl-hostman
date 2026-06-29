#!/usr/bin/env bash
# Política AGL (2026-06): Ollama GPU (sem limites) → Z.AI (quota maior) → OpenAI → Anthropic → outros.
# Aplica defaults em Hermes (CT188), OpenClaw (repo config) e EvoNexus (env example).
#
# Uso:
#   bash scripts/litellm/apply-agent-model-tier.sh hermes --host root@100.81.225.22
#   bash scripts/litellm/apply-agent-model-tier.sh hermes --local   # no CT188 actual
#   bash scripts/litellm/apply-agent-model-tier.sh openclaw --dry-run
#   bash scripts/litellm/apply-agent-model-tier.sh evonexus --ct 548 --host root@100.109.181.93

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:?Uso: $0 hermes|openclaw|evonexus [flags]}"
shift || true

HERMES_HOST=""
HERMES_LOCAL=0
DRY_RUN=0
EVONEXUS_CT=""
EVONEXUS_HOST=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) HERMES_HOST="${2:?}"; shift 2 ;;
    --local) HERMES_LOCAL=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --ct) EVONEXUS_CT="${2:?}"; shift 2 ;;
    *) echo "Flag desconhecida: $1" >&2; exit 1 ;;
  esac
done

# Modelos LiteLLM (CT186 Tailscale)
LITELLM_TS="${LITELLM_TS:-http://100.125.249.8:4000}"
PRIMARY_LOCAL="agl-primary"
PRIMARY_ZAI="zai-glm-5"
PRIMARY_ZAI_CODING="zai-coding-glm-4.7"
PRIMARY_OPENAI="gpt-5-mini"
PRIMARY_ANTHROPIC="claude-haiku"
FALLBACK_CHAIN="agl-primary,zai-glm-5,glm-5,zai-coding-glm-4.7,gpt-5.4-mini,claude-haiku,deepseek"

apply_hermes() {
  # Routing SEGURO (local zero-logging) por default: swarm lê o segundo cérebro (infra+agência).
  # Free OpenRouter (loga prompts) só em opt-in consciente para tarefas públicas.
  local secure="${REPO_ROOT}/scripts/proxmox/hermes-secure-routing-ct188.sh"
  if [[ "${HERMES_LOCAL}" -eq 1 ]]; then
    bash "${secure}"
    return
  fi
  if [[ -z "${HERMES_HOST}" ]]; then
    HERMES_HOST="root@100.81.225.22"
  fi
  echo "=== Hermes CT188 (secure routing) via ${HERMES_HOST} ==="
  scp "${secure}" "${HERMES_HOST}:/tmp/hermes-secure-routing-ct188.sh"
  ssh "${HERMES_HOST}" "bash /tmp/hermes-secure-routing-ct188.sh"
}

apply_openclaw() {
  echo "=== OpenClaw — configs em ${REPO_ROOT}/config/openclaw/ ==="
  echo "Primário recomendado: ${PRIMARY_LOCAL} (Ollama GPU)"
  echo "Fallbacks: ${FALLBACK_CHAIN}"
  echo "Reaplicar no CT187: scripts/deploy-openclaw-config.sh (após rever openclaw-patch.json)"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return
  fi
  echo "Configs actualizados no repo; correr deploy-openclaw-config.sh no host OpenClaw."
}

apply_evonexus() {
  local example="${REPO_ROOT}/config/evonexus/model-defaults.env.example"
  local ct="${EVONEXUS_CT:-548}"
  local host="${EVONEXUS_HOST:-root@100.109.181.93}"
  echo "=== EvoNexus CT${ct} (fgsrv7) ==="
  cat "${example}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return
  fi
  echo "Aplicar no host ${host}: pct exec ${ct} — merge em /workspace/config/.env"
  echo "  bash scripts/evonexus/migrate-off-dashscope-ct242.sh  # EVONEXUS_CTID=${ct}"
}

case "${TARGET}" in
  hermes) apply_hermes ;;
  openclaw) apply_openclaw ;;
  evonexus) apply_evonexus ;;
  *)
    echo "Alvo inválido: ${TARGET}" >&2
    exit 1
    ;;
esac

echo "OK — tier policy: Ollama → Z.AI → OpenAI → Anthropic → outros"

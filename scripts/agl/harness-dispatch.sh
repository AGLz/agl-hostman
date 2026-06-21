#!/usr/bin/env bash
# Dispatch executável multi-harness AGL — env profiles + probe + spawn headless.
#
# Uso:
#   bash scripts/agl/harness-dispatch.sh --harness claude-code --auth max-direct --task "fix bug X"
#   bash scripts/agl/harness-dispatch.sh --harness ruflo --auth litellm --task "implement spec Y" --repo /path
#   bash scripts/agl/harness-dispatch.sh --dry-run --harness cursor --auth cursor-pro --task "UI tweak"
#   bash scripts/agl/harness-dispatch.sh --print-env --auth litellm-free
#
# Wiki: llm-wiki/wiki/Ecossistema Harness Router AGL.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HARNESS_CONFIG_DIR="${HARNESS_CONFIG_DIR:-$HOSTMAN_ROOT/config/harness}"

HARNESS=""
AUTH=""
TASK=""
REPO=""
DRY_RUN=0
SKIP_PROBE=0
PRINT_ENV=0
JSON_OUT=0
EXEC=1

usage() {
  cat <<USAGE
Usage: $(basename "$0") --harness <name> --auth <mode> --task <text> [options]

Harness:  claude-code | cursor | verdent | ruflo
Auth:     max-direct | litellm | litellm-free | cursor-pro
          (aliases: direct, free)

Options:
  --repo <path>     Working directory (default: cwd)
  --dry-run         Mostrar plano sem executar
  --print-env       Aplicar perfil env e imprimir resumo (sem spawn)
  --skip-probe      Ignorar health check LiteLLM / claude
  --json            Output estruturado JSON (com --dry-run ou após probe)
  --no-exec         Equivalente a --dry-run para harnesses headless
  -h, --help

Perfis: config/harness/<profile>.env (local) ou *.env.example
USAGE
  exit 2
}

log() { echo "[harness-dispatch] $*" >&2; }

normalize_harness() {
  case "$1" in
    claude|claude-code) printf '%s' "claude-code" ;;
    cursor) printf '%s' "cursor" ;;
    verdent) printf '%s' "verdent" ;;
    ruflo) printf '%s' "ruflo" ;;
    *) return 1 ;;
  esac
}

normalize_auth() {
  case "$1" in
    max-direct|direct) printf '%s' "max-direct" ;;
    litellm) printf '%s' "litellm" ;;
    litellm-free|free) printf '%s' "litellm-free" ;;
    cursor-pro) printf '%s' "cursor-pro" ;;
    *) return 1 ;;
  esac
}

auth_env_basename() {
  case "$1" in
    max-direct) printf '%s' "claude-max" ;;
    litellm) printf '%s' "litellm-default" ;;
    litellm-free) printf '%s' "litellm-free" ;;
    cursor-pro) printf '%s' "cursor-pro" ;;
    *) return 1 ;;
  esac
}

skill_for_harness() {
  case "$1" in
    claude-code) printf '%s' "agl-claude-code-agent" ;;
    cursor) printf '%s' "agl-cursor-agent" ;;
    verdent) printf '%s' "agl-verdent-agent" ;;
    ruflo) printf '%s' "agl-ruflo-orchestrator" ;;
  esac
}

resolve_env_file() {
  local base="$1"
  local local_env="${HARNESS_CONFIG_DIR}/${base}.env"
  local example_env="${HARNESS_CONFIG_DIR}/${base}.env.example"
  if [[ -f "$local_env" ]]; then
    printf '%s' "$local_env"
  elif [[ -f "$example_env" ]]; then
    printf '%s' "$example_env"
  else
    return 1
  fi
}

source_env_profile() {
  local auth_mode="$1"
  local base
  base="$(auth_env_basename "$auth_mode")" || return 1
  local allowed_root
  allowed_root="$(cd "$HOSTMAN_ROOT/config/harness" && pwd)"
  local config_root
  config_root="$(cd "$HARNESS_CONFIG_DIR" 2>/dev/null && pwd)" || {
    log "ERRO: HARNESS_CONFIG_DIR inválido: $HARNESS_CONFIG_DIR"
    return 1
  }
  if [[ "$config_root" != "$allowed_root" ]]; then
    log "ERRO: HARNESS_CONFIG_DIR fora de config/harness permitido"
    return 1
  fi
  local env_file
  env_file="$(resolve_env_file "$base")" || {
    log "ERRO: perfil env em falta para auth=${auth_mode} (${base}.env ou .example)"
    return 1
  }
  env_file="$(cd "$(dirname "$env_file")" && pwd)/$(basename "$env_file")"
  if [[ "${env_file}" != "${allowed_root}/"* ]]; then
    log "ERRO: env file fora do diretório permitido"
    return 1
  fi
  # shellcheck source=/dev/null
  source "$env_file"
  ENV_FILE_SOURCED="$env_file"
}

env_summary() {
  local auth_mode="$1"
  case "$auth_mode" in
    max-direct)
      echo "ANTHROPIC_API_KEY=unset ANTHROPIC_BASE_URL=unset (Max OAuth)"
      ;;
    litellm|litellm-free)
      echo "ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL:-} LITELLM_GATEWAY_URL=${LITELLM_GATEWAY_URL:-}"
      if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}${LITELLM_VIRTUAL_KEY:-}" ]]; then
        echo "WARN: LITELLM_VIRTUAL_KEY / ANTHROPIC_AUTH_TOKEN não definido — definir em config/harness/litellm-default.env"
      fi
      ;;
    cursor-pro)
      echo "AGL_CURSOR_AUTH=cursor-pro (sem override BASE URL — pool Pro Cursor)"
      ;;
  esac
}

probe_litellm() {
  local url="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
  local health="${url%/}/health/liveliness"
  local code
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 8 "$health" 2>/dev/null || echo 000)"
  if [[ "$code" == "200" ]]; then
    log "probe LiteLLM OK ($health)"
    return 0
  fi
  log "probe LiteLLM FAIL ($health HTTP $code)"
  return 1
}

probe_auth() {
  local auth_mode="$1"
  case "$auth_mode" in
    max-direct)
      if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
        log "WARN: ANTHROPIC_API_KEY definida — Max OAuth pode não activar (unset recomendado)"
      fi
      if ! command -v claude >/dev/null 2>&1; then
        log "ERRO: claude CLI não encontrado no PATH"
        return 1
      fi
      ;;
    litellm|litellm-free)
      probe_litellm || return 1
      ;;
    cursor-pro)
      log "cursor-pro: sem probe automático (IDE manual / Auto pool)"
      ;;
  esac
  return 0
}

emit_structured() {
  local harness="$1" auth_mode="$2" skill="$3" rationale="$4" next="$5"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    if command -v jq >/dev/null 2>&1; then
      jq -cn \
        --arg harness "$harness" \
        --arg auth "$auth_mode" \
        --arg skill "$skill" \
        --arg rationale "$rationale" \
        --arg next "$next" \
        --arg env_file "${ENV_FILE_SOURCED:-}" \
        --arg repo "$REPO" \
        '{harness:$harness,auth:$auth,skill:$skill,rationale:$rationale,next:$next,env_file:$env_file,repo:$repo}'
    else
      log "WARN: jq em falta — JSON omitido; usar bloco texto"
      JSON_OUT=0
    fi
    [[ "$JSON_OUT" -eq 1 ]] && return
  fi
  cat <<BLOCK
HARNESS: $harness
AUTH: $auth_mode
SKILL: $skill
RATIONALE: $rationale
NEXT: $next
ENV: ${ENV_FILE_SOURCED:-none}
REPO: $REPO
BLOCK
}

claude_dsp_flags() {
  local flags=()
  if [[ "$(id -u)" -eq 0 ]] || [[ -n "${IS_SANDBOX:-}" ]]; then
    flags+=(--dangerously-skip-permissions)
  fi
  printf '%s\n' "${flags[@]}"
}

build_claude_cmd() {
  local -a cmd=(claude -p "$TASK")
  local flag
  while IFS= read -r flag; do
    [[ -n "$flag" ]] && cmd+=("$flag")
  done < <(claude_dsp_flags)
  printf '%q ' "${cmd[@]}"
}

build_ruflo_cmd() {
  if command -v ruflo >/dev/null 2>&1; then
    printf '%q ' ruflo hive-mind "$TASK"
  else
    printf '%q ' npx ruflo@latest hive-mind "$TASK"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --harness) HARNESS="$2"; shift 2 ;;
    --auth) AUTH="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --dry-run|--no-exec) DRY_RUN=1; EXEC=0; shift ;;
    --print-env) PRINT_ENV=1; EXEC=0; shift ;;
    --skip-probe) SKIP_PROBE=1; shift ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage ;;
    *) log "Opção desconhecida: $1"; usage ;;
  esac
done

[[ -n "$HARNESS" ]] || usage
[[ -n "$AUTH" ]] || usage

HARNESS="$(normalize_harness "$HARNESS")" || {
  log "Harness inválido: $HARNESS"
  exit 1
}
AUTH="$(normalize_auth "$AUTH")" || {
  log "Auth inválido: $AUTH"
  exit 1
}

if [[ "$PRINT_ENV" -eq 0 && -z "$TASK" && "$DRY_RUN" -eq 0 ]]; then
  log "ERRO: --task obrigatório (ou usar --dry-run / --print-env)"
  exit 1
fi

REPO="${REPO:-$(pwd)}"
if [[ ! -d "$REPO" ]]; then
  log "ERRO: --repo não é directorio: $REPO"
  exit 1
fi

ENV_FILE_SOURCED=""
source_env_profile "$AUTH"

if [[ "$PRINT_ENV" -eq 1 ]]; then
  echo "ENV_FILE=$ENV_FILE_SOURCED"
  env_summary "$AUTH"
  exit 0
fi

if [[ "$SKIP_PROBE" -eq 0 ]]; then
  probe_auth "$AUTH" || {
    log "Probe falhou — usar --auth litellm-free, --skip-probe, ou corrigir gateway"
    exit 1
  }
fi

SKILL="$(skill_for_harness "$HARNESS")"
RATIONALE="Dispatch Fase 2 agl-hostman"
NEXT=""

case "$HARNESS" in
  claude-code)
    NEXT="cd $(printf '%q' "$REPO") && $(build_claude_cmd)"
    if [[ "$DRY_RUN" -eq 1 || "$EXEC" -eq 0 ]]; then
      emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "$NEXT"
      exit 0
    fi
    emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "executando claude -p ..."
    cd "$REPO"
    # shellcheck disable=SC2046
    exec claude -p "$TASK" $(claude_dsp_flags)
    ;;
  ruflo)
    NEXT="cd $(printf '%q' "$REPO") && $(build_ruflo_cmd)"
    if [[ "$DRY_RUN" -eq 1 || "$EXEC" -eq 0 ]]; then
      emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "$NEXT"
      exit 0
    fi
    if ! command -v ruflo >/dev/null 2>&1; then
      log "ruflo não global — a usar npx ruflo@latest"
    fi
    emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "executando ruflo hive-mind ..."
    cd "$REPO"
    if command -v ruflo >/dev/null 2>&1; then
      exec ruflo hive-mind "$TASK"
    else
      exec npx ruflo@latest hive-mind "$TASK"
    fi
    ;;
  cursor)
    NEXT="Abrir Cursor em ${REPO}; Settings LiteLLM se auth=litellm; invocar /${SKILL}; task: ${TASK:-<definir>}"
    RATIONALE="Cursor não tem spawn headless fiável — instruções IDE"
    emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "$NEXT"
    exit 0
    ;;
  verdent)
    NEXT="Abrir Verdent (wk45); git worktree; /${SKILL}; LiteLLM se auth=litellm; task: ${TASK:-<definir>}"
    RATIONALE="Verdent é IDE paralelo — dispatch manual"
    emit_structured "$HARNESS" "$AUTH" "$SKILL" "$RATIONALE" "$NEXT"
    exit 0
    ;;
esac

log "ERRO: harness não tratado: $HARNESS"
exit 1

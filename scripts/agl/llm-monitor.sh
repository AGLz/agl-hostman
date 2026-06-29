#!/usr/bin/env bash
# CLI fino cross-harness — monitor de providers/models LLM AGL.
# Detentor canónico: agente Hermes Argus · skill agl-llm-monitor
#
# Uso:
#   bash scripts/agl/llm-monitor.sh status [--refresh]
#   bash scripts/agl/llm-monitor.sh check <provider>
#   bash scripts/agl/llm-monitor.sh probe [--type simple|complex]
#   bash scripts/agl/llm-monitor.sh why-blocked
#
# Env: GOVERNOR_STATE_FILE, LITELLM_GATEWAY_URL, LITELLM_ENV_FILE, GOVERNOR_ENV
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GOVERNOR="${REPO_ROOT}/scripts/litellm/quota-governor.sh"
AUDIT="${REPO_ROOT}/scripts/litellm/audit-providers-hermes.sh"
STATE_FILE="${GOVERNOR_STATE_FILE:-/var/log/hostman/quota-governor-state.json}"
GATEWAY="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
JSON_OUT=0

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

log() { echo "[llm-monitor] $*" >&2; }

run_governor_json() {
  GOVERNOR_STATE_FILE="$STATE_FILE" \
    LITELLM_GATEWAY_URL="$GATEWAY" \
    bash "$GOVERNOR" --json --dry-run "$@"
}

load_state() {
  python3 - "$STATE_FILE" <<'PY'
import json, sys
from pathlib import Path
p = Path(sys.argv[1])
if not p.is_file():
    print("{}")
    raise SystemExit(0)
try:
    print(json.dumps(json.loads(p.read_text())))
except Exception:
    print("{}")
PY
}

provider_model() {
  local p="${1,,}"
  case "$p" in
    anthropic|claude) printf '%s' "claude-haiku" ;;
    openai|gpt|codex) printf '%s' "gpt-5.4-mini" ;;
    zai|glm) printf '%s' "zai-glm-5" ;;
    groq) printf '%s' "groq-llama-31-8b" ;;
    free|flash|glm-flash) printf '%s' "glm-4.7-flash" ;;
    ollama|vm110|local-free) printf '%s' "agl-primary-vm110" ;;
    ollama-primary|primary|local) printf '%s' "agl-primary" ;;
    moonshot|kimi) printf '%s' "moonshot-v1-8k" ;;
    gemini) printf '%s' "gemini-2.5-flash" ;;
    openrouter|or) printf '%s' "glm-4.7-flash" ;;
    cursor) printf '%s' "cursor-composer" ;;
    verdent) printf '%s' "verdent-default" ;;
    *) return 1 ;;
  esac
}

probe_one_model() {
  local model="$1"
  local auth url code body snippet st
  # Reason: reutilizar carregamento de env do governor (master key, gateway)
  bash "$GOVERNOR" --dry-run --skip-probe >/dev/null 2>&1 || true
  if [[ -f "${LITELLM_ENV_FILE:-/opt/litellm/.env}" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "${LITELLM_ENV_FILE:-/opt/litellm/.env}" 2>/dev/null || true
    set +a
  fi
  if [[ -z "${LITELLM_MASTER_KEY:-}" && -f "${REPO_ROOT}/scripts/litellm/_litellm-master-key.sh" ]]; then
    LITELLM_MASTER_KEY="$("${REPO_ROOT}/scripts/litellm/_litellm-master-key.sh" 2>/dev/null || true)"
  fi
  auth=""
  [[ -n "${LITELLM_MASTER_KEY:-}" ]] && auth="Bearer ${LITELLM_MASTER_KEY}"
  url="${GATEWAY%/}/v1/chat/completions"
  body="$(jq -cn --arg m "$model" '{model:$m,messages:[{role:"user",content:"pong"}],max_tokens:4}')"
  code="$(curl -sS -o /tmp/llm-mon-probe-$$.json -w '%{http_code}' --max-time 45 \
    ${auth:+-H "Authorization: ${auth}"} \
    -H "Content-Type: application/json" \
    -d "$body" "$url" 2>/dev/null || echo 000)"
  snippet="$(python3 - /tmp/llm-mon-probe-$$.json <<'PY' 2>/dev/null || echo ERR
import json, sys
p = sys.argv[1]
try:
    d = json.load(open(p))
except Exception:
    print("ERR:parse")
    raise SystemExit
if "error" in d:
    e = d["error"]
    msg = e.get("message", str(e)) if isinstance(e, dict) else str(e)
    low = msg.lower()
    if any(x in low for x in ("quota", "429", "rate", "limit", "1310")):
        print("rate-limited:" + msg[:80])
    else:
        print("blocked:" + msg[:80])
elif d.get("choices"):
    c = d["choices"][0].get("message", {}).get("content", "")
    print("ok:" + (c or "empty")[:40])
else:
    print("blocked:unknown")
PY
)"
  rm -f /tmp/llm-mon-probe-$$.json
  if [[ "$code" == "200" && "$snippet" == ok:* ]]; then
    st="ok"
  elif [[ "$code" == "429" || "$snippet" == rate-limited:* ]]; then
    st="rate-limited"
  elif [[ "$code" == "401" || "$code" == "403" ]]; then
    st="blocked"
  else
    st="blocked"
  fi
  jq -cn --arg m "$model" --arg s "$st" --arg c "$code" --arg d "${snippet#*:}" \
    '{model:$m,status:$s,http:$c,detail:$d}'
}

format_block() {
  python3 - "$@" <<'PY'
import json, sys

mode = sys.argv[1]
if mode == "status":
    state = json.loads(sys.argv[2])
    action = state.get("action", "unknown")
    reason = state.get("reason", "")
    gw_ok = state.get("gateway_ok", False)
    tiers = state.get("tiers") or {}
    t5 = tiers.get("T5") or {}
    t3 = tiers.get("T3") or {}

    if action in ("critical", "degraded"):
        status = f"blocked({reason})"
        rec = "agl-primary-vm110" if t5.get("ok") else "escalar Tier B / harness alternativo"
        next_a = "pedir Tier B ao Argus" if action == "degraded" else "verificar LiteLLM CT186"
    elif action == "free-tier":
        status = "warn(failover@free-tier)"
        rec = "glm-4.7-flash"
        next_a = "usar free-tier; validar contexto da tarefa"
    elif action == "warn-spend":
        status = "warn(spend@global)"
        rec = "glm-4.7-flash ou agl-primary-vm110"
        next_a = "reduzir uso pago; monitorizar spend"
    else:
        status = "ok"
        rec = "zai-glm-5 ou modelo paid habitual"
        next_a = "continuar; re-router via agl-harness-router se 429"

    print(f"PROVIDER: all")
    print(f"STATUS: {status}")
    print(f"RECOMMEND: {rec}")
    print(f"WINDOWS: 5h=? weekly=? monthly=? rpm/tpm=gateway_ok={gw_ok}")
    print(f"NEXT: {next_a}")
    print(f"# action={action} t3_ok={t3.get('ok')} t5_ok={t5.get('ok')} spend={state.get('global_spend', 'n/a')}")
    raise SystemExit(0)

if mode == "check":
    probe = json.loads(sys.argv[2])
    provider = sys.argv[3]
    st = probe.get("status", "unknown")
    model = probe.get("model", "?")
    is_free = any(x in model for x in ("flash", "groq", "vm110", "llama-31"))
    if st == "ok" and is_free:
        rec = f"{model} (free — validar contexto da tarefa)"
        next_a = "OK para tarefas curtas; long-context → modelo paid"
    elif st == "ok":
        rec = model
        next_a = "usar via LiteLLM"
    elif st == "rate-limited":
        rec = "glm-4.7-flash" if not is_free else "agl-primary-vm110"
        next_a = "re-router via agl-harness-router ou pedir Tier B ao Argus"
    else:
        rec = "glm-4.7-flash"
        next_a = "why-blocked; considerar Tier A se paid falhou"

    print(f"PROVIDER: {provider}")
    print(f"STATUS: {st}")
    print(f"RECOMMEND: {rec}")
    print(f"WINDOWS: 5h=? weekly=? monthly=? rpm/tpm={probe.get('detail', '?')[:60]}")
    print(f"NEXT: {next_a}")
    raise SystemExit(0)

if mode == "why":
    state = json.loads(sys.argv[2])
    action = state.get("action", "unknown")
    reason = state.get("reason", "sem motivo registado")
    tiers = state.get("tiers") or {}
    lines = [f"ACTION: {action}", f"REASON: {reason}"]
    for tier, data in sorted(tiers.items()):
        lines.append(f"{tier}: ok={data.get('ok')} quota={data.get('quota')} fail={data.get('fail')} detail={data.get('detail', '')}")
    if action in ("degraded", "critical"):
        lines.append("NEXT: pedir Tier B ao Argus no Telegram; Werner aplica após OK")
    elif action == "free-tier":
        lines.append("NEXT: Tier A já aplicável — free-tier activo; validar se contexto serve a tarefa")
    else:
        lines.append("NEXT: nenhum bloqueio crítico — usar agl-harness-router")
    print("\n".join(lines))
PY
}

cmd_status() {
  local refresh=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --refresh) refresh=1; shift ;;
      --json) JSON_OUT=1; shift ;;
      *) log "Opção desconhecida: $1"; usage ;;
    esac
  done

  if [[ "$refresh" -eq 1 ]]; then
    log "A refrescar estado via quota-governor..."
    run_governor_json >/dev/null || true
  elif [[ ! -f "$STATE_FILE" ]]; then
    log "Estado em falta — a correr governor (--refresh implícito)"
    run_governor_json >/dev/null || true
  fi

  local state
  state="$(load_state)"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    printf '%s\n' "$state"
    return
  fi
  format_block status "$state"
}

cmd_check() {
  local provider="${1:-}"
  [[ -n "$provider" ]] || { log "Uso: llm-monitor.sh check <provider>"; exit 2; }
  shift || true
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) JSON_OUT=1; shift ;;
      *) log "Opção desconhecida: $1"; usage ;;
    esac
  done

  local model
  model="$(provider_model "$provider")" || {
    log "Provider desconhecido: $provider (tenta: anthropic openai zai groq free ollama cursor verdent)"
    exit 2
  }

  local probe
  probe="$(probe_one_model "$model" 2>/dev/null || echo '{"status":"blocked","model":"'"$model"'","detail":"probe failed"}')"
  if [[ "$JSON_OUT" -eq 1 ]]; then
    printf '%s\n' "$probe"
    return
  fi
  format_block check "$probe" "$provider"
}

cmd_probe() {
  local ptype="simple"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --type) ptype="${2:-simple}"; shift 2 ;;
      --json) JSON_OUT=1; shift ;;
      *) log "Opção desconhecida: $1"; usage ;;
    esac
  done

  case "$ptype" in
    simple)
      log "Probe simples — tiers T3/T4/T5 via quota-governor"
      if [[ "$JSON_OUT" -eq 1 ]]; then
        run_governor_json
      else
        run_governor_json >/dev/null && format_block status "$(load_state)"
      fi
      ;;
    complex)
      log "Probe complexa — audit-providers-hermes (budget ~5-10%% tokens)"
      if [[ ! -x "$AUDIT" && ! -f "$AUDIT" ]]; then
        log "ERRO: audit script em falta: $AUDIT"
        exit 2
      fi
      LITELLM_GATEWAY="$GATEWAY" bash "$AUDIT" 2>&1 | tail -40
      ;;
    *)
      log "Tipo inválido: $ptype (simple|complex)"
      exit 2
      ;;
  esac
}

cmd_why_blocked() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --json) JSON_OUT=1; shift ;;
      *) log "Opção desconhecida: $1"; usage ;;
    esac
  done

  local state
  state="$(load_state)"
  if [[ "$state" == "{}" ]]; then
    log "Sem estado — correr: llm-monitor.sh status --refresh"
    exit 1
  fi
  if [[ "$JSON_OUT" -eq 1 ]]; then
    printf '%s\n' "$state"
    return
  fi
  format_block why "$state"
}

main() {
  local cmd="${1:-}"
  shift || true
  case "$cmd" in
    status) cmd_status "$@" ;;
    check) cmd_check "$@" ;;
    probe) cmd_probe "$@" ;;
    why-blocked) cmd_why_blocked "$@" ;;
    -h|--help|"") usage ;;
    *) log "Comando desconhecido: $cmd"; usage ;;
  esac
}

main "$@"

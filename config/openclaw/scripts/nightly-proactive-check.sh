#!/bin/sh
# Nightly proactive scan — ignora ruído LLM/cron legado pós-migração command (2026-06).
set -eu
BASE=/home/node/.openclaw
WS="$BASE/workspace"
REPORTDIR="$WS/reports"
STATE_DIR="$WS/proactivity/state"
mkdir -p "$REPORTDIR" "$STATE_DIR" "$WS/memory"
TODAY_MEMORY="$WS/memory/$(date +%F).md"
if [ ! -f "$TODAY_MEMORY" ]; then
  {
    echo "# $(date +%F)"
    echo
    echo "- Runtime atual: OpenClaw CT187 (100.123.184.125), LiteLLM CT186 (100.125.249.8:4000)."
    echo "- Cron determinístico: command payload (sem agentTurn LLM)."
    echo "- Arquivo criado automaticamente pela rotina nightly-proactive-check."
  } > "$TODAY_MEMORY"
fi
REPORT="$REPORTDIR/nightly-proactive-check-$(date +%F).md"
LOG="/tmp/openclaw/openclaw-$(date +%F).log"
OFFSET_FILE="$STATE_DIR/nightly-proactive-check.log.offset"
WARN_FILE="$STATE_DIR/nightly-proactive-check.last-warnings"

# Padrões acionáveis (infra real; grep POSIX)
ACTIONABLE='payloads=0|Agent couldn|exec denied|ENOENT|ECONNREFUSED|STORAGE_HEALTH|CRITICAL SERVICES|litellm_ct186_http: [45]|litellm_ct186_http: curl|openclaw_health: \{|SSH .*FAIL|exit code [1-9]'

# Ruído conhecido: falhas LLM antigas, fallback glm-flash, rate limit, polling Telegram
NOISE='MidStreamFallbackError|max_tokens parameter is illegal|Model Group=glm-flash|API rate limit|embedded_run_agent_end|embedded_run_failover|Polling stall|openclaw cron list|FailoverError|gpt-5\.4-nano|lane task error: lane=cron|consecutiveErrors.*backoffMs|cron: applying error backoff'

current_size=0
[ -f "$LOG" ] && current_size=$(wc -c < "$LOG" | tr -d ' ')
last_offset="$current_size"
[ -f "$OFFSET_FILE" ] && last_offset=$(cat "$OFFSET_FILE" 2>/dev/null || echo "$current_size")
case "$last_offset" in ''|*[!0-9]*) last_offset="$current_size" ;; esac
[ "$last_offset" -gt "$current_size" ] && last_offset=0

: > "$WARN_FILE"
if [ -f "$LOG" ] && [ "$current_size" -gt "$last_offset" ]; then
  tail -c +$((last_offset + 1)) "$LOG" \
    | grep -Ei "$ACTIONABLE" \
    | grep -viE "$NOISE" \
    | tail -20 > "$WARN_FILE" || true
fi
printf '%s\n' "$current_size" > "$OFFSET_FILE"

{
  echo "# Nightly Proactive Check - $(date '+%F %T %z')"
  echo
  echo "## Runtime"
  echo "- OpenClaw: CT187 / 100.123.184.125"
  echo "- LiteLLM: CT186 / 100.125.249.8:4000"
  echo "- Cron: command payload (sem LLM)"
  echo
  echo "## Required Files"
  for f in "$WS/MEMORY.md" "$WS/self-improving/memory.md" "$WS/proactivity/session-state.md" "$WS/memory/$(date +%F).md"; do
    if [ -f "$f" ]; then echo "- OK: $f"; else echo "- MISSING_OPTIONAL: $f"; fi
  done
  echo
  echo "## New Gateway Warnings Since Last Run"
  if [ -s "$WARN_FILE" ]; then cat "$WARN_FILE"; else echo "- None"; fi
} > "$REPORT"

if [ -s "$WARN_FILE" ]; then
  echo "NIGHTLY_CHECK_WARNINGS"
  echo "Report: $REPORT"
  sed -n '1,8p' "$WARN_FILE"
  exit 1
else
  echo "HEARTBEAT_OK"
fi

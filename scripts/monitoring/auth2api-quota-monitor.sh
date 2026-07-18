#!/usr/bin/env bash
# Monitor consumo auth2api (tokens) — janelas diária / semanal / mensal.
#
# Fonte: docker/auth2api/data/stats.jsonl (ou AUTH2API_STATS_JSONL)
# Soft limits (env, tokens input+output+reasoning):
#   AUTH2API_DAILY_TOKEN_WARN=500000
#   AUTH2API_WEEKLY_TOKEN_WARN=2000000
#   AUTH2API_MONTHLY_TOKEN_WARN=8000000
#
# Modos:
#   --daily   (default) texto para Argus / cron
#   --alert   só emite se warn/critical; senão [SILENT]
#   --json    dump JSON

set -euo pipefail

MODE="${1:---daily}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AUTH_DIR="${AUTH2API_DIR:-$ROOT/docker/auth2api}"
CT186_SSH="${LITELLM_SSH_HOST:-root@100.125.249.8}"
REMOTE_STATS="${AUTH2API_REMOTE_STATS:-/opt/agl-auth2api/data/stats.jsonl}"
CACHE_STATS="${AUTH2API_STATS_CACHE:-/var/tmp/auth2api-stats-ct186.jsonl}"
STATS="${AUTH2API_STATS_JSONL:-}"
DAILY_WARN="${AUTH2API_DAILY_TOKEN_WARN:-500000}"
WEEKLY_WARN="${AUTH2API_WEEKLY_TOKEN_WARN:-2000000}"
MONTHLY_WARN="${AUTH2API_MONTHLY_TOKEN_WARN:-8000000}"
STATE_DIR="${AUTH2API_QUOTA_STATE_DIR:-/var/log/hostman}"
STATE_FILE="${STATE_DIR}/auth2api-quota-state.json"

if [[ -z "$STATS" ]]; then
  if scp -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
    "${CT186_SSH}:${REMOTE_STATS}" "$CACHE_STATS" 2>/dev/null; then
    STATS="$CACHE_STATS"
  elif [[ -f "$AUTH_DIR/data/stats.jsonl" ]]; then
    STATS="$AUTH_DIR/data/stats.jsonl"
  fi
fi

if [[ -z "${STATS:-}" || ! -f "$STATS" ]]; then
  echo "auth2api-quota: sem stats (CT186 $REMOTE_STATS nem lab local)" >&2
  [[ "$MODE" == "--alert" ]] && echo "[SILENT]" && exit 0
  exit 1
fi

mkdir -p "$STATE_DIR" 2>/dev/null || true

REPORT="$(python3 - "$STATS" "$DAILY_WARN" "$WEEKLY_WARN" "$MONTHLY_WARN" <<'PY'
import json, sys
from datetime import datetime, timezone, timedelta
from collections import defaultdict

path, d_warn, w_warn, m_warn = sys.argv[1:5]
d_warn, w_warn, m_warn = int(d_warn), int(w_warn), int(m_warn)
now = datetime.now(timezone.utc)
day0 = now.replace(hour=0, minute=0, second=0, microsecond=0)
week0 = day0 - timedelta(days=day0.weekday())  # Monday
month0 = day0.replace(day=1)

def tok(u):
    if not u:
        return 0
    return int(u.get("inputTokens") or 0) + int(u.get("outputTokens") or 0) + int(
        u.get("reasoningOutputTokens") or 0
    )

buckets = {
    "day": {"tokens": 0, "ok": 0, "fail": 0, "by_provider": defaultdict(int)},
    "week": {"tokens": 0, "ok": 0, "fail": 0, "by_provider": defaultdict(int)},
    "month": {"tokens": 0, "ok": 0, "fail": 0, "by_provider": defaultdict(int)},
}

with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        ts = ev.get("ts")
        if not ts:
            continue
        t = datetime.fromisoformat(ts.replace("Z", "+00:00"))
        if ev.get("endpoint", "").startswith("GET ") and not ev.get("usage"):
            # ignora polls admin sem usage
            if ev.get("endpoint") != "POST /v1/chat/completions" and "messages" not in (
                ev.get("endpoint") or ""
            ):
                if not (ev.get("endpoint") or "").startswith("POST /v1/"):
                    continue
        usage_t = tok(ev.get("usage"))
        # contar só completions/messages com usage ou falhas de chat
        ep = ev.get("endpoint") or ""
        if not ep.startswith("POST /v1/"):
            continue
        prov = ev.get("provider") or "unknown"
        status = ev.get("status") or ""
        for name, start in (("day", day0), ("week", week0), ("month", month0)):
            if t >= start:
                buckets[name]["tokens"] += usage_t
                if status == "success":
                    buckets[name]["ok"] += 1
                else:
                    buckets[name]["fail"] += 1
                buckets[name]["by_provider"][prov] += usage_t

def level(tokens, warn):
    if tokens >= warn:
        return "WARN"
    if tokens >= int(warn * 0.8):
        return "WATCH"
    return "OK"

out = {
    "generated_at": now.isoformat(),
    "limits": {"daily": d_warn, "weekly": w_warn, "monthly": m_warn},
    "windows": {},
    "alerts": [],
}
for name, warn_key in (("day", d_warn), ("week", w_warn), ("month", m_warn)):
    b = buckets[name]
    lv = level(b["tokens"], warn_key)
    out["windows"][name] = {
        "tokens": b["tokens"],
        "requests_ok": b["ok"],
        "requests_fail": b["fail"],
        "by_provider": dict(b["by_provider"]),
        "limit": warn_key,
        "level": lv,
        "pct": round(100.0 * b["tokens"] / warn_key, 1) if warn_key else 0,
    }
    if lv == "WARN":
        out["alerts"].append(f"{name}: {b['tokens']} tokens >= limit {warn_key}")

print(json.dumps(out, ensure_ascii=False))
PY
)"

echo "$REPORT" >"$STATE_FILE" 2>/dev/null || true

# Espelhar estado no CT188 para o digest Argus
HERMES_SSH="${HERMES_SSH:-root@100.81.225.22}"
if [[ -f "$STATE_FILE" ]]; then
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$HERMES_SSH" \
    "mkdir -p /var/log/hostman" 2>/dev/null || true
  scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
    "$STATE_FILE" "${HERMES_SSH}:/var/log/hostman/auth2api-quota-state.json" 2>/dev/null || true
fi

if [[ "$MODE" == "--json" ]]; then
  echo "$REPORT"
  exit 0
fi

ALERTS="$(echo "$REPORT" | jq -r '.alerts[]?' 2>/dev/null || true)"
if [[ "$MODE" == "--alert" ]]; then
  if [[ -z "${ALERTS// }" ]]; then
    echo "[SILENT]"
    exit 0
  fi
  echo "auth2api quota ALERT ($(date '+%Y-%m-%d %H:%M %Z'))"
  echo "$REPORT" | jq -r '.alerts[]' | while read -r a; do echo "• $a"; done
  exit 0
fi

# --daily
echo "auth2api quota ($(date '+%Y-%m-%d %H:%M %Z'))"
echo "$REPORT" | jq -r '
  .windows as $w |
  "• dia: \($w.day.tokens) tok (\($w.day.pct)% limite \($w.day.limit)) [\($w.day.level)] ok=\($w.day.requests_ok) fail=\($w.day.requests_fail)",
  "• semana: \($w.week.tokens) tok (\($w.week.pct)%) [\($w.week.level)]",
  "• mês: \($w.month.tokens) tok (\($w.month.pct)%) [\($w.month.level)]",
  (.windows.month.by_provider // {} | to_entries | map("• provider \(.key): \(.value) tok") | .[])
'

# Contas OAuth (opcional)
if [[ -f "$AUTH_DIR/.env" ]]; then
  # shellcheck disable=SC1091
  set -a
  source "$AUTH_DIR/.env"
  set +a
  if [[ -n "${AUTH2API_API_KEY:-}" ]] && curl -fsS -m 3 http://127.0.0.1:8317/admin/accounts \
    -H "Authorization: Bearer ${AUTH2API_API_KEY}" >/tmp/a2a-acc.json 2>/dev/null; then
    jq -r '
      .providers | to_entries[] |
      select(.value.account_count > 0) |
      "• conta \(.key): \(.value.accounts[0].email // "?") avail=\(.value.accounts[0].available)"
    ' /tmp/a2a-acc.json 2>/dev/null || true
  fi
fi

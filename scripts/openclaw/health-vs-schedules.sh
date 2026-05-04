#!/usr/bin/env bash
# health-vs-schedules.sh — Validate gateway health against cron schedule expectations
# Tests: Does the gateway respond correctly for each model used by cron jobs?
# Does each cron job's model actually exist and respond in LiteLLM?
# Usage: bash scripts/openclaw/health-vs-schedules.sh [--verbose]

CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"
LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
LITELLM_KEY="${LITELLM_MASTER_KEY:-}"
GATEWAY_PORT="28789"
CRON_FILE="/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json"
VERBOSE="${1:-}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
warn() { WARN=$((WARN+1)); echo "  ⚠️  $1"; }
info() { echo "  ℹ️  $1"; }

echo "=========================================="
echo "  Gateway Health vs Cron Schedules"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# ============================================
# 1. Extract models used by cron jobs
# ============================================
echo ""
echo "📋 Cron Job Models"

python3 << 'PYEOF'
import json, re
d = json.load(open("/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json"))
for j in d.get("jobs", []):
    name = j.get("name", "unknown")
    enabled = j.get("enabled", False)
    msg = j.get("payload", {}).get("message", "")
    models = re.findall(r"model[\"s]*\s*[:=]\s*[\"']?([a-zA-Z0-9_/.: -]+)", msg)
    models += re.findall(r"\$\{?(\w+)_MODEL\}?", msg)
    models += re.findall(r"--model\s+([a-zA-Z0-9_/.: -]+)", msg)
    status = "enabled" if enabled else "disabled"
    model_list = ", ".join(set(models)) if models else "(uses default agent model)"
    print(f"  {name:35s} [{status}] models: {model_list}")
PYEOF

# ============================================
# 2. Test default agent model
# ============================================
echo ""
echo "🎯 Default Agent Model"

DEFAULT_MODEL=$(python3 << 'PYEOF'
import json
d = json.load(open("/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"))
print(d.get("agents",{}).get("defaults",{}).get("model",{}).get("primary","MISSING"))
PYEOF
)

FALLBACKS=$(python3 << 'PYEOF'
import json
d = json.load(open("/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"))
print(",".join(d.get("agents",{}).get("defaults",{}).get("model",{}).get("fallbacks",[])))
PYEOF
)

info "Primary: $DEFAULT_MODEL"
info "Fallbacks: $FALLBACKS"

# Test primary model through LiteLLM
if [ "$DEFAULT_MODEL" != "MISSING" ]; then
    MODEL_NAME="${DEFAULT_MODEL#*/}"

    echo "  Testing $MODEL_NAME via LiteLLM..."
    RESULT=$(docker exec "$CONTAINER" timeout 30 node -e "
      fetch('${LITELLM_GATEWAY_URL}/v1/chat/completions', {
        method: 'POST',
        headers: {
          ...(process.env.LITELLM_MASTER_KEY ? {'Authorization': 'Bearer ${LITELLM_KEY}'} : {}),
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: '${MODEL_NAME}',
          messages: [{role: 'user', content: 'Say OK in 3 words max'}],
          max_tokens: 10
        })
      }).then(r => r.json()).then(d => {
        if (d.error) {
          console.log('ERR:' + JSON.stringify(d.error).substring(0, 150));
        } else {
          console.log('OK:' + d.choices[0].message.content);
        }
      }).catch(e => console.log('ERR:' + e.message));
    " 2>&1) || RESULT="TIMEOUT"

    if echo "$RESULT" | grep -q "^OK:"; then
        RESPONSE=$(echo "$RESULT" | sed 's/^OK://')
        pass "Primary model '$DEFAULT_MODEL' → $RESPONSE"
    else
        fail "Primary model '$DEFAULT_MODEL' failed: $RESULT"
    fi
fi

# Test fallbacks
if [ -n "$FALLBACKS" ]; then
    IFS=',' read -ra FALLBACK_ARRAY <<< "$FALLBACKS"
    for FALLBACK in "${FALLBACK_ARRAY[@]}"; do
        FALLBACK_NAME="${FALLBACK#*/}"

        RESULT=$(docker exec "$CONTAINER" timeout 30 node -e "
          fetch('${LITELLM_GATEWAY_URL}/v1/chat/completions', {
            method: 'POST',
            headers: {
              ...(process.env.LITELLM_MASTER_KEY ? {'Authorization': 'Bearer ${LITELLM_KEY}'} : {}),
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              model: '${FALLBACK_NAME}',
              messages: [{role: 'user', content: 'Say OK'}],
              max_tokens: 10
            })
          }).then(r => r.json()).then(d => {
            if (d.error) console.log('ERR:' + JSON.stringify(d.error).substring(0, 100));
            else console.log('OK');
          }).catch(e => console.log('ERR:' + e.message));
        " 2>&1) || RESULT="TIMEOUT"

        if echo "$RESULT" | grep -q "^OK"; then
            pass "Fallback '$FALLBACK' responds"
        else
            warn "Fallback '$FALLBACK' failed: $RESULT"
        fi
    done
fi

# ============================================
# 3. Gateway health endpoint
# ============================================
echo ""
echo "🏥 Gateway Health"

HEALTH=$(curl -s -m 10 "http://127.0.0.1:${GATEWAY_PORT}/healthz" 2>/dev/null)
if echo "$HEALTH" | grep -q '"ok":true'; then
    pass "Gateway /healthz: OK"
else
    fail "Gateway /healthz failed: $HEALTH"
fi

# ============================================
# 4. LiteLLM models endpoint
# ============================================
echo ""
echo "📚 LiteLLM Models"

AUTH_HEADER=()
if [ -n "$LITELLM_KEY" ]; then
    AUTH_HEADER=(-H "Authorization: Bearer ${LITELLM_KEY}")
fi

MODEL_COUNT=$(curl -s -m 10 "${LITELLM_GATEWAY_URL}/v1/models" \
    "${AUTH_HEADER[@]}" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
print(len(d.get('data', [])))
" 2>/dev/null || echo "0")

if [ -n "$MODEL_COUNT" ] && [ "$MODEL_COUNT" -gt 0 ]; then
    pass "LiteLLM reports $MODEL_COUNT models available"

    if [ -n "$MODEL_NAME" ]; then
        MODEL_IN_LIST=$(curl -s -m 10 "${LITELLM_GATEWAY_URL}/v1/models" \
            "${AUTH_HEADER[@]}" 2>/dev/null | python3 -c "
import json, sys
d = json.load(sys.stdin)
models = [m['id'] for m in d.get('data', [])]
primary = '${MODEL_NAME}'
for m in models:
    if primary in m or m in primary:
        print(m)
        break
else:
    print('NOT_FOUND')
" 2>/dev/null || echo "ERROR")

        if [ "$MODEL_IN_LIST" != "NOT_FOUND" ] && [ "$MODEL_IN_LIST" != "ERROR" ]; then
            pass "Primary model '$MODEL_NAME' found as '$MODEL_IN_LIST' in LiteLLM"
        else
            warn "Primary model '$MODEL_NAME' not found in LiteLLM model list"
        fi
    fi
else
    fail "Could not get model count from LiteLLM"
fi

# ============================================
# 5. Cron job schedule validation
# ============================================
echo ""
echo "⏰ Schedule Validation"

python3 << 'PYEOF'
import json, time

data = json.load(open("/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json"))
now = int(time.time() * 1000)

for j in data.get("jobs", []):
    name = j.get("name", "unknown")
    enabled = j.get("enabled", False)
    schedule = j.get("schedule", {})
    state = j.get("state", {})

    every_ms = schedule.get("everyMs", 0)
    next_run = state.get("nextRunAtMs", 0)
    last_run = state.get("lastRunAtMs", 0)
    consec_err = state.get("consecutiveErrors", 0)
    last_status = state.get("lastStatus", "?")

    if next_run > 0:
        delta_min = (next_run - now) / 60000
        delta_str = f"{delta_min:+.1f}min"
    else:
        delta_str = "N/A"

    if last_run > 0:
        last_delta_min = (now - last_run) / 60000
        last_str = f"{last_delta_min:.0f}min ago"
    else:
        last_str = "never"

    issues = []
    if not enabled:
        issues.append("DISABLED")
    if consec_err > 0:
        issues.append(f"{consec_err} errors")
    if last_status == "error":
        issues.append("last error")
    if "runningAtMs" in state:
        issues.append("running now")

    status = "✅" if not issues else "❌ " + ", ".join(issues)

    every_human = f"{every_ms/1000:.0f}s" if every_ms > 0 else "once"
    print(f"  {name:35s} every={every_human:10s} next={delta_str:10s} last={last_str:12s} {status}")
PYEOF

# ============================================
# Summary
# ============================================
echo ""
echo "=========================================="
echo "  Summary"
echo "=========================================="
echo "  ✅ Pass: $PASS"
echo "  ❌ Fail: $FAIL"
echo "  ⚠️  Warn: $WARN"
echo "=========================================="

if [ "$FAIL" -gt 0 ]; then
    echo "  STATUS: ❌ ISSUES FOUND"
    exit 1
elif [ "$WARN" -gt 0 ]; then
    echo "  STATUS: ⚠️  WARNINGS"
    exit 0
else
    echo "  STATUS: ✅ ALL GOOD"
    exit 0
fi

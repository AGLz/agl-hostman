#!/usr/bin/env bash
# validate-openclaw-docker.sh — Comprehensive OpenClaw Docker Validation
# Usage: bash scripts/openclaw/validate-openclaw-docker.sh [--verbose]
# Checks: container health, LiteLLM connectivity, models, cron jobs, Telegram, schedules

set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-agl-openclaw-openclaw-gateway-1}"
LITELLM_CONTAINER="litellm-proxy"
LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
LITELLM_KEY="${LITELLM_MASTER_KEY:-}"
GATEWAY_PORT="28789"
CONFIG_FILE="/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json"
VERBOSE="${1:-}"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS+1)); echo "  ✅ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ❌ $1"; }
warn() { WARN=$((WARN+1)); echo "  ⚠️  $1"; }
info() { echo "  ℹ️  $1"; }

echo "=========================================="
echo "  OpenClaw Docker Validation"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "=========================================="

# ============================================
# 1. Container Health
# ============================================
echo ""
echo "📦 Container Health"

if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    STATUS=$(docker ps --format '{{.Status}}' -f "name=${CONTAINER}" | head -1)
    if echo "$STATUS" | grep -qi "healthy"; then
        pass "Container running and healthy: $STATUS"
    elif echo "$STATUS" | grep -qi "up"; then
        warn "Container running but health check not passing: $STATUS"
    else
        fail "Container status unknown: $STATUS"
    fi
else
    fail "Container $CONTAINER not found"
fi

# Check LiteLLM
if docker ps --format '{{.Names}}' | grep -q "^${LITELLM_CONTAINER}$"; then
    LITELLM_STATUS=$(docker ps --format '{{.Status}}' -f "name=${LITELLM_CONTAINER}" | head -1)
    if echo "$LITELLM_STATUS" | grep -qi "healthy"; then
        pass "LiteLLM proxy healthy: $LITELLM_STATUS"
    else
        warn "LiteLLM status: $LITELLM_STATUS"
    fi
else
    fail "LiteLLM container $LITELLM_CONTAINER not found"
fi

# ============================================
# 2. Network Connectivity
# ============================================
echo ""
echo "🌐 Network Connectivity"

# Check container is on LiteLLM network
if docker inspect "$CONTAINER" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null | grep -q "litellm"; then
    pass "Container connected to LiteLLM network"
else
    info "Container not on LiteLLM Docker network; CT186 gateway URL is ${LITELLM_GATEWAY_URL}"
fi

# Test LiteLLM from container
RESULT=$(docker exec "$CONTAINER" node -e "
  fetch('${LITELLM_GATEWAY_URL}/v1/chat/completions', {
    method: 'POST',
    headers: {
      ...(process.env.LITELLM_MASTER_KEY ? {'Authorization': 'Bearer ${LITELLM_KEY}'} : {}),
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model: 'qwen3.5-flash',
      messages: [{role: 'user', content: 'Say OK'}],
      max_tokens: 10
    })
  }).then(r => r.json()).then(d => {
    if (d.error) console.log('ERR:' + JSON.stringify(d.error).substring(0, 100));
    else console.log('OK:' + d.choices[0].message.content);
  }).catch(e => console.log('ERR:' + e.message));
" 2>&1)

if echo "$RESULT" | grep -q "^OK:"; then
    pass "LiteLLM chat completions working ($RESULT)"
elif echo "$RESULT" | grep -q "^ERR:"; then
    fail "LiteLLM chat failed: $RESULT"
else
    fail "LiteLLM test returned unexpected: $RESULT"
fi

# ============================================
# 3. Gateway Health
# ============================================
echo ""
echo "🏥 Gateway Health"

HEALTH=$(curl -s -m 10 "http://127.0.0.1:${GATEWAY_PORT}/healthz" 2>/dev/null)
if echo "$HEALTH" | grep -q '"ok":true'; then
    pass "Gateway healthz: OK"
else
    fail "Gateway healthz failed: $HEALTH"
fi

# ============================================
# 4. Configuration
# ============================================
echo ""
echo "⚙️  Configuration"

if [ -f "$CONFIG_FILE" ]; then
    pass "Config file exists: $CONFIG_FILE"

    # Validate JSON
    if python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
        pass "Config JSON is valid"
    else
        fail "Config JSON is invalid"
    fi

    # Check provider
    PROVIDER_URL=$(python3 -c "
import json
d = json.load(open('$CONFIG_FILE'))
print(d.get('models',{}).get('providers',{}).get('openai',{}).get('baseUrl','MISSING'))
" 2>/dev/null)

    if [ "$PROVIDER_URL" = "http://${LITELLM_IP}:4000" ]; then
        pass "Provider URL correct: $PROVIDER_URL"
    elif [ "$PROVIDER_URL" = "MISSING" ]; then
        fail "Provider URL not configured"
    else
        warn "Provider URL: $PROVIDER_URL (expected http://${LITELLM_IP}:4000)"
    fi

    # Check primary model
    PRIMARY_MODEL=$(python3 -c "
import json
d = json.load(open('$CONFIG_FILE'))
print(d.get('agents',{}).get('defaults',{}).get('model',{}).get('primary','MISSING'))
" 2>/dev/null)

    if [ "$PRIMARY_MODEL" != "MISSING" ]; then
        pass "Primary model: $PRIMARY_MODEL"
    else
        fail "Primary model not configured"
    fi

    # Check Telegram
    TELEGRAM_ENABLED=$(python3 -c "
import json
d = json.load(open('$CONFIG_FILE'))
print(d.get('channels',{}).get('telegram',{}).get('enabled', False))
" 2>/dev/null)

    if [ "$TELEGRAM_ENABLED" = "True" ]; then
        pass "Telegram channel: enabled"
    else
        warn "Telegram channel: $TELEGRAM_ENABLED"
    fi
else
    fail "Config file not found: $CONFIG_FILE"
fi

# ============================================
# 5. Cron Jobs
# ============================================
echo ""
echo "⏰ Cron Jobs"

CRON_LIST=$(docker exec "$CONTAINER" openclaw cron list 2>&1 | grep -v "Config warnings" | tail -n +2)

if [ -z "$CRON_LIST" ]; then
    fail "No cron jobs returned from container"
else
    # Check each job (read com || evita exit 1 do último read com set -e)
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] && continue
        JOB_NAME=$(echo "$line" | awk '{print $2}' | cut -d'.' -f1)
        JOB_STATUS=$(echo "$line" | grep -oE '(ok|error|running)' | head -1)

        case "$JOB_STATUS" in
            ok) pass "Cron job '$JOB_NAME': $JOB_STATUS" ;;
            running) warn "Cron job '$JOB_NAME': currently running" ;;
            error) fail "Cron job '$JOB_NAME': $JOB_STATUS" ;;
            *) warn "Cron job '$JOB_NAME': unknown status ($JOB_STATUS)" ;;
        esac
    done <<< "$CRON_LIST"
fi

# ============================================
# 6. Telegram Bot
# ============================================
echo ""
echo "📱 Telegram Bot"

TELEGRAM_LOGS=$(docker logs "$CONTAINER" --tail=100 2>/dev/null | grep -i "telegram" | tail -5)

if echo "$TELEGRAM_LOGS" | grep -qi "starting provider"; then
    # Reason: grep sem match retorna 1 e com set -e aborta o script
    BOT_NAME=$(echo "$TELEGRAM_LOGS" | grep -oE '@[a-zA-Z0-9_]+' | tail -1 || true)
    if [ -n "$BOT_NAME" ]; then
        pass "Telegram bot connected: $BOT_NAME"
    else
        pass "Telegram provider started"
    fi
elif echo "$TELEGRAM_LOGS" | grep -qi "error\|fail"; then
    fail "Telegram errors found in logs"
    if [ "$VERBOSE" = "--verbose" ]; then
        echo "$TELEGRAM_LOGS" | grep -i "error\|fail" | tail -5
    fi
else
    warn "Telegram status unclear from recent logs"
fi

# ============================================
# 7. Models Validation
# ============================================
echo ""
echo "🤖 Models"

# Test primary model
if [ "$PRIMARY_MODEL" != "MISSING" ] && [ "$PROVIDER_URL" = "http://${LITELLM_IP}:4000" ]; then
    MODEL_TEST=$(docker exec "$CONTAINER" node -e "
      fetch('http://${LITELLM_IP}:4000/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Authorization': 'Bearer ${LITELLM_KEY}',
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          model: '${PRIMARY_MODEL#*/}',
          messages: [{role: 'user', content: 'Say OK'}],
          max_tokens: 10
        })
      }).then(r => r.json()).then(d => {
        if (d.error) console.log('ERR:' + JSON.stringify(d.error).substring(0, 100));
        else console.log('OK');
      }).catch(e => console.log('ERR:' + e.message));
    " 2>&1)

    if echo "$MODEL_TEST" | grep -q "^OK"; then
        pass "Primary model '$PRIMARY_MODEL' responds"
    else
        fail "Primary model '$PRIMARY_MODEL' failed: $MODEL_TEST"
    fi
fi

# ============================================
# 8. Schedule Alignment
# ============================================
echo ""
echo "📅 Schedule Alignment"

# Check if cron intervals match expected
EXPECTED_INTERVALS=(
    "critical-services-monitor:600000"
    "websites-monitor:900000"
    "morning-briefing:43200000"
    "daily-maintenance:86400000"
    "daily-backup:86400000"
    "nightly-proactive-task:86400000"
)

for entry in "${EXPECTED_INTERVALS[@]}"; do
    JOB_NAME="${entry%%:*}"
    EXPECTED_MS="${entry##*:}"

    ACTUAL_MS=$(python3 -c "
import json
d = json.load(open('/mnt/overpower/apps/dev/agl/openclaw-repo/config/cron/jobs.json'))
for j in d.get('jobs', []):
    if '${JOB_NAME}' in j.get('name', ''):
        print(j.get('schedule',{}).get('everyMs', 'NOT_FOUND'))
        break
" 2>/dev/null)

    if [ "$ACTUAL_MS" = "$EXPECTED_MS" ]; then
        pass "$JOB_NAME schedule: ${ACTUAL_MS}ms"
    elif [ "$ACTUAL_MS" = "NOT_FOUND" ]; then
        warn "$JOB_NAME: not found in cron config"
    else
        warn "$JOB_NAME schedule mismatch: expected ${EXPECTED_MS}ms, got ${ACTUAL_MS}ms"
    fi
done

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

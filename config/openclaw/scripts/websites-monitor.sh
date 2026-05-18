#!/bin/bash
# websites-monitor.sh — versão corrigida 2026-04-12
# IPs corrigidos: n8n → LAN AGLSRV1 CT202, wg-easy → FGSRV06 Tailscale

LOG_FILE="/root/.openclaw/logs/websites-monitor.log"
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S GMT%z")

source /root/.openclaw/litellm-master.secret.env 2>/dev/null || echo "⚠️ LiteLLM secrets not loaded" >&2
source /root/.openclaw/.env 2>/dev/null || true

echo "========================================" >> "$LOG_FILE"
echo "[$TIMESTAMP] WEBSITES MONITOR - AGL" >> "$LOG_FILE"

# Google
curl -s -o /dev/null -w "✅ Google (https://google.com): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" https://google.com >> "$LOG_FILE" 2>/dev/null || echo "❌ Google (https://google.com): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# GitHub
curl -s -o /dev/null -w "✅ GitHub (https://github.com): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" https://github.com >> "$LOG_FILE" 2>/dev/null || echo "❌ GitHub (https://github.com): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# OpenAI
curl -s -o /dev/null -w "✅ OpenAI (https://openai.com): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" https://openai.com >> "$LOG_FILE" 2>/dev/null || echo "❌ OpenAI (https://openai.com): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# Anthropic
curl -s -o /dev/null -w "✅ Anthropic (https://anthropic.com): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" https://anthropic.com >> "$LOG_FILE" 2>/dev/null || echo "❌ Anthropic (https://anthropic.com): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# DeepSeek
curl -s -o /dev/null -w "✅ DeepSeek (https://deepseek.com): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" https://deepseek.com >> "$LOG_FILE" 2>/dev/null || echo "❌ DeepSeek (https://deepseek.com): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# LiteLLM (auth+models) — local loopback
LITELLM_AUTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://127.0.0.1:4000/v1/models 2>/dev/null)
if [ "$LITELLM_AUTH_CODE" = "200" ]; then
  echo "✅ LiteLLM (auth+models): HTTP $LITELLM_AUTH_CODE" >> "$LOG_FILE"
else
  echo "❌ LiteLLM (auth+models): HTTP $LITELLM_AUTH_CODE" >> "$LOG_FILE"
fi

# n8n — AGLSRV1 CT202 LAN (NÃO usar Tailscale/Cloudflare IP)
N8N_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: AGL-Monitor/1.0" http://192.168.0.202:5678/healthz -m 10 2>/dev/null)
if [ "$N8N_CODE" = "200" ]; then
  echo "✅ n8n (http://192.168.0.202:5678/healthz): HTTP $N8N_CODE" >> "$LOG_FILE"
else
  echo "❌ n8n (http://192.168.0.202:5678/healthz): HTTP ${N8N_CODE:-TIMEOUT}/UNREACHABLE" >> "$LOG_FILE"
fi

# wg-easy — FGSRV06 Tailscale
WG_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "User-Agent: AGL-Monitor/1.0" http://100.83.51.9:51821/ -m 10 2>/dev/null)
if [ "$WG_CODE" = "200" ] || [ "$WG_CODE" = "302" ]; then
  echo "✅ wg-easy (http://100.83.51.9:51821/): HTTP $WG_CODE" >> "$LOG_FILE"
else
  echo "❌ wg-easy (http://100.83.51.9:51821/): HTTP ${WG_CODE:-TIMEOUT}/UNREACHABLE" >> "$LOG_FILE"
fi

# OpenAI API
curl -s -o /dev/null -w "✅ OpenAI API (https://api.openai.com/v1/models): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/models >> "$LOG_FILE" 2>/dev/null || echo "❌ OpenAI API (https://api.openai.com/v1/models): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

# Anthropic API
curl -s -o /dev/null -w "⚠️ Anthropic API (https://api.anthropic.com/v1/messages): HTTP %{http_code}\n" -H "User-Agent: AGL-Monitor/1.0" -H "Authorization: Bearer $ANTHROPIC_API_KEY" https://api.anthropic.com/v1/messages >> "$LOG_FILE" 2>/dev/null || echo "❌ Anthropic API (https://api.anthropic.com/v1/messages): TIMEOUT/UNREACHABLE" >> "$LOG_FILE"

echo "----------------------------------------" >> "$LOG_FILE"
echo "[$TIMESTAMP] Fim da verificação" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# Manter apenas as últimas 500 linhas do log
tail -n 500 "$LOG_FILE" > "${LOG_FILE}.tmp"
mv "${LOG_FILE}.tmp" "$LOG_FILE"

exit 0

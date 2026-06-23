#!/usr/bin/env bash
# Smoke AGLz quartet no CT188 — LiteLLM, Honcho, llm-wiki, Telegram, Jarvis API.
# Uso: bash smoke-hermes-aglz-quartet.sh
set -euo pipefail

LITELLM_URL="${LITELLM_URL:-http://100.125.249.8:4000}"
HONCHO_URL="${HONCHO_URL:-http://100.124.98.54:8000}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
FAIL=0

ok() { echo "OK  $*"; }
fail() { echo "FAIL $*" >&2; FAIL=1; }

echo "=== LiteLLM ==="
curl -sf -m5 "${LITELLM_URL}/health/liveliness" >/dev/null && ok "${LITELLM_URL}" || fail "${LITELLM_URL}"

echo "=== Honcho ==="
curl -sf -m5 "${HONCHO_URL}/health" | grep -q '"ok"' && ok "${HONCHO_URL}" || fail "${HONCHO_URL}"

echo "=== llm-wiki ==="
if [[ -r /opt/agl-llm-wiki/wiki/index.md ]]; then
  ok "/opt/agl-llm-wiki/wiki/index.md"
else
  fail "llm-wiki missing — correr ensure-llm-wiki-ct188.sh"
fi

echo "=== Jarvis API ==="
curl -sf -m5 http://127.0.0.1:8642/health | grep -q hermes-agent && ok ":8642" || fail ":8642"

echo "=== Telegram (gateway_state) ==="
for agent in jarvis elon satya werner curator orion; do
  if [[ "${agent}" == jarvis ]]; then
    f="${HERMES_ROOT}/data/gateway_state.json"
  else
    f="${HERMES_ROOT}/profiles/${agent}/gateway_state.json"
  fi
  if [[ ! -f "${f}" ]]; then
    fail "${agent}: sem gateway_state.json"
    continue
  fi
  state="$(python3 -c "import json; print(json.load(open('${f}'))['platforms']['telegram']['state'])")"
  if [[ "${state}" == connected ]]; then
    ok "${agent} telegram=${state}"
  else
    fail "${agent} telegram=${state}"
  fi
done

echo "=== llm-wiki no contentor (rw) ==="
docker exec agl-hermes-jarvis test -r /opt/llm-wiki/wiki/index.md && ok "mount /opt/llm-wiki (jarvis read)" || fail "mount /opt/llm-wiki"
for agent in jarvis elon satya werner curator orion; do
  c="agl-hermes-${agent}"
  if docker exec -u hermes "${c}" sh -c 'touch /opt/llm-wiki/wiki/.rw-smoke && rm -f /opt/llm-wiki/wiki/.rw-smoke' 2>/dev/null; then
    ok "${agent} escreve em /opt/llm-wiki/wiki"
  else
    fail "${agent} sem rw em /opt/llm-wiki — compose :rw + recreate"
  fi
done

echo "=== Curator profile ==="
CURATOR_CFG="${HERMES_ROOT}/profiles/curator/config.yaml"
[[ -f "${CURATOR_CFG}" ]] || CURATOR_CFG="${HERMES_ROOT}/data/profiles/curator/config.yaml"
if [[ -f "${CURATOR_CFG}" ]]; then
  ok "curator config.yaml"
else
  fail "curator — bootstrap-hermes-curator-profile-ct188.sh"
fi
CURATOR_SKILL="${HERMES_ROOT}/profiles/curator/skills/research/llm-wiki"
[[ -e "${CURATOR_SKILL}" ]] || CURATOR_SKILL="${HERMES_ROOT}/data/profiles/curator/skills/research/llm-wiki"
if [[ -f "${CURATOR_SKILL}/SKILL.md" ]] || [[ -L "${CURATOR_SKILL}" ]]; then
  ok "curator skill llm-wiki"
else
  fail "curator llm-wiki — fix-curator-llm-wiki-skill-ct188.sh"
fi

echo "=== Orion profile ==="
if [[ -f "${HERMES_ROOT}/profiles/orion/config.yaml" ]]; then
  ok "orion config.yaml"
else
  fail "orion — bootstrap-hermes-orion-profile-ct188.sh"
fi
if [[ -f "${HERMES_ROOT}/profiles/orion/skills/agl-media/SKILL.md" ]]; then
  ok "orion skill agl-media"
else
  fail "orion agl-media skill"
fi
docker ps --format '{{.Names}}' | grep -q agl-hermes-curator && ok "container agl-hermes-curator" || fail "container curator — configure-hermes-curator-orion-ct188.sh"
docker ps --format '{{.Names}}' | grep -q agl-hermes-orion && ok "container agl-hermes-orion" || fail "container orion — configure-hermes-curator-orion-ct188.sh"

echo "=== NFS dev tree (jarvis) ==="
docker exec agl-hermes-jarvis test -d /mnt/overpower/apps/dev/agl && ok "mount /mnt/overpower/apps/dev" || fail "mount /mnt/overpower/apps/dev"
docker exec agl-hermes-jarvis bash -lc 'touch /mnt/overpower/apps/dev/.hermes-rw-smoke 2>/dev/null && rm -f /mnt/overpower/apps/dev/.hermes-rw-smoke' && ok "mount rw /mnt/overpower/apps/dev" || fail "mount rw /mnt/overpower/apps/dev"

echo "=== Voice (jarvis) ==="
if docker exec agl-hermes-jarvis /opt/hermes/.venv/bin/python3 -c "import edge_tts, faster_whisper, langfuse" 2>/dev/null; then
  ok "voice deps (edge-tts, faster-whisper, langfuse)"
else
  fail "voice deps — correr enable-hermes-voice-ct188.sh"
fi
if docker exec agl-hermes-jarvis grep -q 'auto_tts: true' /opt/data/config.yaml 2>/dev/null; then
  ok "jarvis auto_tts=true"
else
  fail "jarvis auto_tts"
fi
if docker exec agl-hermes-jarvis /opt/hermes/.venv/bin/edge-tts --voice pt-BR-FranciscaNeural --text smoke --write-media /tmp/smoke-tts.mp3 2>/dev/null \
  && docker exec agl-hermes-jarvis test -s /tmp/smoke-tts.mp3; then
  ok "edge-tts synthesis"
else
  fail "edge-tts synthesis"
fi
if grep -q 'auto_tts: true' "${CURATOR_CFG}" 2>/dev/null; then
  ok "curator auto_tts=true"
else
  fail "curator auto_tts — correr enable-hermes-voice-ct188.sh"
fi

echo "=== Linear CLI ==="
docker exec agl-hermes-jarvis linear --version >/dev/null 2>&1 && ok "linear-cli" || fail "linear-cli"

if grep -q '^LINEAR_API_KEY=.\+' "${HERMES_ROOT}/data/.env" 2>/dev/null; then
  ok "LINEAR_API_KEY definida (jarvis .env)"
  if docker exec agl-hermes-jarvis bash -lc 'LINEAR_API_KEY=$(grep ^LINEAR_API_KEY= /opt/data/.env | cut -d= -f2-) linear me --json 2>/dev/null | grep -q email'; then
    ok "linear me"
  else
    fail "linear me (validar LINEAR_API_KEY)"
  fi
else
  echo "WARN LINEAR_API_KEY em falta — ver docs/LINEAR-MCP-INTEGRATION.md"
fi

echo ""
if [[ "${FAIL}" -eq 0 ]]; then
  echo "Smoke quartet: PASS"
else
  echo "Smoke quartet: FAIL"
  exit 1
fi

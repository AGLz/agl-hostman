#!/usr/bin/env bash
# Instala deps de voz (STT local + gravação) e activa TTS/STT no config Hermes CT188.
#
# Uso (root no CT188):
#   bash enable-hermes-voice-ct188.sh
#   bash enable-hermes-voice-ct188.sh /mnt/overpower/apps/dev/agl/agl-hostman

set -euo pipefail

AGL_HOSTMAN="${1:-/mnt/overpower/apps/dev/agl/agl-hostman}"
HERMES_ROOT="${HERMES_ROOT:-/opt/agl-hermes}"
CONTAINER="${HERMES_JARVIS_CONTAINER:-agl-hermes-jarvis}"
MARKER="# hermes-voice-ct188"

profile_dirs() {
  echo "${HERMES_ROOT}/data"
  for agent in elon satya werner; do
    echo "${HERMES_ROOT}/profiles/${agent}"
  done
  # Curator vive sob data/profiles (gateway no jarvis, não contentor separado)
  echo "${HERMES_ROOT}/data/profiles/curator"
}

echo "=== 1/3 Instalar extra [voice] no venv (${CONTAINER}) ==="
docker exec -u root "${CONTAINER}" bash -lc '
set -euo pipefail
if ! dpkg -s libportaudio2 >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq libportaudio2 portaudio19-dev
fi
cd /opt/hermes
uv sync --frozen --no-install-project --extra all --extra messaging --extra voice --extra edge-tts
uv pip install -e .
uv pip install "langfuse>=4.7,<5" 2>/dev/null || uv pip install langfuse
chown -R hermes:hermes /opt/hermes/.venv
/opt/hermes/.venv/bin/python3 -c "
import edge_tts, faster_whisper, sounddevice, numpy, langfuse
print(\"OK voice deps:\", edge_tts.__version__, numpy.__version__)
"
'

echo "=== 2/3 Activar voice/stt/tts nos profiles ==="
for pdir in $(profile_dirs); do
  cfg="${pdir}/config.yaml"
  [[ -f "${cfg}" ]] || continue
  python3 - "${cfg}" <<'PY'
import sys
from pathlib import Path
import yaml

path = Path(sys.argv[1])
cfg = yaml.safe_load(path.read_text()) or {}

voice = cfg.setdefault("voice", {})
if not isinstance(voice, dict):
    voice = {}
    cfg["voice"] = voice
voice["auto_tts"] = True
voice.setdefault("beep_enabled", True)
voice.setdefault("max_recording_seconds", 120)

stt = cfg.setdefault("stt", {})
if not isinstance(stt, dict):
    stt = {}
    cfg["stt"] = stt
stt["enabled"] = True
stt.setdefault("provider", "local")
local = stt.setdefault("local", {})
if isinstance(local, dict):
    local.setdefault("model", "base")

tts = cfg.setdefault("tts", {})
if not isinstance(tts, dict):
    tts = {}
    cfg["tts"] = tts
tts.setdefault("provider", "edge")
edge = tts.setdefault("edge", {})
if isinstance(edge, dict):
    edge.setdefault("voice", "pt-BR-FranciscaNeural")

path.write_text(yaml.safe_dump(cfg, sort_keys=False, allow_unicode=True), encoding="utf-8")
print("OK voice config", path)
PY
  chown -R 10000:10000 "${pdir}" 2>/dev/null || true
done

echo "=== 3/4 PortAudio + voice deps nos outros gateways ==="
for c in agl-hermes-elon agl-hermes-satya agl-hermes-werner; do
  docker exec -u root "${c}" bash -lc '
    if ! dpkg -s libportaudio2 >/dev/null 2>&1; then
      apt-get update -qq && apt-get install -y -qq libportaudio2 portaudio19-dev
    fi
    cd /opt/hermes
    uv sync --frozen --no-install-project --extra all --extra messaging --extra voice --extra edge-tts
    uv pip install -e . >/dev/null
    uv pip install "langfuse>=4.7,<5" 2>/dev/null || true
  ' && echo "OK voice deps ${c}" || echo "WARN ${c}" >&2
done

echo "=== 4/4 Reiniciar gateways Hermes ==="
cd "${HERMES_ROOT}"
docker compose -f docker-compose.aglz-quartet.yml restart hermes-jarvis hermes-elon hermes-satya hermes-werner

echo "A aguardar jarvis..."
for _ in $(seq 1 45); do
  code="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 3 http://127.0.0.1:9119/ 2>/dev/null || echo 000)"
  if [[ "${code}" == "200" ]]; then
    echo "OK Web UI :9119"
    break
  fi
  sleep 2
done

docker exec "${CONTAINER}" /opt/hermes/.venv/bin/hermes doctor 2>&1 | grep -E "tts|voice|stt|faster" || true
echo ""
echo "Voz activa: STT=local (faster-whisper), TTS=edge, auto_tts=true"
echo "Teste: mensagem de voz no Telegram ou \`hermes\` interactivo com Ctrl+B."

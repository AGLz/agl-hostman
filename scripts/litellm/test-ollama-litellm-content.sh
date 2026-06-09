#!/usr/bin/env bash
# Smoke: Ollama via LiteLLM devolve content não vazio (Qwen3 think=false no callback).
set -euo pipefail

URL="${LITELLM_URL:-http://100.125.249.8:4000}"
KEY="${LITELLM_MASTER_KEY:-}"
if [[ -z "$KEY" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  # shellcheck source=/dev/null
  KEY="$("$SCRIPT_DIR/_litellm-master-key.sh" || true)"
fi
if [[ -z "$KEY" ]]; then
  echo "Defina LITELLM_MASTER_KEY." >&2
  exit 1
fi

MODEL="${1:-agl-primary}"
BODY="$(cat <<EOF
{"model":"${MODEL}","messages":[{"role":"user","content":"Responde só: OK"}],"max_tokens":32,"stream":false}
EOF
)"

resp="$(curl -sf --max-time 120 -X POST "${URL}/v1/chat/completions" \
  -H "Authorization: Bearer ${KEY}" \
  -H "Content-Type: application/json" \
  -d "$BODY")"

python3 - "$resp" <<'PY'
import json, sys
d = json.loads(sys.argv[1])
msg = d.get("choices", [{}])[0].get("message", {})
content = (msg.get("content") or "").strip()
reasoning = (msg.get("reasoning_content") or "").strip()
print("model:", d.get("model"))
print("content:", repr(content[:120]))
print("reasoning_len:", len(reasoning))
if not content:
    raise SystemExit("FAIL: content vazio")
print("OK")
PY

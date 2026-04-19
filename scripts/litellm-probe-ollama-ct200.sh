#!/usr/bin/env bash
# Prova HTTP ao Ollama no CT200 (AGLSRV1) a partir do contentor litellm-proxy no agldv03.
# Uso no agldv03: OLLAMA_URL=http://192.168.0.200:11434 bash scripts/litellm-probe-ollama-ct200.sh
set -euo pipefail
OLLAMA_URL="${OLLAMA_URL:-http://192.168.0.200:11434}"
docker exec litellm-proxy python3 -c "
import urllib.request
u='${OLLAMA_URL}/api/tags'
try:
    r = urllib.request.urlopen(u, timeout=8)
    b = r.read()
    print('OK', r.status, 'bytes', len(b))
    print(b[:240].decode('utf-8', errors='replace'))
except Exception as e:
    print('FAIL', e)
    raise
"

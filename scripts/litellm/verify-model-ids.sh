#!/usr/bin/env bash
# Lista rápida: confirma que IDs esperados aparecem em /v1/models (LiteLLM local).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
K="$("$DIR/_litellm-master-key.sh")"
CURL_AUTH=()
[[ -n "$K" ]] && CURL_AUTH=(-H "Authorization: Bearer ${K}")
raw="$(curl -sS --max-time 30 "${CURL_AUTH[@]}" http://127.0.0.1:4000/v1/models)"
python3 -c "import json,sys; d=json.loads(sys.argv[1]); ids=[x.get('id','') for x in d.get('data',[])]; want=['google/gemini-2.5-flash-lite','openrouter/meta-llama/llama-3.3-70b-instruct:free','openrouter/z-ai/glm-4.5-air:free','or-glm-4.5-air-free'];
for w in want: print(w, 'OK' if w in ids else 'MISSING')" "$raw"

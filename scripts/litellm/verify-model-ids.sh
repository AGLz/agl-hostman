#!/usr/bin/env bash
# Lista rápida: confirma que IDs esperados aparecem em /v1/models (LiteLLM local).
set -euo pipefail
K="$(grep -m1 '^LITELLM_MASTER_KEY=' /opt/litellm/.env | cut -d= -f2-)"
K="${K//\"/}"
raw="$(curl -sS -H "Authorization: Bearer ${K}" http://127.0.0.1:4000/v1/models)"
python3 -c "import json,sys; d=json.loads(sys.argv[1]); ids=[x.get('id','') for x in d.get('data',[])]; want=['google/gemini-2.5-flash-lite:free','google/gemini-2.5-flash-lite','openrouter/google/gemini-2.5-flash-lite:free'];
for w in want: print(w, 'OK' if w in ids else 'MISSING')" "$raw"

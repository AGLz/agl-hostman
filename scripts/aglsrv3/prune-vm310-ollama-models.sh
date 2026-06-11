#!/usr/bin/env bash
# Remove modelos Ollama não usados na VM310 (libertar disco).
# Mantém: qwen3:8b, qwen3:4b, gemma3:4b, llama3.1:8b (~16 GB).
#
# Uso (AGLSRV3):
#   bash scripts/aglsrv3/prune-vm310-ollama-models.sh
#   DRY_RUN=1 bash scripts/aglsrv3/prune-vm310-ollama-models.sh
#
# Uso directo na guest (root):
#   HOME=/usr/share/ollama bash scripts/aglsrv3/prune-vm310-ollama-models.sh --local
set -euo pipefail

VMID="${VMID:-310}"
AGLSRV3="${AGLSRV3:-root@100.123.5.81}"
DRY_RUN="${DRY_RUN:-0}"

KEEP=(
  qwen3:8b
  qwen3:4b
  gemma3:4b
  llama3.1:8b
)

REMOVE=(
  qwen3.5:9b
  gemma2:9b
  deepseek-r1:8b
  command-r7b:latest
  granite3.3:8b
  qwen2.5:7b
  qwen2.5-coder:7b
  mistral:7b
)

log() { printf '[prune-vm310] %s\n' "$*" >&2; }

prune_local() {
  export HOME="${HOME:-/usr/share/ollama}"
  local ollama_bin="${OLLAMA_BIN:-/usr/local/bin/ollama}"
  for m in "${REMOVE[@]}"; do
    if [[ "$DRY_RUN" == "1" ]]; then
      log "DRY_RUN: ollama rm $m"
      continue
    fi
    log "ollama rm $m"
    "$ollama_bin" rm "$m" 2>/dev/null || log "AVISO: $m não estava instalado"
  done
  curl -sf http://127.0.0.1:11434/api/tags | python3 -c "
import json,sys
d=json.load(sys.stdin)
ms=sorted(d.get('models',[]), key=lambda x:x.get('size',0), reverse=True)
print(len(ms), 'modelos:', ', '.join(m['name'] for m in ms))
"
  df -h / | tail -1
}

prune_remote() {
  local remove_json
  remove_json="$(printf '%s\n' "${REMOVE[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"
  local keep_json
  keep_json="$(printf '%s\n' "${KEEP[@]}" | python3 -c 'import json,sys; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')"

  ssh -o BatchMode=yes "$AGLSRV3" bash -s -- "$VMID" "$DRY_RUN" "$remove_json" "$keep_json" <<'REMOTE'
set -euo pipefail
VMID="$1"
DRY_RUN="$2"
REMOVE_JSON="$3"
KEEP_JSON="$4"
qm guest exec "$VMID" -- bash -lc "
set -e
export HOME=/usr/share/ollama
OLL=/usr/local/bin/ollama
REMOVE=(\$(python3 -c 'import json,sys; print(\" \".join(json.loads(sys.argv[1])))' '$REMOVE_JSON'))
KEEP=(\$(python3 -c 'import json,sys; print(\" \".join(json.loads(sys.argv[1])))' '$KEEP_JSON'))
echo \"Manter: \${KEEP[*]}\"
for m in \"\${REMOVE[@]}\"; do
  if [[ '$DRY_RUN' == '1' ]]; then echo \"DRY_RUN: rm \$m\"; continue; fi
  echo \"=== rm \$m ===\"
  \$OLL rm \"\$m\" 2>/dev/null || echo \"WARN: \$m\"
done
echo \"=== remaining ===\"
curl -sf http://127.0.0.1:11434/api/tags | python3 -c \"import json,sys;d=json.load(sys.stdin);print(len(d.get('models',[])),'models');[print(m['name']) for m in d.get('models',[])]\"
df -h / | tail -1
du -sh /usr/share/ollama/.ollama/models
"
REMOTE
}

main() {
  if [[ "${1:-}" == "--local" ]]; then
    prune_local
    return
  fi
  log "Prune VM$VMID via $AGLSRV3 (DRY_RUN=$DRY_RUN)"
  prune_remote
}

main "$@"

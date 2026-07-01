#!/usr/bin/env bash
# Corrige ccll() no ~/.zshrc: URL CT186 + chave real + modelo agl-primary (glm-5 dá timeout no proxy).
set -euo pipefail

ZSHRC="${1:-$HOME/.zshrc}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEY_HELPER="${REPO_ROOT}/.claude/helpers/get-litellm-key.sh"

if [[ ! -f "$ZSHRC" ]]; then
  echo "ERRO: $ZSHRC não encontrado" >&2
  exit 1
fi

python3 - "$ZSHRC" "$KEY_HELPER" <<'PY'
import re
import sys
from pathlib import Path

zshrc = Path(sys.argv[1])
key_helper = sys.argv[2]
text = zshrc.read_text(encoding="utf-8")

new_fn = f'''ccll () {{
    export MODEL_ROBUST="zai-glm-5"
    export MODEL_FAST="zai-glm-flash"
    export MODEL_BASE_URL="${{LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}}"
    if [[ -z "${{LITELLM_MASTER_KEY:-}}" && -r "${{HOME}}/.openclaw/litellm-master.secret.env" ]]; then
      source "${{HOME}}/.openclaw/litellm-master.secret.env"
    fi
    export MODEL_AUTH_TOKEN="${{LITELLM_MASTER_KEY:-$({key_helper} 2>/dev/null)}}"
    cc_envs
    echo "✓ LiteLLM configurado: $MODEL_BASE_URL (zai-glm-5 / zai-glm-flash)"
}}'''

pattern = re.compile(
    r"(?:ccll|cclitellm)\s*\(\s*\)\s*\{[^}]*export MODEL_BASE_URL[^}]*cc_envs[^}]*\}",
    re.DOTALL,
)

if not pattern.search(text):
    print("AVISO: bloco ccll() não encontrado — nada alterado", file=sys.stderr)
    sys.exit(0)

updated = pattern.sub(new_fn, text, count=1)
zshrc.write_text(updated, encoding="utf-8")
print(f"OK: ccll() atualizado em {zshrc}")
PY

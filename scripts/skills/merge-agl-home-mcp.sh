#!/usr/bin/env bash
# Merge MCP AGL (template sanitizado) em ~/.claude/mcp.json e ~/.cursor/mcp.json.
# Não sobrescreve secrets já presentes; não copia API keys literais.
#
# Uso:
#   bash scripts/skills/merge-agl-home-mcp.sh
#   MERGE_CURSOR=0 bash scripts/skills/merge-agl-home-mcp.sh   # só Claude
#   MERGE_CLAUDE=0 bash scripts/skills/merge-agl-home-mcp.sh   # só Cursor
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TEMPLATE="${AGL_HOME_MCP_TEMPLATE:-$HOSTMAN_ROOT/config/templates/mcp/agl-home-mcp.json.example}"
LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
MERGE_CLAUDE="${MERGE_CLAUDE:-1}"
MERGE_CURSOR="${MERGE_CURSOR:-1}"

log() { echo "[merge-home-mcp] $*"; }
ok() { echo "[OK] $*"; }
warn() { echo "[WARN] $*" >&2; }

[[ -f "$TEMPLATE" ]] || { echo "Template em falta: $TEMPLATE" >&2; exit 1; }

merge_one() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  [[ -f "$dest" ]] || echo '{"mcpServers":{}}' >"$dest"

  python3 - "$TEMPLATE" "$dest" "$LLM_WIKI_DIR" <<'PY'
import json, os, sys, re
from copy import deepcopy

template_path, dest_path, wiki = sys.argv[1], sys.argv[2], sys.argv[3]
with open(template_path, encoding="utf-8") as f:
    tmpl = json.load(f)
with open(dest_path, encoding="utf-8") as f:
    dest = json.load(f)

servers = dest.setdefault("mcpServers", {})
added, skipped = [], []

def looks_like_placeholder(val: str) -> bool:
    if not isinstance(val, str):
        return False
    return bool(re.search(r"\$\{[A-Z0-9_:-]+\}", val)) or val in ("", "changeme", "YOUR_KEY")

def has_real_secret(cfg: dict) -> bool:
    env = cfg.get("env") or {}
    for v in env.values():
        if isinstance(v, str) and v and not looks_like_placeholder(v):
            # Heurística: tokens longos / keys
            if len(v) >= 16 and not v.startswith("http") and "/" not in v[:8]:
                return True
    # portainer -token arg
    args = cfg.get("args") or []
    for i, a in enumerate(args):
        if a in ("-token", "--token") and i + 1 < len(args):
            tok = args[i + 1]
            if isinstance(tok, str) and tok and not looks_like_placeholder(tok):
                return True
    return False

# Normalizar alias dokploy-mcp → manter ambos se já existir dokploy-mcp
if "dokploy-mcp" in servers and "dokploy" not in servers:
    servers["dokploy"] = deepcopy(servers["dokploy-mcp"])
    added.append("dokploy(from dokploy-mcp)")

for name, cfg in (tmpl.get("mcpServers") or {}).items():
    cfg = deepcopy(cfg)
    # Paths llm-wiki dinâmicos
    if name == "llm-wiki-fs":
        cfg["args"] = [
            "-y",
            "@modelcontextprotocol/server-filesystem",
            f"{wiki}/wiki",
            f"{wiki}/raw",
        ]

    if name not in servers:
        servers[name] = cfg
        added.append(name)
        continue

    existing = servers[name]
    # Não tocar se já tem secret real
    if has_real_secret(existing):
        skipped.append(f"{name}:keep-secrets")
        # Ainda assim garantir type/command se em falta
        for k in ("type", "command", "url", "description"):
            if k in cfg and k not in existing:
                existing[k] = cfg[k]
        continue

    # Merge raso: preencher chaves em falta; não apagar env existente
    for k, v in cfg.items():
        if k == "env":
            env = existing.setdefault("env", {})
            for ek, ev in (v or {}).items():
                if ek not in env or looks_like_placeholder(str(env.get(ek, ""))):
                    # Só escrever placeholder se destino vazio/placeholder
                    if ek not in env or looks_like_placeholder(str(env.get(ek, ""))):
                        if looks_like_placeholder(str(ev)):
                            env.setdefault(ek, ev)
                        else:
                            env[ek] = ev
        elif k not in existing:
            existing[k] = v
    skipped.append(f"{name}:merged")

with open(dest_path, "w", encoding="utf-8") as f:
    json.dump(dest, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"dest={dest_path}")
print(f"added={','.join(added) or '-'}")
print(f"touched={','.join(skipped) or '-'}")
print(f"servers={len(servers)}")
PY
}

if [[ "$MERGE_CLAUDE" == "1" ]]; then
  merge_one "${HOME}/.claude/mcp.json"
  ok "claude mcp → ${HOME}/.claude/mcp.json"
fi
if [[ "$MERGE_CURSOR" == "1" ]]; then
  merge_one "${HOME}/.cursor/mcp.json"
  ok "cursor mcp → ${HOME}/.cursor/mcp.json"
fi

# settings LiteLLM / Anthropic examples → home se em falta
DOT_CLAUDE="$HOSTMAN_ROOT/config/dotfiles/linux/claude"
for pair in "settings-litellm.json.example:settings-litellm.json" "settings-anthropic.json.example:settings-anthropic.json"; do
  src="${DOT_CLAUDE}/${pair%%:*}"
  dst="${HOME}/.claude/${pair##*:}"
  if [[ -f "$src" && ! -f "$dst" ]]; then
    /usr/bin/install -m 0644 "$src" "$dst"
    ok "copied $dst"
  fi
done

ok "merge-agl-home-mcp concluído"

# Variáveis AGL partilhadas — source em ~/.config/agl/env.sh (symlink via install).
# Tailscale aglfs1: 100.69.187.105 | LiteLLM CT186: 100.125.249.8:4000

export LITELLM_GATEWAY_URL="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-$LITELLM_GATEWAY_URL}"
export LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
export AGL_HOME_SYNC_ROOT="${AGL_HOME_SYNC_ROOT:-/mnt/overpower/apps/dev/agl/agl-home-sync}"
export AGL_HOSTMAN_ROOT="${AGL_HOSTMAN_ROOT:-/mnt/overpower/apps/dev/agl/agl-hostman}"

_hn="$(hostname -s 2>/dev/null || hostname)"
if [[ "$_hn" =~ ^agldv ]]; then
  export AGL_HOME_USER="${AGL_HOME_USER:-$_hn}"
  export CURSOR_EXPORT_HOST="${CURSOR_EXPORT_HOST:-$_hn}"
fi

# Montagem dedicada aglfs1 (futuro): descomentar quando /mnt/agl-home-sync existir
# export AGL_HOME_SYNC_ROOT="/mnt/agl-home-sync"

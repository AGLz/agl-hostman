#!/usr/bin/env bash
# Propaga Claude Code shell (CC_PROVIDER, ccll, ccs, settings-*) para todos os AGLDV*.
#
# Uso (raiz do repo):
#   ./scripts/ruflo/propagate-claude-code-shell-all-hosts.sh
#   ./scripts/ruflo/propagate-claude-code-shell-all-hosts.sh agldv03 agldv05
#   ZSHRC_SOURCE_HOST=100.113.9.98 SKIP_ZSHRC=1 ./scripts/ruflo/propagate-claude-code-shell-all-hosts.sh
#
# Default origem ~/.zshrc: IP Tailscale do host actual; senão agldv04.
# Ref: llm-wiki — [[agl-hostman — Claude Code Shell zsh]]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO_PATH_REMOTE="/mnt/overpower/apps/dev/agl/agl-hostman"
SKIP_ZSHRC="${SKIP_ZSHRC:-0}"
VALIDATE="${VALIDATE:-1}"

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"
HOST_IPS[fgsrv06]="100.83.51.9"

if [[ -z "${ZSHRC_SOURCE_HOST:-}" ]]; then
  ZSHRC_SOURCE_HOST="$(tailscale ip -4 2>/dev/null | head -1 || true)"
  ZSHRC_SOURCE_HOST="${ZSHRC_SOURCE_HOST:-100.113.9.98}"
fi

[[ $# -gt 0 ]] && TARGETS=("$@") || TARGETS=(agldv02 agldv03 agldv05 agldv06 agldv07 agldv12 fgsrv06)

SETTINGS_LITELLM_SRC="${SETTINGS_LITELLM_SRC:-$HOME/.claude/settings-litellm.json}"
SETTINGS_ANTHROPIC_SRC="${SETTINGS_ANTHROPIC_SRC:-$HOME/.claude/settings-anthropic.json}"
[[ -f "$SETTINGS_LITELLM_SRC" ]] || SETTINGS_LITELLM_SRC="$REPO_ROOT/config/templates/claude-code/settings-litellm.json.example"
[[ -f "$SETTINGS_ANTHROPIC_SRC" ]] || SETTINGS_ANTHROPIC_SRC="$REPO_ROOT/config/templates/claude-code/settings-anthropic.json.example"

REPO_SYNC_ITEMS=(
  ".claude/settings.json"
  ".claude/settings.litellm.json"
  ".claude/helpers/get-litellm-key.sh"
  "config/openclaw/zshrc-openclaw.env"
  "config/openclaw/zshrc-openclaw-litellm.env"
  "config/openclaw/zshrc-openclaw-direct.env"
  "config/templates/zshrc-claude-code.template.zsh"
  "config/templates/claude-code"
  "scripts/ccll.sh"
  "scripts/ruflo/propagate-claude-code-shell-all-hosts.sh"
)

echo "=============================================="
echo "  Claude Code shell → AGLDV* (propagação)"
echo "=============================================="
echo "  Repo:      $REPO_ROOT"
echo "  Origem zsh: root@${ZSHRC_SOURCE_HOST}"
echo "  Alvos:     ${TARGETS[*]}"
echo ""

tmp_zsh=""
if [[ "$SKIP_ZSHRC" != "1" ]]; then
  tmp_zsh="$(mktemp)"
  if ! scp -q -o ConnectTimeout=15 "root@${ZSHRC_SOURCE_HOST}:/root/.zshrc" "$tmp_zsh" 2>/dev/null; then
    echo "ERRO: não foi possível ler ~/.zshrc de ${ZSHRC_SOURCE_HOST}"
    rm -f "$tmp_zsh"
    exit 1
  fi
  echo "OK: ~/.zshrc lido de ${ZSHRC_SOURCE_HOST} ($(wc -l < "$tmp_zsh") linhas)"
  echo ""
fi

for host in "${TARGETS[@]}"; do
  ip="${HOST_IPS[$host]:-}"
  if [[ -z "$ip" ]]; then
    echo "WARN: host '$host' desconhecido — ignorar"
    continue
  fi

  echo "=== $host ($ip) ==="
  if ! ssh -o ConnectTimeout=12 -o BatchMode=yes "root@${ip}" "true" 2>/dev/null; then
    echo "  SKIP: SSH indisponível"
    echo ""
    continue
  fi

  # --- zsh (obrigatório para ~/.zshrc / ccll) ---
  zsh_install="$(ssh "root@${ip}" "
    if command -v zsh >/dev/null 2>&1; then
      echo \"OK: \$(zsh --version | head -1)\"
      exit 0
    fi
    export DEBIAN_FRONTEND=noninteractive
    if command -v apt-get >/dev/null; then
      apt-get update -qq || true
      apt-get install -y zsh
    elif command -v apk >/dev/null; then
      apk add --no-cache zsh
    elif command -v dnf >/dev/null; then
      dnf install -y zsh
    else
      echo 'ERRO: zsh não instalado e gestor de pacotes desconhecido'
      exit 1
    fi
    command -v chsh >/dev/null && chsh -s \"\$(command -v zsh)\" root 2>/dev/null || true
    echo \"INSTALLED: \$(zsh --version | head -1)\"
  " 2>&1)" || zsh_install="ERRO: instalação zsh falhou"
  echo "  zsh: $zsh_install"

  # --- Repo (NFS ou scp) ---
  ssh "root@${ip}" "mkdir -p ${REPO_PATH_REMOTE}/.claude/helpers ${REPO_PATH_REMOTE}/config/openclaw ${REPO_PATH_REMOTE}/config/templates ${REPO_PATH_REMOTE}/scripts/ruflo" 2>/dev/null || true
  for item in "${REPO_SYNC_ITEMS[@]}"; do
    src="$REPO_ROOT/$item"
    [[ -e "$src" ]] || continue
    if [[ -d "$src" ]]; then
      parent="$REPO_PATH_REMOTE/$(dirname "$item")"
      ssh "root@${ip}" "mkdir -p $parent" 2>/dev/null || true
      scp -rq "$src" "root@${ip}:$parent/" 2>/dev/null && echo "  OK repo: $item/"
    else
      ssh "root@${ip}" "mkdir -p ${REPO_PATH_REMOTE}/$(dirname "$item")" 2>/dev/null || true
      scp -q "$src" "root@${ip}:${REPO_PATH_REMOTE}/$item" 2>/dev/null && echo "  OK repo: $item"
    fi
  done

  # --- ~/.claude (home) ---
  ssh "root@${ip}" "umask 077; mkdir -p ~/.claude/helpers"
  scp -q "$SETTINGS_LITELLM_SRC" "root@${ip}:/root/.claude/settings-litellm.json"
  scp -q "$SETTINGS_ANTHROPIC_SRC" "root@${ip}:/root/.claude/settings-anthropic.json"
  ssh "root@${ip}" "
    ln -sf ${REPO_PATH_REMOTE}/.claude/helpers/get-litellm-key.sh ~/.claude/helpers/get-litellm-key.sh 2>/dev/null || \
    ln -sf ${REPO_PATH_REMOTE}/.claude/helpers/get-litellm-key.sh ~/.claude/helpers/get-litellm-key.sh
    # Normalizar apiKeyHelper para path absoluto no home
    if command -v python3 >/dev/null 2>&1; then
      python3 - <<'PY'
import json, pathlib
p = pathlib.Path('/root/.claude/settings-litellm.json')
d = json.loads(p.read_text())
d['apiKeyHelper'] = '/root/.claude/helpers/get-litellm-key.sh'
p.write_text(json.dumps(d, indent=2) + '\n')
PY
    fi
  " 2>/dev/null
  echo "  OK ~/.claude/settings-{litellm,anthropic}.json + symlink key helper"

  # --- OpenClaw env ---
  for f in zshrc-openclaw.env zshrc-openclaw-litellm.env zshrc-openclaw-direct.env; do
    src="$REPO_ROOT/config/openclaw/$f"
    [[ -f "$src" ]] || continue
    ssh "root@${ip}" "umask 077; mkdir -p ~/.openclaw"
    scp -q "$src" "root@${ip}:/root/.openclaw/$f" 2>/dev/null && echo "  OK ~/.openclaw/$f"
  done

  # --- ~/.zshrc ---
  if [[ "$SKIP_ZSHRC" != "1" && -n "$tmp_zsh" ]]; then
    if [[ "$ip" == "$ZSHRC_SOURCE_HOST" ]]; then
      echo "  SKIP ~/.zshrc (host origem)"
    else
      ts="$(date +%Y%m%d%H%M%S)"
      ssh "root@${ip}" "cp -a /root/.zshrc /root/.zshrc.bak.${ts} 2>/dev/null || true"
      scp -q "$tmp_zsh" "root@${ip}:/root/.zshrc"
      ssh "root@${ip}" "
        sed -i 's/cclitellm/ccll/g' /root/.zshrc 2>/dev/null || true
        # Remover bloco openclaw duplicado que chama ccll no loop (mantém definição no fim)
        if grep -q 'source.*zshrc-openclaw.env.*&& ccll && break' /root/.zshrc 2>/dev/null; then
          sed -i 's/&& ccll && break/\\&\\& break/' /root/.zshrc
        fi
      "
      echo "  OK ~/.zshrc (backup .bak.$ts)"
    fi
  else
    ssh "root@${ip}" "
      sed -i 's/cclitellm/ccll/g' /root/.zshrc 2>/dev/null || true
    " 2>/dev/null && echo "  OK sed cclitellm→ccll em ~/.zshrc"
  fi

  # --- Validação ---
  if [[ "$VALIDATE" == "1" ]]; then
    val="$(ssh "root@${ip}" "zsh -fc 'source ~/.zshrc 2>/dev/null; typeset -f ccll ccs _cc_provider_settings_args >/dev/null 2>&1 && echo FUNCS_OK || echo FUNCS_MISSING'" 2>/dev/null || echo "VALIDATE_ERR")"
    echo "  validate: $val"
  fi
  echo ""
done

[[ -n "$tmp_zsh" ]] && rm -f "$tmp_zsh"

echo "=============================================="
echo "  Propagação concluída"
echo "  Teste remoto: zsh -fc 'source ~/.zshrc; ccll; ccs ok'"
echo "=============================================="

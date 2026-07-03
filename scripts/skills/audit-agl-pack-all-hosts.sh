#!/usr/bin/env bash
# Auditoria pack AGL (Six Repos + segundo cérebro + delivery) em AGLDV* e Hermes CT188.
#
# Uso:
#   bash scripts/skills/audit-agl-pack-all-hosts.sh
#   bash scripts/skills/audit-agl-pack-all-hosts.sh --host agldv04
#   bash scripts/skills/audit-agl-pack-all-hosts.sh --json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTMAN_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOSTMAN_NFS="${HOSTMAN_NFS:-/mnt/overpower/apps/dev/agl/agl-hostman}"
LLM_WIKI_NFS="${LLM_WIKI_NFS:-/mnt/overpower/apps/dev/agl/llm-wiki}"
AGLSRV1_HOST="${AGLSRV1_HOST:-root@100.107.113.33}"
CT188_VMID="${CT188_VMID:-188}"
JSON_OUT=0
ONLY_HOST=""

declare -A HOST_IPS
HOST_IPS[agldv02]="100.95.204.85"
HOST_IPS[agldv03]="100.94.221.87"
HOST_IPS[agldv04]="100.113.9.98"
HOST_IPS[agldv05]="100.82.71.49"
HOST_IPS[agldv06]="100.71.229.12"
HOST_IPS[agldv07]="100.64.175.89"
HOST_IPS[agldv12]="100.71.217.115"

SSH=(ssh -o BatchMode=yes -o ConnectTimeout=12 -o StrictHostKeyChecking=accept-new)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host) ONLY_HOST="$2"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help)
      echo "Usage: $(basename "$0") [--host agldvNN] [--json]"
      exit 0
      ;;
    *) echo "Opção: $1" >&2; exit 2 ;;
  esac
done

# Remote audit snippet (runs ON each AGLDV host)
read -r -d '' REMOTE_AUDIT <<'REMOTE' || true
HOSTMAN="/mnt/overpower/apps/dev/agl/agl-hostman"
LLM="/mnt/overpower/apps/dev/agl/llm-wiki"
HN="$(hostname -s 2>/dev/null || hostname)"
echo "HOST=$HN"

check() { [[ -e "$1" ]] && echo "OK:$2" || echo "MISS:$2"; }

# Claude Code global
check "$HOME/.claude/skills/using-superpowers/SKILL.md" "claude:using-superpowers"
check "$HOME/.claude/skills/humanizer/SKILL.md" "claude:humanizer"
check "$HOME/.claude/skills/fact-check/SKILL.md" "claude:fact-check"
check "$HOME/.claude/skills/prompt-improver/SKILL.md" "claude:prompt-improver"
check "$HOME/.claude/skills/obsidian-cli/SKILL.md" "claude:obsidian-cli"
check "$HOME/.claude/skills/reflect-yourself/SKILL.md" "claude:reflect-yourself"
check "$HOME/.claude/skills/mandatory-delivery-pipeline/SKILL.md" "claude:delivery-pipeline"
check "$HOME/.claude/rules/mandatory-delivery-pipeline.md" "claude:delivery-rule"
check "$HOME/.claude/skills/andrej-karpathy-skills/SKILL.md" "claude:karpathy"

# QA + DevSecOps pack
check "$HOME/.claude/skills/agl-stack-testing/SKILL.md" "claude:agl-stack-testing"
check "$HOME/.claude/skills/agl-devsecops/SKILL.md" "claude:agl-devsecops"
check "$HOME/.claude/skills/agl-testing-policy/SKILL.md" "claude:agl-testing-policy"
check "$HOME/.claude/skills/verification-loop/SKILL.md" "claude:verification-loop"
check "$HOME/.claude/skills/e2e-testing/SKILL.md" "claude:e2e-testing"
check "$HOME/.claude/skills/review-security/SKILL.md" "claude:review-security"

# agl-hostman project (Cursor)
check "$HOSTMAN/.cursor/rules/llm-wiki-second-brain.mdc" "proj:llm-wiki-second-brain"
check "$HOSTMAN/.cursor/rules/karpathy-skills.mdc" "proj:karpathy-skills"
check "$HOSTMAN/.cursor/rules/mandatory-delivery-pipeline.mdc" "proj:delivery-pipeline"
check "$HOSTMAN/.cursor/rules/ponytail.mdc" "proj:ponytail"
check "$HOSTMAN/.cursor/rules/learned-memories.mdc" "proj:learned-memories"
check "$HOSTMAN/.cursor/skills/llm-wiki-ingest/SKILL.md" "proj:llm-wiki-ingest"
check "$HOSTMAN/.cursor/skills/humanizer/SKILL.md" "proj:humanizer"
check "$HOSTMAN/.cursor/content-skills-sync-state.json" "proj:content-skills-state"

# QA + DevSecOps (project)
check "$HOSTMAN/.cursor/skills/agl-stack-testing/SKILL.md" "proj:agl-stack-testing"
check "$HOSTMAN/.cursor/skills/agl-devsecops/SKILL.md" "proj:agl-devsecops"
check "$HOSTMAN/.cursor/skills/agl-testing-policy/SKILL.md" "proj:agl-testing-policy"
check "$HOSTMAN/.cursor/skills/agl-sast-gate/SKILL.md" "proj:agl-sast-gate"
check "$HOSTMAN/.cursor/skills/e2e-testing/SKILL.md" "proj:e2e-testing"
check "$HOSTMAN/.cursor/skills/verification-loop/SKILL.md" "proj:verification-loop"
check "$HOSTMAN/.cursor/rules/agl-testing-policy.mdc" "proj:agl-testing-policy-rule"
check "$HOSTMAN/scripts/skills/install-agl-pack-qa-devsecops.sh" "proj:install-qa-devsecops"
if [[ -f "$HOSTMAN/.cursor/mcp.json" ]] && grep -q llm-wiki-fs "$HOSTMAN/.cursor/mcp.json" 2>/dev/null; then
  echo "OK:proj:mcp-llm-wiki-fs"
else
  echo "MISS:proj:mcp-llm-wiki-fs"
fi

# Self-improve pack
check "$HOSTMAN/.cursor/rules/self-improve.mdc" "proj:self-improve"
check "$HOSTMAN/.cursor/rules/prompt-improve.mdc" "proj:prompt-improve"

# Vault NFS
check "$LLM/wiki/index.md" "vault:index"

# verify-six-repos (compact)
if [[ -x "$HOSTMAN/scripts/skills/verify-six-repos.sh" ]]; then
  OUT=$(cd "$HOSTMAN" && SKIP_LLM_WIKI=0 bash scripts/skills/verify-six-repos.sh 2>&1 | tail -1 || true)
  echo "VERIFY:$OUT"
else
  echo "MISS:verify-six-repos.sh"
fi

command -v claude >/dev/null 2>&1 && echo "OK:claude-cli" || echo "MISS:claude-cli"

# Claude Code plugins (formais)
if [[ -d "$HOME/.claude/plugins/cache/superpowers-marketplace/superpowers" ]]; then
  echo "OK:claude:superpowers-cache"
else
  echo "MISS:claude:superpowers-cache"
fi
if command -v claude >/dev/null 2>&1; then
  check_claude_plugin_enabled() {
    local id="$1" label="$2"
    if claude plugin list 2>/dev/null | awk -v id="$1" '
      index($0, id) { block=1 }
      block && /Status: ✔ enabled/ { found=1; exit }
      block && /^  ❯/ && index($0, id) == 0 { block=0 }
      END { exit !found }
    '; then
      echo "OK:$2"
    else
      echo "MISS:$2"
    fi
  }
  check_claude_plugin_enabled 'github@claude-plugins-official' 'claude:github-enabled'
  check_claude_plugin_enabled 'superpowers@superpowers-marketplace' 'claude:superpowers-enabled'
else
  echo "MISS:claude:github-enabled"
  echo "MISS:claude:superpowers-enabled"
fi
check "$HOME/.claude/ecc/install-state.json" "claude:ecc-home"
check "$HOME/.claude/skills/od-design-md/SKILL.md" "claude:od-design-md"

# Codex
check "$HOME/.codex/config.toml" "codex:config-toml"
check "$HOME/.codex/plugins" "codex:plugins-dir"
check "$HOME/.codex/ecc-install-state.json" "codex:ecc-state"
command -v codex >/dev/null 2>&1 && echo "OK:codex-cli" || echo "MISS:codex-cli"
REMOTE

audit_agldv() {
  local name="$1" ip="$2"
  echo "=== $name ($ip) ==="
  if ! "${SSH[@]}" "root@$ip" "echo reachable" >/dev/null 2>&1; then
    echo "  UNREACHABLE"
    echo ""
    return 1
  fi
  local out
  out=$("${SSH[@]}" "root@$ip" "bash -s" <<<"$REMOTE_AUDIT" 2>&1) || true
  local ok=0 miss=0
  while IFS= read -r line; do
    case "$line" in
      OK:*) ok=$((ok + 1)); [[ "$JSON_OUT" == "0" ]] && echo "  OK   ${line#OK:}" ;;
      MISS:*) miss=$((miss + 1)); [[ "$JSON_OUT" == "0" ]] && echo "  MISS ${line#MISS:}" ;;
      VERIFY:*) [[ "$JSON_OUT" == "0" ]] && echo "  ${line#VERIFY:}" ;;
      HOST=*) [[ "$JSON_OUT" == "0" ]] && echo "  hostname: ${line#HOST=}" ;;
    esac
  done <<<"$out"
  [[ "$JSON_OUT" == "0" ]] && echo "  --- score: OK=$ok MISS=$miss ---"
  echo ""
  [[ "$miss" -eq 0 ]]
}

audit_hermes() {
  echo "=== Hermes CT188 (via $AGLSRV1_HOST) ==="
  if ! "${SSH[@]}" "$AGLSRV1_HOST" "pct exec $CT188_VMID -- echo reachable" >/dev/null 2>&1; then
    echo "  UNREACHABLE (pct exec $CT188_VMID)"
    echo ""
    return 1
  fi

  local smoke="$HOSTMAN_ROOT/scripts/skills/smoke-hermes-six-repos.sh"
  if [[ -f "$smoke" ]]; then
    echo "  -- smoke Six Repos wiki --"
    "${SSH[@]}" "$AGLSRV1_HOST" "pct exec $CT188_VMID -- bash -s" < "$smoke" 2>&1 | sed 's/^/  /' || true
  fi

  echo "  -- Hermes agent skills / second brain --"
  "${SSH[@]}" "$AGLSRV1_HOST" "pct exec $CT188_VMID -- bash -lc '
    H=/opt/agl-hermes
    check() { [[ -e \"\$1\" ]] && echo \"  OK   \$2\" || echo \"  MISS \$2\"; }
    check /opt/agl-llm-wiki/wiki/index.md vault-host-index
    check \$H/data/skills/research/llm-wiki/SKILL.md jarvis-llm-wiki-skill
    check \$H/data/SECOND-BRAIN.md jarvis-SECOND-BRAIN
    for a in jarvis elon satya werner curator orion argus; do
      p=\$H/profiles/\$a
      [[ \"\$a\" == jarvis ]] && p=\$H/data
    check \$p/skills/research/llm-wiki llm-wiki-\$a
    check \$p/SECOND-BRAIN.md SECOND-BRAIN-\$a
    done
    if command -v docker >/dev/null 2>&1; then
      docker exec agl-hermes-jarvis test -r /opt/llm-wiki/wiki/index.md 2>/dev/null \
        && echo \"  OK   docker-jarvis-wiki-mount\" || echo \"  MISS docker-jarvis-wiki-mount\"
      docker exec agl-hermes-jarvis bash -lc \"export HOME=/opt/data; /opt/hermes/.venv/bin/hermes plugins list 2>/dev/null | grep -qi ponytail\" \
        && echo \"  OK   jarvis-ponytail-plugin\" || echo \"  MISS jarvis-ponytail-plugin\"
    else
      echo \"  WARN docker ausente\"
    fi
  '" 2>&1 || true
  echo ""
}

main() {
  [[ "$JSON_OUT" == "0" ]] && echo "=== Audit AGL Pack — AGLDV + Hermes ==="
  [[ "$JSON_OUT" == "0" ]] && echo "hostman: $HOSTMAN_NFS"
  echo ""

  local fail=0
  if [[ -n "$ONLY_HOST" ]]; then
    if [[ "$ONLY_HOST" == "ct188" || "$ONLY_HOST" == "hermes" ]]; then
      audit_hermes || fail=1
    elif [[ -n "${HOST_IPS[$ONLY_HOST]:-}" ]]; then
      audit_agldv "$ONLY_HOST" "${HOST_IPS[$ONLY_HOST]}" || fail=1
    else
      echo "Host desconhecido: $ONLY_HOST" >&2
      exit 2
    fi
  else
    for name in agldv02 agldv03 agldv04 agldv05 agldv06 agldv07 agldv12; do
      audit_agldv "$name" "${HOST_IPS[$name]}" || fail=1
    done
    audit_hermes || fail=1
  fi

  [[ "$fail" -eq 0 ]]
}

main "$@"

#!/usr/bin/env bash
# Verifica e orienta activação do Obsidian CLI para o vault llm-wiki (segundo cérebro).
set -euo pipefail

LLM_WIKI_DIR="${LLM_WIKI_DIR:-/mnt/overpower/apps/dev/agl/llm-wiki}"
VAULT_NAME="${OBSIDIAN_VAULT_NAME:-llm-wiki}"

pass() { echo "  OK   $1"; }
warn() { echo "  WARN $1"; }
fail() { echo "  FAIL $1"; exit 1; }

echo "=== Obsidian CLI + llm-wiki ==="
echo "vault path: $LLM_WIKI_DIR"
echo "vault name: $VAULT_NAME (ajustar OBSIDIAN_VAULT_NAME se diferente na UI)"
echo ""

if [[ ! -f "$LLM_WIKI_DIR/wiki/index.md" ]]; then
  fail "llm-wiki inacessível — clone: gh repo clone AGLz/llm-wiki $LLM_WIKI_DIR"
fi
pass "llm-wiki wiki/index.md"

if command -v obsidian >/dev/null 2>&1; then
  pass "obsidian no PATH ($(obsidian version 2>/dev/null | head -1 || echo 'version unknown'))"
  echo ""
  echo "-- vaults registados --"
  obsidian vaults 2>/dev/null || warn "obsidian vaults falhou — Obsidian desktop a correr?"
  echo ""
  echo "Definir default (se ainda não estiver):"
  echo "  obsidian set-default \"$VAULT_NAME\""
  echo ""
  echo "Smoke test:"
  echo "  obsidian search query=\"Plano Six Repos\" vault=\"$VAULT_NAME\""
  exit 0
fi

warn "obsidian CLI não está no PATH"

# Caminhos comuns (Linux / headless dev)
candidates=(
  "$HOME/.local/bin/obsidian"
  "/usr/local/bin/obsidian"
  "/opt/Obsidian/obsidian"
  "$HOME/Applications/Obsidian/obsidian"
)

for bin in "${candidates[@]}"; do
  if [[ -x "$bin" ]]; then
    echo "  Encontrado: $bin — adiciona ao PATH, ex.:"
    echo "    export PATH=\"$(dirname "$bin"):\$PATH\""
    exit 0
  fi
done

cat <<'EOF'

Pré-requisitos (Obsidian 1.12+, fevereiro 2026):

1. Instalar Obsidian Desktop na máquina de desenvolvimento (agldv03 ou wk45).
2. Abrir o vault llm-wiki (pasta do repositório clonado).
3. Settings → General → Command line interface → Toggle ON.
4. Reiniciar Obsidian; confirmar que `obsidian` está no PATH (ou symlink em ~/.local/bin).
5. Definir vault default:
     obsidian set-default "llm-wiki"
6. Re-correr:
     ./scripts/skills/setup-obsidian-cli-llm-wiki.sh
     ./scripts/skills/verify-six-repos.sh

Nota CT188/Hermes: contentores só leem /opt/llm-wiki (ro) — CLI Obsidian é para dev desktop, não para LXC headless.

EOF

exit 0

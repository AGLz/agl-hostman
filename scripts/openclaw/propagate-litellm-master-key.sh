#!/usr/bin/env bash
# Copia ~/.openclaw/litellm-master.secret.env para hosts OpenClaw/LiteLLM clientes.
# Executar na máquina que já tem o ficheiro (ex.: agldv03 após rotação em /opt/litellm/.env).
# Uso: ./scripts/openclaw/propagate-litellm-master-key.sh
# Opcional: OPENCLAW_KEY_HOSTS="root@ip1 root@ip2" ./scripts/openclaw/propagate-litellm-master-key.sh

set -euo pipefail

SECRET_SRC="${HOME}/.openclaw/litellm-master.secret.env"
SSH_OPTS=(
  -o ProxyCommand="tailscale nc %h %p"
  -o BatchMode=yes
  -o ConnectTimeout=20
  -o StrictHostKeyChecking=accept-new
)

DEFAULT_HOSTS=(
  "root@100.94.221.87"   # agldv03 (local — no-op se já igual)
  "root@100.83.51.9"     # fgsrv6 (se IP Tailscale mudar, ajustar ou usar OPENCLAW_KEY_HOSTS)
  "root@100.113.9.98"    # agldv04
  "root@100.119.41.63"   # agldv05
  "root@100.71.229.12"   # agldv06
)

if [[ ! -f "$SECRET_SRC" ]]; then
  echo "Erro: $SECRET_SRC não existe. Gere a chave no LiteLLM e crie o ficheiro (export LITELLM_MASTER_KEY=...)." >&2
  exit 1
fi

if [[ -n "${OPENCLAW_KEY_HOSTS:-}" ]]; then
  read -r -a HOSTS <<< "$OPENCLAW_KEY_HOSTS"
else
  HOSTS=("${DEFAULT_HOSTS[@]}")
fi

insert_zshrc_line() {
  local host="$1"
  ssh "${SSH_OPTS[@]}" "$host" 'bash -s' <<'REMOTE'
set -euo pipefail
f="${HOME}/.zshrc"
[[ -f "$f" ]] || { echo "sem .zshrc"; exit 0; }
grep -qF "litellm-master.secret.env" "$f" && exit 0
if grep -qE 'litellm-gateway\.env.*source' "$f"; then
  tmp=$(mktemp)
  awk '
    /litellm-gateway\.env/ && /source/ && !done {
      print
      print "[[ -f ~/.openclaw/litellm-master.secret.env ]] && source ~/.openclaw/litellm-master.secret.env"
      done = 1
      next
    }
    { print }
  ' "$f" > "$tmp" && mv "$tmp" "$f"
  echo "  OK: linha litellm-master.secret.env inserida no .zshrc"
else
  echo "  Aviso: bloco litellm-gateway.env não encontrado em .zshrc — adicione manualmente o source do secret"
fi
REMOTE
}

for host in "${HOSTS[@]}"; do
  echo ""
  echo "=== $host ==="
  if scp "${SSH_OPTS[@]}" "$SECRET_SRC" "${host}:.openclaw/litellm-master.secret.env"; then
    ssh "${SSH_OPTS[@]}" "$host" 'chmod 600 ~/.openclaw/litellm-master.secret.env'
    insert_zshrc_line "$host" || true
    echo "  OK: secret copiado"
  else
    echo "  FALHA: scp (host offline, firewall ou chave SSH?)"
  fi
done

echo ""
echo "Concluído. Em cada host com gateway: systemctl --user restart openclaw-gateway (se existir)."

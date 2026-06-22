#!/usr/bin/env bash
# Permite nginx (www-data) traversar caminhos absolutos até agl-hostman em NFS/ZFS.
#
# Causa típica: / ou /mnt sem bit de execução para "others" → stat() EACCES no error.log.
#
# Uso (root no agldv03 ou host com nginx a servir ah.aglz.io):
#   bash scripts/infra/fix-nfs-nginx-traverse-agldv03.sh
#   bash scripts/infra/fix-nfs-nginx-traverse-agldv03.sh --verify-only

set -euo pipefail

DOCROOT="${AGL_NGINX_DOCROOT:-/mnt/overpower/apps/dev/agl/agl-hostman/src/public}"
VERIFY_ONLY="${1:-}"

need_exec() {
  local path="$1"
  local mode
  mode="$(stat -c '%a' "${path}" 2>/dev/null || echo '')"
  [[ -n "${mode}" ]] || { echo "ERRO: ${path} inexistente" >&2; return 1; }
  local other_x=$((mode % 10))
  if (( other_x & 1 )); then
    echo "OK ${path} (${mode})"
  else
    echo "FIX ${path} (${mode}) → adicionar o+x"
    return 1
  fi
}

fix_exec() {
  local path="$1"
  chmod o+x "${path}"
}

echo "=== NFS/nginx traverse (docroot: ${DOCROOT}) ==="

paths=(/ /mnt)
while IFS= read -r parent; do
  [[ -n "${parent}" ]] && paths+=("${parent}")
done < <(dirname "${DOCROOT}" | tr '/' '\n' | awk 'NF{ p=p"/"$0; print p }')

missing=0
for p in "${paths[@]}"; do
  need_exec "${p}" || missing=1
done

if [[ "${VERIFY_ONLY}" == "--verify-only" ]]; then
  [[ "${missing}" -eq 0 ]] || exit 1
  echo "Verificação OK"
  exit 0
fi

if [[ "${missing}" -eq 1 ]]; then
  for p in "${paths[@]}"; do
    mode="$(stat -c '%a' "${p}" 2>/dev/null || echo 0)"
    ox=$((mode % 10))
    if (( !(ox & 1) )); then
      fix_exec "${p}"
      echo "  chmod o+x ${p} → $(stat -c '%a' "${p}")"
    fi
  done
fi

if command -v nginx >/dev/null 2>&1; then
  nginx -t
  systemctl reload nginx 2>/dev/null || service nginx reload 2>/dev/null || true
fi

if command -v curl >/dev/null 2>&1; then
  code="$(curl -sS -o /dev/null -w '%{http_code}' -H 'Host: ah.aglz.io' http://127.0.0.1:8055/ 2>/dev/null || echo '000')"
  echo "Smoke GET / → HTTP ${code}"
fi

echo "Concluído."

#!/usr/bin/env bash
# Provisiona teams + virtual keys LiteLLM CT186 a partir de manifest JSON.
#
# Uso:
#   bash scripts/litellm/provision-virtual-keys.sh --dry-run
#   bash scripts/litellm/provision-virtual-keys.sh --apply
#   LITELLM_ENV_FILE=/opt/litellm/.env bash scripts/litellm/provision-virtual-keys.sh --apply
#
# Manifest local (gitignored): config/litellm/virtual-keys-manifest.json
# Exemplo: config/litellm/virtual-keys-manifest.example.json
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
MANIFEST="${VIRTUAL_KEYS_MANIFEST:-$REPO_ROOT/config/litellm/virtual-keys-manifest.json}"
EXAMPLE_MANIFEST="$REPO_ROOT/config/litellm/virtual-keys-manifest.example.json"
ENV_FILE="${LITELLM_ENV_FILE:-/opt/litellm/.env}"
GATEWAY="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"
DRY_RUN=1

usage() {
  sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
}

log() { echo "[provision-vkeys] $*" >&2; }

load_env() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
  fi
  if [[ -z "${LITELLM_MASTER_KEY:-}" ]]; then
    LITELLM_MASTER_KEY="$("$SCRIPT_DIR/_litellm-master-key.sh" || true)"
  fi
  [[ -n "${LITELLM_MASTER_KEY:-}" ]] || {
    log "ERRO: LITELLM_MASTER_KEY em falta ($ENV_FILE ou env)"
    exit 1
  }
}

resolve_manifest() {
  if [[ -f "$MANIFEST" ]]; then
    printf '%s' "$MANIFEST"
    return
  fi
  if [[ -f "$EXAMPLE_MANIFEST" ]]; then
    log "WARN: usando example manifest — copiar para virtual-keys-manifest.json para produção"
    printf '%s' "$EXAMPLE_MANIFEST"
    return
  fi
  log "ERRO: manifest em falta"
  exit 1
}

litellm_curl() {
  local method="$1" path="$2" body="${3:-}"
  local url="${GATEWAY%/}${path}"
  local -a args=(-sS --max-time 30 -X "$method" -H "Authorization: Bearer ${LITELLM_MASTER_KEY}" -H "Content-Type: application/json")
  if [[ -n "$body" ]]; then
    args+=(-d "$body")
  fi
  curl "${args[@]}" "$url"
}

team_exists() {
  local alias="$1"
  litellm_curl GET "/team/list" | jq -e --arg a "$alias" '.[] | select(.team_alias == $a)' >/dev/null 2>&1
}

key_alias_exists() {
  local alias="$1"
  litellm_curl GET "/key/list" | jq -e --arg a "$alias" '.[] | select(.key_alias == $a)' >/dev/null 2>&1
}

ensure_team() {
  local alias="$1" budget="$2"
  if team_exists "$alias"; then
    log "team OK: $alias"
    litellm_curl GET "/team/list" | jq -r --arg a "$alias" '.[] | select(.team_alias == $a) | .team_id' | head -1
    return
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] criar team $alias budget=$budget"
    printf '%s' "dry-run-team-id"
    return
  fi
  local resp team_id
  resp="$(litellm_curl POST "/team/new" "{\"team_alias\":\"${alias}\",\"max_budget\":${budget}}")"
  team_id="$(echo "$resp" | jq -r '.team_id // empty')"
  [[ -n "$team_id" ]] || { log "ERRO team/new $alias: $resp"; exit 1; }
  log "team criado: $alias ($team_id)"
  printf '%s' "$team_id"
}

ensure_key() {
  local team_id="$1" key_alias="$2" models_json="$3" budget="$4"
  if key_alias_exists "$key_alias"; then
    log "key OK: $key_alias"
    return
  fi
  if [[ "$DRY_RUN" -eq 1 ]]; then
    log "[dry-run] criar key $key_alias team=$team_id models=$models_json"
    return
  fi
  local body resp
  body="$(jq -cn \
    --arg team_id "$team_id" \
    --arg key_alias "$key_alias" \
    --argjson models "$models_json" \
    --argjson max_budget "$budget" \
    '{team_id:$team_id,key_alias:$key_alias,models:$models,max_budget:$max_budget}')"
  resp="$(litellm_curl POST "/key/generate" "$body")"
  if echo "$resp" | jq -e '.key // .token // .key_name' >/dev/null 2>&1; then
    log "key criada: $key_alias (guardar token localmente — não reimprimir em logs CI)"
    echo "$resp" | jq -r '.key // .token // empty' >"${REPO_ROOT}/config/litellm/.generated-${key_alias}.secret"
    chmod 600 "${REPO_ROOT}/config/litellm/.generated-${key_alias}.secret" 2>/dev/null || true
  else
    log "ERRO key/generate $key_alias: $resp"
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --apply) DRY_RUN=0; shift ;;
    --manifest) MANIFEST="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) log "Opção desconhecida: $1"; usage ;;
  esac
done

command -v jq >/dev/null 2>&1 || { log "ERRO: jq obrigatório"; exit 1; }
load_env
manifest_path="$(resolve_manifest)"
GATEWAY="$(jq -r '.gateway // empty' "$manifest_path")"
[[ -n "$GATEWAY" && "$GATEWAY" != "null" ]] || GATEWAY="${LITELLM_GATEWAY_URL:-http://100.125.249.8:4000}"

log "gateway=$GATEWAY manifest=$manifest_path dry_run=$DRY_RUN"

if [[ "$DRY_RUN" -eq 1 ]]; then
  jq -c '.teams[] | {team:.team_alias,budget:.max_budget_usd,keys:[.keys[].key_alias]}' "$manifest_path" | while read -r line; do
    log "[dry-run] provision $line"
  done
  log "provision-virtual-keys concluído (dry_run=1, sem API)"
  exit 0
fi

team_count="$(jq '.teams | length' "$manifest_path")"
for ((i = 0; i < team_count; i++)); do
  alias="$(jq -r ".teams[$i].team_alias" "$manifest_path")"
  budget="$(jq -r ".teams[$i].max_budget_usd // 50" "$manifest_path")"
  team_id="$(ensure_team "$alias" "$budget")"
  key_count="$(jq ".teams[$i].keys | length" "$manifest_path")"
  for ((k = 0; k < key_count; k++)); do
    key_alias="$(jq -r ".teams[$i].keys[$k].key_alias" "$manifest_path")"
    models_json="$(jq -c ".teams[$i].keys[$k].models" "$manifest_path")"
    ensure_key "$team_id" "$key_alias" "$models_json" "$budget"
  done
done

log "provision-virtual-keys concluído (dry_run=$DRY_RUN)"

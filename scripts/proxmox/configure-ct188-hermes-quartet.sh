#!/usr/bin/env bash
# Configura quartet AGLz no CT188: 4 profiles Hermes (1 bot Telegram cada).
# Tokens: ficheiro 600 com TELEGRAM_TOKEN_<AGENT>=... (nunca commitar).
#
# Uso (root no CT188):
#   bash configure-ct188-hermes-quartet.sh /caminho/agl-hostman /root/.aglz-telegram-tokens.env

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/agl-hostman /path/tokens.env}"
TOKENS_FILE="${2:?Uso: $0 /caminho/agl-hostman /path/tokens.env}"

HERMES_ROOT="/opt/agl-hermes"
LITELLM_TS="http://100.125.249.8:4000"
HONCHO_BASE_URL="${HONCHO_BASE_URL:-http://100.124.98.54:8000}"
ALLOWED_USERS="${TELEGRAM_ALLOWED_USERS:-1272190248}"

declare -A AGENT_MODEL=(
  [jarvis]=gpt-5.5
  [elon]=glm-4.7-flash
  # qwen-coder no LiteLLM CT186 cai em nemotron free → content vazio com tools Hermes
  [satya]=glm-4.7-flash
  [werner]=glm-4.7-flash
)

FALLBACK_MODEL="${HERMES_FALLBACK_MODEL:-glm-4.7-flash}"
AUXILIARY_MODEL="${HERMES_AUXILIARY_MODEL:-zai-glm-flash}"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: ${AGL_HOSTMAN} inexistente" >&2; exit 1; }
test -f "${TOKENS_FILE}" || { echo "ERRO: tokens ${TOKENS_FILE} inexistente" >&2; exit 1; }
chmod 600 "${TOKENS_FILE}" 2>/dev/null || true

# shellcheck disable=SC1090
source "${TOKENS_FILE}"

for agent in jarvis elon satya werner; do
  var="TELEGRAM_TOKEN_${agent^^}"
  if [[ -z "${!var:-}" ]]; then
    echo "ERRO: falta ${var} em ${TOKENS_FILE}" >&2
    exit 1
  fi
done

install -d -m 0755 "${HERMES_ROOT}/profiles"

BASE_CONFIG="${HERMES_ROOT}/data/config.yaml"
if [[ ! -f "${BASE_CONFIG}" ]]; then
  echo "ERRO: ${BASE_CONFIG} inexistente — correr bootstrap-ct188-hermes.sh primeiro" >&2
  exit 1
fi

profile_dir() {
  local agent="$1"
  if [[ "${agent}" == "jarvis" ]]; then
    echo "${HERMES_ROOT}/data"
  else
    echo "${HERMES_ROOT}/profiles/${agent}"
  fi
}

seed_profile() {
  local agent="$1"
  local pdir
  pdir="$(profile_dir "${agent}")"
  install -d -m 0700 "${pdir}"

  if [[ "${agent}" != "jarvis" ]] && [[ ! -f "${pdir}/config.yaml" ]]; then
    echo "=== Seed config ${agent} a partir de data/ ==="
    cp -a "${HERMES_ROOT}/data/config.yaml" "${pdir}/config.yaml"
    rm -f "${pdir}/gateway.lock" "${pdir}/gateway.pid" 2>/dev/null || true
  fi

  echo "=== SOUL + config modelo: ${agent} ==="
  install -m 0600 "${AGL_HOSTMAN}/docker/hermes/profiles/${agent}/SOUL.md" "${pdir}/SOUL.md"

  if [[ "${agent}" == "werner" ]] && [[ -f "${AGL_HOSTMAN}/.claude/skills/agl-infra/SKILL.md" ]]; then
    install -d -m 0755 "${pdir}/skills/agl-infra"
    install -m 0644 "${AGL_HOSTMAN}/.claude/skills/agl-infra/SKILL.md" "${pdir}/skills/agl-infra/SKILL.md"
  fi

  python3 - "${pdir}/config.yaml" "${AGENT_MODEL[$agent]}" "${LITELLM_TS}" "${FALLBACK_MODEL}" "${AUXILIARY_MODEL}" <<'PY'
import sys
from pathlib import Path
import yaml

path, model, litellm, fallback_model, auxiliary_model = sys.argv[1:6]
cfg = yaml.safe_load(Path(path).read_text())
for drop in ("agents", "routes", "default_agent"):
    cfg.pop(drop, None)

base_cfg = yaml.safe_load(Path("/opt/agl-hermes/data/config.yaml").read_text())
api_key = (base_cfg.get("model") or {}).get("api_key") or (cfg.get("model") or {}).get("api_key")

def patch_urls(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k == "base_url" and isinstance(v, str) and v.strip():
                if "localhost" in v or "127.0.0.1" in v:
                    obj[k] = litellm.rstrip("/")
            else:
                patch_urls(v)
    elif isinstance(obj, list):
        for item in obj:
            patch_urls(item)

patch_urls(cfg)

m = cfg.setdefault("model", {})
m["default"] = model
m["provider"] = m.get("provider") or "custom"
m["base_url"] = litellm.rstrip("/")
m["fallback"] = fallback_model
if api_key:
    m["api_key"] = api_key

fb = cfg.setdefault("fallback_model", {})
fb["provider"] = fb.get("provider") or "custom"
fb["model"] = fallback_model
fb["base_url"] = litellm.rstrip("/")
if api_key:
    fb["api_key"] = api_key

for cp in cfg.get("custom_providers") or []:
    if isinstance(cp, dict):
        cp["base_url"] = litellm.rstrip("/")
        cp["model"] = cp.get("model") or model
        cp["fallback"] = fallback_model
        if api_key and not cp.get("api_key"):
            cp["api_key"] = api_key

for section in ("delegation", "compression"):
    block = cfg.get(section)
    if isinstance(block, dict):
        if block.get("provider") == "custom" or block.get("model"):
            block["base_url"] = litellm.rstrip("/")
            if api_key and not block.get("api_key"):
                block["api_key"] = api_key

aux = cfg.get("auxiliary")
if isinstance(aux, dict):
    for _name, block in aux.items():
        if not isinstance(block, dict):
            continue
        block["provider"] = "custom"
        block["model"] = auxiliary_model
        block["base_url"] = litellm.rstrip("/")
        if api_key:
            block["api_key"] = api_key

prov = cfg.setdefault("providers", {})
custom = prov.setdefault("custom", {})
custom["base_url"] = litellm.rstrip("/")

Path(path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
print(f"OK config {path} model={model} fallback={fallback_model} auxiliary={auxiliary_model}")
PY

  if [[ -f "${AGL_HOSTMAN}/docker/hermes/config.aglz-quartet-snippet.yaml" ]]; then
    python3 - "${pdir}/config.yaml" "${AGL_HOSTMAN}/docker/hermes/config.aglz-quartet-snippet.yaml" <<'PY'
import sys
from pathlib import Path
import yaml

cfg_path, snippet_path = sys.argv[1:3]
cfg = yaml.safe_load(Path(cfg_path).read_text()) or {}
frag = yaml.safe_load(Path(snippet_path).read_text()) or {}
qc = frag.get("quick_commands") or {}
if qc:
    merged = dict(cfg.get("quick_commands") or {})
    merged.update(qc)
    cfg["quick_commands"] = merged
    Path(cfg_path).write_text(yaml.dump(cfg, default_flow_style=False, allow_unicode=True))
    print("OK quick_commands", sorted(qc.keys()))
PY
  fi

  local token_var="TELEGRAM_TOKEN_${agent^^}"
  local token="${!token_var}"

  if [[ -f "${pdir}/.env" ]]; then
    grep -q '^TELEGRAM_BOT_TOKEN=' "${pdir}/.env" && \
      sed -i "s|^TELEGRAM_BOT_TOKEN=.*|TELEGRAM_BOT_TOKEN=${token}|" "${pdir}/.env" || \
      echo "TELEGRAM_BOT_TOKEN=${token}" >>"${pdir}/.env"
    grep -q '^TELEGRAM_ALLOWED_USERS=' "${pdir}/.env" || \
      echo "TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}" >>"${pdir}/.env"
  else
    cat >"${pdir}/.env" <<EOF
TELEGRAM_BOT_TOKEN=${token}
TELEGRAM_ALLOWED_USERS=${ALLOWED_USERS}
API_SERVER_ENABLED=false
EOF
  fi
  chmod 600 "${pdir}/.env"

  if [[ -f "${AGL_HOSTMAN}/docker/hermes/honcho.aglz.json.example" ]]; then
    python3 - "${AGL_HOSTMAN}/docker/hermes/honcho.aglz.json.example" "${pdir}/honcho.json" "${agent}" "${HONCHO_BASE_URL}" <<'PY'
import json, sys
from pathlib import Path
src, dst, peer, base_url = sys.argv[1:5]
data = json.loads(Path(src).read_text())
h = data.get("hosts", {}).get("hermes", {})
h["aiPeer"] = peer
out = {"baseUrl": base_url.rstrip("/"), "hosts": {"hermes": h}}
Path(dst).write_text(json.dumps(out, indent=2) + "\n")
print("OK honcho", peer, base_url)
PY
  fi

  chown -R 10000:10000 "${pdir}" 2>/dev/null || true
}

for agent in jarvis elon satya werner; do
  seed_profile "${agent}"
done

WIKI_DIR="/opt/agl-llm-wiki"
bash "${AGL_HOSTMAN}/scripts/proxmox/ensure-llm-wiki-ct188.sh" || true

install -m 0644 "${AGL_HOSTMAN}/docker/hermes/docker-compose.aglz-quartet.ct188.yml" \
  "${HERMES_ROOT}/docker-compose.aglz-quartet.yml"
install -m 0644 "${AGL_HOSTMAN}/docker/hermes/Dockerfile.aglz-agency" \
  "${HERMES_ROOT}/Dockerfile.aglz-agency"

# Chaves SSH opcionais — infra AGL usa Tailscale SSH (tailscale up --ssh + ACLs).
# Montagem compose AGL_INFRA_SSH_DIR só para SSH clássico dentro do contentor; operação normal via agldv03.
install -d -m 0700 /root/.ssh
if [[ ! -f /root/.ssh/config ]]; then
  cat >/root/.ssh/config <<'SSHCFG'
# Tailscale IPs — auth via Tailscale SSH no host operador (agldv03), não chaves id_* aqui
Host aglsrv1 aglsrv1-ts
  HostName 100.107.113.33
  User root
  StrictHostKeyChecking accept-new
Host aglsrv6-ts
  HostName 100.98.108.66
  User root
  StrictHostKeyChecking accept-new
SSHCFG
  chmod 0600 /root/.ssh/config
fi

seed_infra_ssh() {
  local pdir="$1"
  install -d -m 0700 "${pdir}/.ssh"
  if [[ ! -f "${pdir}/.ssh/config" ]]; then
    cat >"${pdir}/.ssh/config" <<'SSHCFG'
# Referência Tailscale — auth real: Tailscale SSH no operador (agldv03)
Host aglsrv1 aglsrv1-ts
  HostName 100.107.113.33
  User root
  StrictHostKeyChecking accept-new
Host aglsrv6-ts
  HostName 100.98.108.66
  User root
  StrictHostKeyChecking accept-new
SSHCFG
    chmod 0600 "${pdir}/.ssh/config"
  fi
  chown -R 10000:10000 "${pdir}/.ssh" 2>/dev/null || true
}

for agent in jarvis elon satya werner; do
  seed_infra_ssh "$(profile_dir "${agent}")"
done

# Chaves SSH: copiar do host CT188 para profiles se existirem (senão montagem compose)
if [[ -d /root/.ssh ]] && compgen -G "/root/.ssh/id_*" >/dev/null; then
  for agent in jarvis elon satya werner; do
    pdir="$(profile_dir "${agent}")"
    for key in /root/.ssh/id_*; do
      [[ -f "${key}" ]] || continue
      install -m 0600 "${key}" "${pdir}/.ssh/$(basename "${key}")"
      [[ -f "${key}.pub" ]] && install -m 0644 "${key}.pub" "${pdir}/.ssh/$(basename "${key}").pub"
    done
    seed_infra_ssh "${pdir}"
  done
fi

# DNS: Pi-hole LAN (CT102) — padrão AGL
cat >/etc/resolv.conf <<'RESOLV'
search localdomain
nameserver 192.168.0.102
RESOLV

# Tailscale table 52 captura 192.168.0.0/24 — Pi-hole tem de ir por eth0 local
if [[ -f "${AGL_HOSTMAN}/scripts/proxmox/ct188-pihole-lan-route.sh" ]]; then
  bash "${AGL_HOSTMAN}/scripts/proxmox/ct188-pihole-lan-route.sh"
  install -m 0755 "${AGL_HOSTMAN}/scripts/proxmox/ct188-pihole-lan-route.sh" /usr/local/sbin/agl-pihole-lan-route.sh
  cat >/etc/systemd/system/agl-pihole-lan-route.service <<'UNIT'
[Unit]
Description=AGL CT188 Pi-hole LAN route (bypass Tailscale table 52)
After=tailscaled.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/sbin/agl-pihole-lan-route.sh

[Install]
WantedBy=multi-user.target
UNIT
  systemctl daemon-reload
  systemctl enable --now agl-pihole-lan-route.service
fi

cd "${HERMES_ROOT}"
docker compose -f docker-compose.yml down 2>/dev/null || true
if ! docker compose -f docker-compose.aglz-quartet.yml build --pull 2>/dev/null; then
  echo "WARN: build falhou (rede?) — tentar imagem upstream + lazy-install" >&2
  export HERMES_IMAGE="${HERMES_IMAGE:-nousresearch/hermes-agent:latest}"
  docker compose -f docker-compose.aglz-quartet.yml pull 2>/dev/null || true
fi
docker compose -f docker-compose.aglz-quartet.yml up -d --build

echo ""
echo "=== Quartet AGLz — gateways ==="
docker compose -f docker-compose.aglz-quartet.yml ps
echo ""
echo "Bots: @hermes_jarvis_h_bot @hermes_jarvis_h_elon_bot @hermes_jarvis_h_satya_bot @hermes_jarvis_h_werner_bot"
echo "API Jarvis: http://$(hostname -I | awk '{print $1}'):8642/health"
echo "Apagar tokens: rm -f ${TOKENS_FILE}"

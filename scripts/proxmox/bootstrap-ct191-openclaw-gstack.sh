#!/usr/bin/env bash
# Bootstrap CT191: OpenClaw (Jarvis O) + GStack (AGLz AI Agency).
# Executar dentro do CT191 como root, com agl-hostman disponível.
#
# Uso:
#   bash bootstrap-ct191-openclaw-gstack.sh /caminho/para/agl-hostman [LITELLM_URL]
#
# Pré-requisitos:
#   - /opt/agl-openclaw/.env e config/openclaw.json (copiar de CT187 ou openclaw-repo)
#   - Segredos LiteLLM (não versionar)

set -euo pipefail

AGL_HOSTMAN="${1:?Uso: $0 /caminho/para/agl-hostman [http://IP_CT186:4000]}"
LITELLM_BASE_URL="${2:-http://192.168.0.186:4000}"
AGLZ_CREW="${AGL_HOSTMAN}/projects/aglz-crew"

test -d "${AGL_HOSTMAN}" || { echo "ERRO: agl-hostman inexistente" >&2; exit 1; }
test -x "${AGLZ_CREW}/install-gstack-aglz.sh" || { echo "ERRO: falta projects/aglz-crew/install-gstack-aglz.sh" >&2; exit 1; }

export DEBIAN_FRONTEND=noninteractive

echo "=== [1/4] OpenClaw (stack Docker /opt/agl-openclaw) ==="
bash "${AGL_HOSTMAN}/scripts/proxmox/bootstrap-ct187-openclaw.sh" "${AGL_HOSTMAN}" "${LITELLM_BASE_URL}" || {
  echo "AVISO: bootstrap OpenClaw falhou — verificar .env e openclaw.json" >&2
}

echo "=== [2/4] GStack (Jarvis O, CT191) ==="
install -d -m 0755 /etc/gstack
if [[ -f "${AGLZ_CREW}/gstack/config/jarvis-o-ct191.yaml" ]]; then
  install -m 0644 "${AGLZ_CREW}/gstack/config/jarvis-o-ct191.yaml" /etc/gstack/jarvis-o.yaml
else
  install -m 0644 "${AGLZ_CREW}/gstack/config/jarvis-o.yaml" /etc/gstack/jarvis-o.yaml
fi

bash "${AGLZ_CREW}/install-gstack-aglz.sh" jarvis-o 191

echo "=== [3/4] Skill browse → OpenClaw workspace ==="
OC_SKILLS="/opt/agl-openclaw/workspace/skills"
install -d -m 0755 "${OC_SKILLS}/gstack-browse"
if [[ -f "${AGLZ_CREW}/gstack/skills/browse/SKILL.md" ]]; then
  install -m 0644 "${AGLZ_CREW}/gstack/skills/browse/SKILL.md" "${OC_SKILLS}/gstack-browse/SKILL.md"
  chown -R 1000:1000 /opt/agl-openclaw/workspace/skills 2>/dev/null || true
fi

echo "=== [4/4] Referência AGLz AI Agency ==="
install -d -m 0755 /opt/aglz-agency
for doc in AGLZ_AI_AGENCY_PLAN_FINAL_V6.md TRANSFORMACAO_OPENCLAW_HERMES_83_AGENTES.md README_GSTACK.md; do
  if [[ -f "${AGLZ_CREW}/${doc}" ]]; then
    install -m 0644 "${AGLZ_CREW}/${doc}" "/opt/aglz-agency/${doc}"
  elif [[ -f "${AGL_HOSTMAN}/docs/${doc}" ]]; then
    install -m 0644 "${AGL_HOSTMAN}/docs/${doc}" "/opt/aglz-agency/${doc}"
  fi
done

echo ""
echo "=== CT191 bootstrap concluído ==="
echo "  OpenClaw gateway: http://127.0.0.1:\${OPENCLAW_GATEWAY_PORT:-28789}/healthz"
echo "  GStack CLI:       gstack-browser / gb"
echo "  LiteLLM:          ${LITELLM_BASE_URL}"
echo "  Docs locais:      /opt/aglz-agency/"
echo "  Plano agência:    docs/AGLZ_AI_AGENCY_PLAN_FINAL_V6.md (repo)"

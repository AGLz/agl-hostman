#!/usr/bin/env bash
# Gera ~/.openclaw/openclaw.env para o systemd (variáveis que o daemon precisa)
# Rodar no host onde o gateway OpenClaw está: ./scripts/openclaw-systemd-env.sh
# Ou via deploy: ssh root@agldv03 'bash -s' < scripts/openclaw-systemd-env.sh

set -e
ENV_FILE="${OPENCLAW_ENV_FILE:-$HOME/.openclaw/openclaw.env}"
mkdir -p "$(dirname "$ENV_FILE")"

# Carregar vars do zshrc (se existir)
[[ -f ~/.openclaw/zshrc-openclaw.env ]] && source ~/.openclaw/zshrc-openclaw.env 2>/dev/null || true

# Formato systemd: KEY=value (uma por linha)
cat > "$ENV_FILE" << EOF
# OpenClaw Gateway - variáveis para systemd (gerado por openclaw-systemd-env.sh)
# Não versionar - contém secrets

KIMI_URL=${KIMI_URL:-https://api.moonshot.ai/anthropic}
KIMI_AUTH=${KIMI_AUTH:-}
MOONSHOT_API_KEY=${MOONSHOT_API_KEY:-$KIMI_AUTH}
DEEPSEEK_URL=${DEEPSEEK_URL:-https://api.deepseek.com/anthropic}
DEEPSEEK_AUTH=${DEEPSEEK_AUTH:-}
DEEPSEEK_API_KEY=${DEEPSEEK_API_KEY:-$DEEPSEEK_AUTH}
GLM_URL=${GLM_URL:-https://api.z.ai/api/anthropic}
GLM_AUTH=${GLM_AUTH:-}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
OPENAI_URL=${OPENAI_URL:-https://api.openai.com/v1}
OPENAI_AUTH=${OPENAI_AUTH:-}
OPENAI_API_KEY=${OPENAI_API_KEY:-$OPENAI_AUTH}
GEMINI_URL=${GEMINI_URL:-https://generativelanguage.googleapis.com/v1beta}
GEMINI_AUTH=${GEMINI_AUTH:-}
GEMINI_API_KEY=${GEMINI_API_KEY:-$GEMINI_AUTH}
OPENROUTER_API_KEY=${OPENROUTER_API_KEY:-}
EOF

chmod 600 "$ENV_FILE"
echo "Gerado: $ENV_FILE"

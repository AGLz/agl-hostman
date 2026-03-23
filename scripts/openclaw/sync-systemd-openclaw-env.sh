#!/usr/bin/env bash
# Gera ~/.config/environment.d/openclaw.conf a partir de ~/.zshrc + zshrc-openclaw.env.
# Reason: systemd EnvironmentFile não expande ${VAR:-default}; após o grep, injetamos
# URLs literais com valores já resolvidos após source dos ficheiros.
set -euo pipefail

mkdir -p ~/.config/environment.d

grep -h -E "^export (ZAI_API_KEY|GLM_AUTH|GLM_URL|KIMI_AUTH|KIMI_URL|MOONSHOT_API_KEY|DEEPSEEK_API_KEY|DEEPSEEK_AUTH|DEEPSEEK_URL|OPENAI_API_KEY|OPENAI_AUTH|OPENAI_URL|GEMINI_API_KEY|GEMINI_AUTH|GEMINI_URL|OPENROUTER_API_KEY|OPENROUTER_AUTH|OPENROUTER_URL|DASHSCOPE_API_KEY|ANTHROPIC_API_KEY)=" \
  ~/.zshrc ~/.openclaw/zshrc-openclaw.env 2>/dev/null | sed "s/^export //" > ~/.config/environment.d/openclaw.conf

grep -q "ANTHROPIC_API_KEY=" ~/.config/environment.d/openclaw.conf || echo 'ANTHROPIC_API_KEY="sk-optional"' >> ~/.config/environment.d/openclaw.conf
sed -i 's/^ANTHROPIC_API_KEY=""$/ANTHROPIC_API_KEY="sk-optional"/' ~/.config/environment.d/openclaw.conf 2>/dev/null || true

KVAL=$(grep "^KIMI_AUTH=" ~/.config/environment.d/openclaw.conf 2>/dev/null | head -1 | sed "s/^KIMI_AUTH=//;s/^\"//;s/\"$//")
if [[ -n "${KVAL:-}" ]]; then
  grep -v "^MOONSHOT_API_KEY=" ~/.config/environment.d/openclaw.conf > /tmp/ocfix.$$
  mv /tmp/ocfix.$$ ~/.config/environment.d/openclaw.conf
  echo "MOONSHOT_API_KEY=\"$KVAL\"" >> ~/.config/environment.d/openclaw.conf
fi

# Apenas zshrc-openclaw.env (bash-safe): ~/.zshrc pode conter exit e quebrar o script.
# Os defaults (${VAR:-url}) ficam resolvidos após source deste ficheiro.
(
  set -a
  # shellcheck source=/dev/null
  source ~/.openclaw/litellm-gateway.env 2>/dev/null || true
  # shellcheck source=/dev/null
  source ~/.openclaw/zshrc-openclaw.env 2>/dev/null || true
  set +a
  for k in OPENAI_URL OPENROUTER_URL GLM_URL KIMI_URL GEMINI_URL DEEPSEEK_URL ANTHROPIC_BASE_URL LITELLM_GATEWAY_URL; do
    v="${!k:-}"
    [[ -z "${v}" ]] && continue
    sed -i "/^${k}=/d" ~/.config/environment.d/openclaw.conf
    printf '%s="%s"\n' "$k" "$v" >> ~/.config/environment.d/openclaw.conf
  done
) || true

echo "env OK"

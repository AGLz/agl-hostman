# Patch OpenClaw para usar LiteLLM local (localhost:4000)
# Aplicar: jq -f config/openclaw/openclaw-litellm-local.jq openclaw.json
.models.providers.zai.baseUrl = "http://localhost:4000" |
.models.providers.zai.apiKey = "sk-litellm-default" |
.models.providers.zai.api = "openai-completions" |
.models.providers.anthropic.baseUrl = "http://localhost:4000" |
.models.providers.anthropic.apiKey = "sk-litellm-default" |
.models.providers.deepseek.baseUrl = "http://localhost:4000" |
.models.providers.deepseek.apiKey = "sk-litellm-default" |
.models.providers.google.baseUrl = "http://localhost:4000" |
.models.providers.google.apiKey = "sk-litellm-default" |
.models.providers.openai.baseUrl = "http://localhost:4000" |
.models.providers.openai.apiKey = "sk-litellm-default" |
.models.providers.kimi.baseUrl = "http://localhost:4000" |
.models.providers.kimi.apiKey = "sk-litellm-default" |
.models.providers.moonshot.baseUrl = "http://localhost:4000" |
.models.providers.moonshot.apiKey = "sk-litellm-default" |
.models.providers.qwen.baseUrl = "http://localhost:4000" |
.models.providers.qwen.apiKey = "sk-litellm-default" |
.models.providers.openrouter.baseUrl = "http://localhost:4000" |
.models.providers.openrouter.apiKey = "sk-litellm-default"

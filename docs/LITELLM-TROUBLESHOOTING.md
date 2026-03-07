# LiteLLM — Troubleshooting

> **Last Updated**: 2026-03-02  
> **Host**: agldv03 (100.94.221.87) — porta 4000

## Diagnóstico rápido

```bash
# 1. Porta 4000
ss -tlnp | grep 4000

# 2. Container
docker ps -a | grep litellm

# 3. Health (sem auth — endpoints públicos)
curl -s http://localhost:4000/health/liveliness   # "I'm alive!"
curl -s http://localhost:4000/health/readiness    # {"status":"healthy",...}

# 4. Health completo (requer auth)
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/health

# 5. Modelos (requer auth)
curl -s -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/models | jq .
```

---

## Problemas comuns

### 1. HTTP 401 — "No api key passed in"

**Causa**: O LiteLLM exige autenticação na maioria dos endpoints.

**Endpoints que NÃO exigem auth** (use para health checks):
- `/health/liveliness` — "I'm alive!"
- `/health/readiness` — status do proxy, DB, cache

**Endpoints que EXIGEM auth**:
- `/health` — health completo dos modelos (faz chamadas reais às APIs)
- `/models` — lista de modelos
- `/chat/completions` — inferência

**Solução**:
```bash
export LITELLM_MASTER_KEY=$(grep LITELLM_MASTER_KEY config/litellm/.env | cut -d= -f2)
curl -H "Authorization: Bearer $LITELLM_MASTER_KEY" http://localhost:4000/models
```

---

### 2. Container "unhealthy"

**Causa**: O healthcheck padrão da imagem usa `/health`, que exige auth. O `curl` no healthcheck não passa o token.

**Solução**: Usar `/health/readiness` no healthcheck (não exige auth). A imagem LiteLLM **não tem curl/wget** — use Python:

```yaml
# docker/litellm/docker-compose.yml
healthcheck:
  test: ["CMD", "python", "-c", "import urllib.request; urllib.request.urlopen('http://localhost:4000/health/readiness', timeout=5)"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 15s
```

Recriar: `docker compose -f docker/litellm/docker-compose.yml up -d --force-recreate`

---

### 3. "API key not valid" nos logs

**Causa**: Algum provider (Anthropic, OpenAI, Gemini, etc.) tem chave inválida ou vazia.

**Verificar**:
```bash
# No .env
grep -E '^[A-Z_]+_API_KEY=' config/litellm/.env
```

**Providers configurados no container** (docker inspect):
- `ZAI_API_KEY` — GLM
- `MOONSHOT_API_KEY` — Kimi
- `DEEPSEEK_API_KEY` — DeepSeek
- `ANTHROPIC_API_KEY` — Claude (pode estar vazio)
- `OPENAI_API_KEY` — GPT (pode estar vazio)
- `GEMINI_API_KEY` — Gemini (pode estar vazio)

Modelos que funcionam sem Anthropic/OpenAI: glm, glm-flash, kimi, deepseek, r1.

---

### 4. LiteLLM não inicia

**Verificar**:
```bash
# Config existe?
test -f config/litellm/config.yaml && echo OK

# .env existe?
test -f config/litellm/.env && echo OK

# Docker compose
docker compose -f docker/litellm/docker-compose.yml up -d

# Logs
docker logs litellm-proxy -f
```

---

### 5. Claude Code / Ruflo não conecta

**Variáveis necessárias**:
```bash
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=$LITELLM_MASTER_KEY
```

**Em agldv03**: `source ~/.openclaw/zshrc-openclaw.env` já define isso.

**Em hosts cliente** (agldv04/05/06): `LITELLM_GATEWAY_URL=http://100.94.221.87:4000`

---

## Referências

- [LiteLLM Health Docs](https://docs.litellm.ai/docs/proxy/health)
- [CLAUDE-FLOW-LITELLM](CLAUDE-FLOW-LITELLM.md)
- [scripts/test-multi-model.sh](../scripts/test-multi-model.sh)

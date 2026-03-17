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

### 5. 401 "expected to start with sk-" / "Received=896f..."

**Causa**: O cliente está enviando **ZAI_API_KEY** (formato 896f...) em vez de **LITELLM_MASTER_KEY** (sk-...). LiteLLM exige chaves com prefixo `sk-`.

**Solução**:
```bash
# NUNCA use ZAI_API_KEY ou GLM_AUTH para Authorization no LiteLLM
export ANTHROPIC_BASE_URL=http://localhost:4000
export ANTHROPIC_AUTH_TOKEN=sk-litellm-default   # = LITELLM_MASTER_KEY
export ANTHROPIC_API_KEY=sk-litellm-default    # mesmo valor
```

**Validar**:
```bash
./scripts/litellm/validate-client-auth.sh
```

**Cursor**: O `.claude/settings.json` já define `ANTHROPIC_AUTH_TOKEN` e `ANTHROPIC_API_KEY` no env do projeto. Feche e reabra o Cursor para aplicar.

---

### 6. 400 "Invalid model name passed in model=glm-4.5-air" (anthropic_messages)

**Causa**: O config usava `anthropic/glm-4.5-air`, fazendo o LiteLLM rotear para a API Anthropic real ao invés da ZAI. O endpoint `/v1/messages` (formato Anthropic) não suporta modelos ZAI.

**Solução**: O config foi corrigido para `zai/glm-4.5-air` (formato LiteLLM para ZAI). O glm-air agora usa o endpoint correto.

**Fallback**: Se glm-4.5-air ainda falhar, glm-air tem fallback para glm-flash (gratuito).

**Reiniciar**: `docker compose -f docker/litellm/docker-compose.yml restart litellm-proxy`

---

### 7. Claude Code / Ruflo não conecta

**Causa comum**: O Cursor inicia como app gráfica e **não herda** variáveis do `.zshrc`. Ou `ANTHROPIC_API_KEY` está com ZAI key (896f...) em `~/.config/environment.d/`.

**Solução (agldv03)**: O projeto configura via `.claude/settings.json`:
- `ANTHROPIC_BASE_URL`: http://localhost:4000
- `ANTHROPIC_AUTH_TOKEN` e `ANTHROPIC_API_KEY`: sk-litellm-default (força chave correta)
- `apiKeyHelper`: fallback que lê `LITELLM_MASTER_KEY` de `config/litellm/.env`

**Verificar**:
```bash
./.claude/helpers/get-litellm-key.sh | head -c 5   # deve retornar "sk-li"
./scripts/litellm/validate-client-auth.sh
```

**Se ~/.config/environment.d/** tem ANTHROPIC_API_KEY=896f..., remova ou corrija para sk-litellm-default.

**Em hosts cliente** (agldv04/05/06): `LITELLM_GATEWAY_URL=http://100.94.221.87:4000`

---

### 7. 400 "Invalid model name passed in model=glm-4.5-air"

**Causa**: Uso de `anthropic/glm-4.5-air` com api_base ZAI fazia o endpoint `/v1/messages` rotear para a API Anthropic real, que não reconhece GLM.

**Solução aplicada** (config.yaml): trocar para `zai/glm-4.5-air` (formato LiteLLM ZAI). Fallback de glm-air para glm-flash.

**Se ainda falhar**: ZAI pode ter descontinuado glm-4.5-air — usar `glm-flash` (glm-4.7-flash, FREE) diretamente.

---

### 8. Implementações não visíveis nos agents

**Agentes especializados** (claude-code-agent, infra-agent, research-agent) e **modelos Cursor** (cursor-claude-sonnet, cursor-glm-5, etc.) estão no `config.yaml` principal. O `cursor-agent-config.yaml` **não é montado** no container — seu conteúdo foi integrado ao config principal.

**Para aplicar mudanças**:
```bash
docker compose -f docker/litellm/docker-compose.yml restart litellm-proxy
# ou
docker compose -f docker/litellm/docker-compose.yml up -d --force-recreate litellm-proxy
```

**Cursor**: Configurar Base URL = `http://100.94.221.87:4000` (ou localhost) e adicionar modelos custom: `cursor-claude-sonnet`, `cursor-glm-5`, `cursor-deepseek`.

---

## Referências

- [LiteLLM Health Docs](https://docs.litellm.ai/docs/proxy/health)
- [CLAUDE-FLOW-LITELLM](CLAUDE-FLOW-LITELLM.md)
- [scripts/test-multi-model.sh](../scripts/test-multi-model.sh)

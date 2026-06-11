# LiteLLM — Troubleshooting

> **Last Updated**: 2026-06-05  
> **Host canónico**: CT186 (agl-litellm) — LAN `http://192.168.0.186:4000`, Tailscale `http://100.125.249.8:4000`, path `/opt/agl-litellm`  
> **agldv03 (CT179):** LiteLLM descontinuado — não troubleshootar `:4000` em `100.94.221.87`

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

### 0. HTTP 401 — `token_not_found_in_db` / `Invalid proxy server token` (OpenClaw / wk45)

**Sintoma** (exemplo): `Received API Key = sk-...ault` · `Unable to find token in cache or LiteLLM_VerificationTokenTable`.

**OpenClaw (2026.3.x) — `models.providers.*.apiKey`**: usar o marcador **`LITELLM_API_KEY`** (nome exacto da variável de ambiente), **não** a string literal `${LITELLM_MASTER_KEY}` (não é expandida e o LiteLLM recebe Bearer inválido → 401 ou respostas vazias). O script `scripts/openclaw/ensure-litellm-gateway-env-from-opt.sh` alinha `litellm-gateway.env`, `models.json` do agente e **`openclaw.json`**; `sync-systemd-openclaw-env.sh` exporta `LITELLM_API_KEY` para o systemd do gateway.

**Causa**: O cliente envia **`sk-litellm-default`** como Bearer, mas o LiteLLM em **produção (CT186)** usa outro valor em **`LITELLM_MASTER_KEY`** (ficheiro **`/opt/agl-litellm/.env`**). O placeholder `sk-litellm-default` só é válido se o proxy estiver configurado **explicitamente** com essa string.

**Verificação no gateway (CT186)**:
```bash
# Via Proxmox — substitua pela chave real do .env
ssh root@100.107.113.33 'pct exec 186 -- grep ^LITELLM_MASTER_KEY= /opt/agl-litellm/.env'
curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer COPIE_A_CHAVE_AQUI" http://100.125.249.8:4000/v1/models
```

**Correção (aglwk45)**:
1. Obter **`LITELLM_MASTER_KEY`** real (mesma linha que o container `litellm-proxy` usa).
2. No `openclaw.json`, em **todos** os `models.providers.*` que apontam ao proxy LiteLLM, definir **`apiKey`** igual a essa chave (não usar `sk-litellm-default` se o servidor não a usar).
3. Se os providers usam **`http://localhost:4000`** mas o LiteLLM corre no **CT186**, alterar **`baseUrl`** para **`http://100.125.249.8:4000`** (Tailscale) ou **`http://192.168.0.186:4000`** (LAN).

**Automático (recomendado)**: na wk45, em Git Bash a partir do repo:

`bash scripts/openclaw/wk45-sync-openclaw-litellm.sh` → aplica `config/openclaw/wk45-sync-openclaw-litellm.jq` (substitui `sk-litellm-default` e `localhost`/`127.0.0.1:4000). Depois: `openclaw gateway restart`. Exemplo opcional de env: `config/openclaw/wk45-litellm-gateway.env.example`.

**Variáveis Windows**: alinhar `ANTHROPIC_AUTH_TOKEN` e `LITELLM_MASTER_KEY` com o **mesmo** valor do `/opt/litellm/.env` (ver `docs/AGLWK45-SETUP.md`).

**TUI no próprio agldv03**: O erro com sufixo de chave **diferente** da master (ex.: `...nTG0` no log vs `...er-key` no servidor) indica que o processo do TUI ainda envia **outra** API key. Alinhar `apiKey` / env do provider com `grep ^LITELLM_MASTER_KEY= /opt/litellm/.env` (sem aspas extra em `~/.openclaw/litellm-gateway.env`). Diagnóstico sem expor a chave: `bash scripts/litellm/diag-litellm-key-mismatch.sh` no host.

---

### 0b. Embeddings (`/v1/embeddings`) — OpenClaw memory / HTTP 400

**Sintoma**: Erro ao indexar ou pesquisar memória no OpenClaw com `model: text-embedding-3-small` (ex.: 400 *Invalid model name* ou falha upstream OpenAI).

**Configuração no repo**: `config/litellm/config.yaml` inclui `text-embedding-3-small`, `text-embedding-3-large` e `text-embedding-ada-002` com `api_key: os.environ/OPENAI_API_KEY`. Sem estas linhas o proxy não reconhece o nome do modelo.

**Chave OpenAI no host**: Em cada servidor, `/opt/litellm/.env` deve ter **`OPENAI_API_KEY=`** válida (carregada pelo container `litellm-proxy`). O script `scripts/litellm/replicate-all-hosts.sh` faz *merge* do `config/litellm/.env` do repo: se aparecer **`.env (0 vars)`**, significa que o ficheiro local não tinha valores não vazios a aplicar — **não apaga** chaves já presentes no servidor.

**Teste no agldv03** (substituir a chave):

```bash
export LITELLM_MASTER_KEY=$(grep ^LITELLM_MASTER_KEY= /opt/litellm/.env | cut -d= -f2-)
curl -sS -H "Authorization: Bearer $LITELLM_MASTER_KEY" -H "Content-Type: application/json" \
  http://127.0.0.1:4000/v1/embeddings \
  -d '{"model":"text-embedding-3-small","input":"teste"}' | head -c 400
```

Resposta esperada: JSON com `data[0].embedding` (vector). Se faltar `OPENAI_API_KEY` no `.env` do host, o erro costuma indicar falha ao chamar a API OpenAI.

---

### 1. HTTP 401 — "No api key passed in"

**Causa**: O LiteLLM exige autenticação na maioria dos endpoints.

**Endpoints que NÃO exigem auth** (use para health checks):
- `/health/liveliness` — "I'm alive!"
- `/health/readiness` — status do proxy, DB, cache

**Endpoints que EXIGEM auth**:
- `/health` — health completo dos modelos (faz chamadas reais às APIs)
- `/models` — lista de modelos
- `/chat/completions` — inferência
- `/v1/embeddings` — embeddings (OpenClaw memory, clientes OpenAI-compat)

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

### 3. Claude-flow trava 20+ min sem retorno

**Causa**: (a) `request_timeout` muito curto; (b) modelos Qwen3/DeepSeek-R1 com **thinking** activo → `content` vazio / erro 500; (c) Ollama **cold load** (troca de modelo 8–12 GB na VM310) demora 60–180s.

**Soluções aplicadas (2026-06-11)**:
- `request_timeout: 240` em `litellm_settings` (CT186)
- Callback `agl_glm_flash_params.py` + `think: false` nas rotas Ollama (`agl-primary`, `ollama-qwen*`)
- Claude fallbacks: preferir cloud APIs; Ollama só em aliases dedicados
- Smoke: `bash scripts/litellm/test-ollama-litellm-content.sh <alias>` (timeout curl **240s**)

**Deploy CT186**: `bash scripts/litellm/deploy-litellm-callbacks-ct186.sh` (force-recreate + scripts smoke em `/opt/agl-litellm/scripts/`)

---

### 4. "API key not valid" nos logs

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

### 5. LiteLLM não inicia

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

### 6. 401 "expected to start with sk-" / "Received=896f..."

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

### 7. 400 "Invalid model name passed in model=glm-4.5-air" (anthropic_messages)

**Causa**: O config usava `anthropic/glm-4.5-air`, fazendo o LiteLLM rotear para a API Anthropic real ao invés da ZAI. O endpoint `/v1/messages` (formato Anthropic) não suporta modelos ZAI.

**Solução**: O config foi corrigido para `zai/glm-4.5-air` (formato LiteLLM para ZAI). O glm-air agora usa o endpoint correto.

**Fallback**: Se glm-4.5-air ainda falhar, glm-air tem fallback para glm-flash (gratuito).

**Reiniciar**: `docker compose -f docker/litellm/docker-compose.yml restart litellm-proxy`

---

### 8. Claude Code / Ruflo não conecta

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

**Em hosts cliente** (sem LiteLLM local): `LITELLM_GATEWAY_URL=http://100.125.249.8:4000` (CT186 Tailscale) ou `http://192.168.0.186:4000` (LAN)

---

### 8a. agldv04 — Erro ao usar Claude Code/Claude-Flow após `cclitellm`

**Causa**: O `cclitellm` antigo usava `sk-litellm-default` fixo, mas o LiteLLM em execução (CT186) espera a chave de `/opt/agl-litellm/.env`. Ou o `.claude/settings.json` usa localhost sem stack local.

**Solução** (uma das opções):

1. **Usar cclitellm atualizado** (recomendado para terminal):
   ```bash
   cd /caminho/agl-hostman
   source config/openclaw/zshrc-openclaw.env
   cclitellm
   claude-flow hive-mind spawn "tarefa" --claude
   ```
   O `cclitellm` em `zshrc-openclaw.env` usa `get-litellm-key.sh` (chave de /opt/litellm/.env ou config/litellm/.env).

2. **Aplicar settings para agldv04** (para Cursor/Claude Code na IDE):
   ```bash
   cp .claude/settings.agldv04.json .claude/settings.json
   ```
   Depois feche e reabra o Cursor/Claude Code.

3. **Verificar conectividade** antes de usar:
   ```bash
   # No agldv04 — deve retornar lista de modelos
   curl -s -H "Authorization: Bearer sk-litellm-default" \
        http://100.125.249.8:4000/v1/models | jq -r '.data[].id' | head -5
   ```

4. **Confirmar que LiteLLM está rodando no CT186**:
   ```bash
   curl -sf http://100.125.249.8:4000/health/readiness
   # ou: ssh root@100.107.113.33 'pct exec 186 -- curl -sf http://127.0.0.1:4000/health/readiness'
   ```

5. **Se usar `cclitellm` no terminal**: Use `source config/openclaw/zshrc-openclaw.env` e depois `cclitellm` — a função agora usa `get-litellm-key.sh` (chave de /opt/litellm/.env ou config/litellm/.env). O Cursor iniciado pelo menu **não herda** variáveis do shell; use settings.agldv04.json para Cursor.

**Erros comuns**:
- `Connection refused` / `ECONNREFUSED` → URL errada ou LiteLLM parado no CT186
- `401 Unauthorized` → ANTHROPIC_AUTH_TOKEN com ZAI key (896f...) em vez de sk-litellm-default

---

### 8b. 400 "Invalid model name passed in model=glm-4.5-air"

**Causa**: Uso de `anthropic/glm-4.5-air` com api_base ZAI fazia o endpoint `/v1/messages` rotear para a API Anthropic real, que não reconhece GLM.

**Solução aplicada** (config.yaml): trocar para `zai/glm-4.5-air` (formato LiteLLM ZAI). Fallback de glm-air para glm-flash.

**Se ainda falhar**: ZAI pode ter descontinuado glm-4.5-air — usar `glm-flash` (glm-4.7-flash, FREE) diretamente.

---

### 9. Implementações não visíveis (legado) nos agents

**Agentes especializados** (claude-code-agent, infra-agent, research-agent) e **modelos Cursor** (cursor-claude-sonnet, cursor-glm-5, etc.) estão no `config.yaml` principal. O `cursor-agent-config.yaml` **não é montado** no container — seu conteúdo foi integrado ao config principal.

**Para aplicar mudanças**:
```bash
docker compose -f docker/litellm/docker-compose.yml restart litellm-proxy
# ou
docker compose -f docker/litellm/docker-compose.yml up -d --force-recreate litellm-proxy
```

**Cursor**: Base URL = `http://100.125.249.8:4000/cursor` (ou LAN `http://192.168.0.186:4000/cursor`); modelos custom: `cursor-claude-sonnet`, `cursor-glm-5`, `cursor-deepseek`. Ver `docs/CURSOR-LITELLM-INTEGRATION.md`.

---

### 10. Claude-flow — "dangerously-skip-permissions cannot be used with root/sudo"

**Causa**: O CLI do Claude rejeita o flag quando executado como root.

**Controle via IS_SANDBOX**:
- `IS_SANDBOX=1` → `cc`, `cl`, `dsp`, `claude-hierarchical` e hive-mind usam `--dangerously-skip-permissions`
- Definido em: `~/.zshrc`, devcontainer `containerEnv`, `~/.claude/settings.json` (defaultMode: bypassPermissions)
- **Exceção**: root — o CLI rejeita; use usuário não-root (ex: vscode no devcontainer) ou `--no-auto-permissions`

**Para desabilitar**: `export IS_SANDBOX=0` ou `unset IS_SANDBOX`

---

### 11. `404 No endpoints found for google/gemini-2.5-flash-lite:free` (ex.: Telegram no **fgsrv06**)

**Causa A (mais comum com OpenClaw)**: O modelo **principal** é `zai/glm-5`, mas o LiteLLM só tinha `glm-5` no `model_list`. Pedidos a `zai/glm-5` falhavam (**400 Invalid model name**); o gateway seguia para **fallbacks** e a mensagem de erro podia mostrar **Gemini** (`google/...:free`) em vez do GLM — sintoma confuso. **Correção**: entradas explícitas `zai/glm-5`, `zai/glm-4.7`, `zai/glm-4.7-flash` no `config/litellm/config.yaml` (e sync para hosts). Teste: `curl …/v1/chat/completions` com `"model":"zai/glm-5"`.

**Causa B**: O ID `google/gemini-2.5-flash-lite:free` não está no `model_list` nesse proxy (config em falta ou não reiniciada).

**Solução B**: No `config/litellm/config.yaml` existem aliases (`google/gemini-2.5-flash-lite`, `google/gemini-2.5-flash-lite:free` → `gemini/gemini-2.5-flash-lite`, e `openrouter/google/gemini-2.5-flash-lite:free` para OpenRouter). Replicar (`./scripts/litellm/replicate-all-hosts.sh`) e recriar o container `litellm-proxy`.

**Alternativa no cliente**: usar **`gemini-lite`** ou `openrouter/google/gemini-2.5-flash-lite:free` conforme documentado em `docs/OPENCLAW.md`.

### 12. OpenClaw: `models.providers.kimi.models: expected array, received undefined`

**Causa**: O provider **`kimi`** (ou **`moonshot`**) ficou só com `baseUrl`/`apiKey` (ex.: após patch jq que define campos sem preservar `models`).

**Solução**: `scripts/openclaw/wk45-sync-openclaw-litellm.cjs` repõe `models` em **kimi**, **moonshot** e **google** se faltarem. Correr de novo o deploy QEMU ou, na VM: `node wk45-sync-openclaw-litellm.cjs` com `LITELLM_MASTER_KEY` definido. Ou `openclaw doctor --fix` se o CLI sugerir.

---

## Referências

- [LiteLLM Health Docs](https://docs.litellm.ai/docs/proxy/health)
- [CLAUDE-FLOW-LITELLM](CLAUDE-FLOW-LITELLM.md)
- [scripts/test-multi-model.sh](../scripts/test-multi-model.sh)

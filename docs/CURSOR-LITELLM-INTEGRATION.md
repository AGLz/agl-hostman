# Cursor Agent Composer 2 Fast + LiteLLM Integration

> **Last Updated**: 2026-06-05
> **Gateway canónico**: CT186 — Tailscale `http://100.125.249.8:4000` · LAN `http://192.168.0.186:4000`
> **Status**: Beta - Agent mode has known limitations

## Visão Geral

Integração do Cursor IDE com o gateway LiteLLM. O modelo **Composer 2 / Composer 2 Fast** é [proprietário da Cursor](https://cursor.com/docs/models/cursor-composer-2) (focado em agente, ferramentas e edição); **não existe API pública** para o mesmo modelo fora do produto. Neste repositório, `cursor-composer` e `cursor-composer-2-fast` usam **`openai/gpt-5.4-mini`** na rota OpenAI ([GPT-5.4 mini](https://platform.openai.com/docs/models/gpt-5.4-mini), ~**400K** contexto, ~\$0.75/M in / \$4.50/M out em mar/2026). No proxy LiteLLM mantêm-se também os **aliases públicos** `openai/gpt-5.3-chat-latest` e `gpt-5.3-instant` (mesmo backend **gpt-5.4-mini**) para clientes e docs antigos.

## Limitações Conhecidas

| Modo Cursor | Suporte Custom API Key | Status |
|-------------|------------------------|--------|
| **Ask** | ✅ Suportado | Funcional |
| **Plan** | ✅ Suportado | Funcional |
| **Agent** | ❌ Limitado | Não suporta custom keys ainda |

### Issue Aberto (Fev 2026)

Cursor Agent envia formato **Responses API** ao invés de **Chat Completions** para o endpoint `/chat/completions`:
- [GitHub Issue #19800](https://github.com/BerriAI/litellm/issues/19800)
- [Forum Discussion](https://forum.cursor.com/t/cursor-agent-sends-responses-api-format-to-chat-completions-endpoint/153019)

## Configuração

### 1. Configurar Base URL no Cursor

1. Abrir **Cursor → Settings → Cursor Settings → Models**
2. Habilitar **Override OpenAI Base URL**
3. Inserir URL do proxy com sufixo `/cursor`:

```
http://100.125.249.8:4000/cursor
```

LAN (desde rede AGL):

```
http://192.168.0.186:4000/cursor
```

Para acesso local (só se LiteLLM correr no mesmo host):
```
http://localhost:4000/cursor
```

### 2. Criar Virtual Key no LiteLLM

```bash
# Via API
curl -X POST http://localhost:4000/key/generate \
  -H "Authorization: Bearer $LITELLM_MASTER_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "cursor-user",
    "key_alias": "cursor-key",
    "models": ["cursor-composer", "cursor-composer-2-fast", "cursor-claude-sonnet", "cursor-glm-5", "cursor-deepseek"],
    "max_budget": 50
  }'
```

### 3. Adicionar Modelos Customizados no Cursor

1. Clicar em **+ Add Custom Model**
2. Adicionar os nomes públicos dos modelos:
   - `cursor-composer` (Composer 2 Fast → **gpt-5.4-mini**; alias `openai/gpt-5.3-chat-latest` equivalente)
   - `cursor-composer-2-fast` (idem)
   - `cursor-claude-sonnet`
   - `cursor-claude-opus`
   - `cursor-glm-5`
   - `cursor-deepseek`
   - `cursor-gpt-4o`

### 4. Testar

```bash
# Modo Ask (Cmd+L / Ctrl+L)
# Selecionar modelo cursor-claude-sonnet
# Enviar mensagem de teste
```

## Modelos Disponíveis

| Modelo | Descrição | Uso |
|--------|-----------|-----|
| `cursor-composer` | Composer 2 Fast → **gpt-5.4-mini** (aliases `gpt-5.3-chat-latest` / `gpt-5.3-instant` no gateway) | Fluxo tipo Composer rápido |
| `cursor-composer-2-fast` | Idem (nome explícito no Cursor) | Idem |
| `cursor-claude-sonnet` | Claude Sonnet 4.6 | Código geral |
| `cursor-claude-opus` | Claude Opus 4.6 | Raz. complexo |
| `cursor-glm-5` | GLM-5 (Z.AI) | Custo reduzido |
| `cursor-deepseek` | DeepSeek V3.2 | Excelente para código |
| `cursor-gpt-4o` | GPT-4o | Fallback robusto |

## Fallbacks Configurados

```
cursor-composer → cursor-claude-sonnet → cursor-claude-opus → cursor-glm-5 → cursor-deepseek
cursor-claude-sonnet → cursor-composer → cursor-composer-2-fast → …
cursor-glm-5 → cursor-deepseek → cursor-gpt-4o
```

## MCP Server Integration

O Cursor também pode conectar aos MCP servers do LiteLLM:

```json
// mcp.json
{
  "mcpServers": {
    "litellm": {
      "url": "http://localhost:4000/everything/mcp",
      "type": "http",
      "headers": {
        "Authorization": "Bearer sk-YOUR_VIRTUAL_KEY"
      }
    }
  }
}
```

## Troubleshooting

| Problema | Solução |
|----------|---------|
| Modelo não responde | Verificar se Base URL termina com `/cursor` |
| Erro 401 | Regenerar chave; garantir que começa com `sk-` |
| Agent mode não funciona | Limitação conhecida - usar Ask/Plan modes |
| tool_choice error | Issue #19800 - aguardar fix ou usar modelos OpenAI |

## Referências

- [Composer 2 (Cursor)](https://cursor.com/docs/models/cursor-composer-2)
- [LiteLLM Cursor Integration](https://docs.litellm.ai/docs/tutorials/cursor_integration)
- [Cursor MCP Documentation](https://cursor.com/en-US/docs/context/mcp)
- [GitHub Issue #19800](https://github.com/BerriAI/litellm/issues/19800)

# Cursor Agent Composer 1.5 + LiteLLM Integration

> **Last Updated**: 2026-03-13
> **Status**: Beta - Agent mode has known limitations

## Visão Geral

Integração do Cursor IDE (Agent Composer 1.5) com o gateway LiteLLM para usar modelos Claude, GLM-5, DeepSeek e outros.

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
http://100.94.221.87:4000/cursor
```

Para acesso local:
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
    "models": ["cursor-claude-sonnet", "cursor-glm-5", "cursor-deepseek"],
    "max_budget": 50
  }'
```

### 3. Adicionar Modelos Customizados no Cursor

1. Clicar em **+ Add Custom Model**
2. Adicionar os nomes públicos dos modelos:
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
| `cursor-claude-sonnet` | Claude Sonnet 4.6 | Código geral |
| `cursor-claude-opus` | Claude Opus 4.6 | Raz. complexo |
| `cursor-glm-5` | GLM-5 via OpenRouter | Custo reduzido |
| `cursor-deepseek` | DeepSeek V3.2 | Excelente para código |
| `cursor-gpt-4o` | GPT-4o | Fallback robusto |

## Fallbacks Configurados

```
cursor-claude-sonnet → cursor-claude-opus → cursor-glm-5 → cursor-deepseek
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

- [LiteLLM Cursor Integration](https://docs.litellm.ai/docs/tutorials/cursor_integration)
- [Cursor MCP Documentation](https://cursor.com/en-US/docs/context/mcp)
- [GitHub Issue #19800](https://github.com/BerriAI/litellm/issues/19800)

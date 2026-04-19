# Hermes Agent (NousResearch) no agldv03

> **Host**: CT179 / agldv03 (Tailscale `100.94.221.87`)  
> **Última verificação no servidor**: 2026-04-19  
> **Nota**: Não commitar `~/.hermes/.env`, `config.yaml` com chaves nem `state.db`.

## O que é (pesquisa web + contexto AGL)

**Hermes Agent** é o agente CLI da **NousResearch**, distinto do modelo *Hermes 3* no LiteLLM/OpenRouter. Documentação oficial:

- [Hermes Agent — documentação](https://hermes-agent.nousresearch.com/)
- [CLI](https://hermes-agent.nousresearch.com/docs/user-guide/cli)
- [Configuração](https://hermes-agent.nousresearch.com/docs/user-guide/configuration)
- [Migrar de OpenClaw](https://hermes-agent.nousresearch.com/docs/guides/migrate-from-openclaw) — comando `hermes claw migrate` (lê `~/.openclaw/` por defeito)

No agldv03 convive com **OpenClaw** (Docker) e **LiteLLM** (`litellm-proxy`); o Hermes Agent usa normalmente **LiteLLM local** como backend OpenAI-compatible.

## Diretório `~/.hermes` no agldv03 (root)

Estrutura observada no servidor:

| Caminho | Função |
|--------|--------|
| `config.yaml` | Modelo, provider, compressão de contexto, toolsets, personalidades, etc. |
| `.env` | Segredos e variáveis (não versionar) |
| `SOUL.md` | Identidade do agente |
| `sessions/` | Metadados de sessões (JSON) |
| `logs/agent.log` | Log principal do agente |
| `logs/errors.log` | Erros (ex.: TUI `prompt_toolkit`, `KeyboardInterrupt` ao sair) |
| `memories/` | Memória persistente |
| `skills/` | Skills do agente |
| `hermes-agent/` | Checkout/código do CLI (venv em `hermes-agent/venv`) |
| `state.db` | Estado local (SQLite) |

## Configuração relevante (sem segredos)

Valores **não sensíveis** confirmados em `config.yaml`:

- **Provider**: `custom` com `base_url: http://localhost:4000` (gateway **LiteLLM** no próprio CT).
- **Modelo por defeito**: `qwen-coder` (`model.default`).
- **Fallback de modelo** (campo `model.fallback`): `gemini-lite`.
- **`fallback_providers: []`** — lista **vazia**. Isto alinha com avisos na TUI do tipo *«No fallback providers configured»*: quando o modelo principal falha ou devolve conteúdo vazio após tool calls, **não há segunda fila de providers** configurada (além do fallback simples de nome de modelo acima, conforme comportamento do Hermes Agent).
- **Compressão de contexto** (`compression`): `enabled: true` — corresponde a mensagens como *«compacting context»* / *«Session compressed»* na TUI quando o histórico é longo.

## Logs úteis para diagnóstico

```bash
# No agldv03 (como utilizador que corre o Hermes, ex.: root)
tail -100 ~/.hermes/logs/agent.log
tail -100 ~/.hermes/logs/errors.log
```

Exemplos de linhas úteis em `agent.log`: pedidos ao auxiliar (*Auxiliary compression*, *flush_memories*), deteção de contexto via LiteLLM (*Could not detect context length for model 'qwen-coder' — defaulting to 128,000 tokens*).

## Relação com o erro «empty response / no fallback»

1. **Resposta vazia do modelo** após chamadas a ferramentas → retries na TUI; com **sem `fallback_providers`**, a mensagem de falha total pode citar fallback ausente.  
2. **Sessão muito comprimida** → aviso de degradação de precisão; preferir nova sessão (`/new` ou equivalente na versão instalada).  
3. **Melhorias possíveis** (a validar na doc da versão instalada): preencher `fallback_providers` com IDs compatíveis com o LiteLLM local; definir `model.context_length` se o probe ao proxy falhar; rever quotas/upstream no LiteLLM.

## Ligações no repositório

- LiteLLM: `config/litellm/config.yaml` (aliases `qwen-coder`, `gemini-lite`, etc.).
- OpenClaw (outro agente): `docs/OPENCLAW.md`.

# LiteLLM no agldv03 — verificação (SSH + chamadas reais)

> **Host**: agldv03 (CT179), `http://127.0.0.1:4000` no próprio CT  
> **Chave de API**: usar a mesma que o Hermes/OpenClaw (`model.api_key` em `~/.hermes/config.yaml`) — **não** commitar.  
> **Script**: `scripts/litellm-smoke-test-remote.sh` (executar no servidor com `bash`; em Windows, alimentar o SSH com pipe e `tr -d '\r'` se necessário).

## Logs analisados (2026-04-19)

### `litellm-proxy` (Docker)

- Tráfego recente: sobretudo `GET /health/readiness` 200, `POST` chat/completions 200, `GET /v1/models` 200.
- Clientes vistos: `127.0.0.1`, `192.168.32.x` (rede Docker), `100.117.146.21` (ex.: aglwk45 / Tailscale).

### Hermes Agent (`~/.hermes/logs/`)

- **`agent.log`**: uso consistente do provider **custom** + modelo **`qwen-coder`** em `http://localhost:4000`; tarefas auxiliares (visão, compressão de contexto, flush de memórias) no mesmo endpoint.
- **Aviso recorrente**: `Could not detect context length for model 'qwen-coder'` — o cliente assume 128k até se definir `model.context_length` em `config.yaml` (opcional).
- **`errors.log`**: stack traces de **prompt_toolkit** ao encerrar a TUI (`KeyboardInterrupt` durante redraw da status bar) — típico de Ctrl+C/resize; não indica falha do LiteLLM por si só.
- **Gateway Hermes**: avisos sobre allowlists e ausência de plataformas de mensagens (Telegram etc.) se não estiverem configuradas.

## Lista de modelos no proxy

Em **2026-04-19** o endpoint `GET /v1/models` reportou **87** entradas `id`. Exemplos de aliases **free** / OpenRouter usados na matriz abaixo: `or-hermes-free`, `or-nemotron-super-free`, `or-llama-3.3-70b-free`, `openrouter-free`, etc.

**Nota**: nomes como `or-nemotron-free` ou `or-llama-free` **não** existem neste proxy — usar os `id` devolvidos por `/v1/models`.

## Smoke tests (`POST /v1/chat/completions`, `max_tokens` baixo)

Resumo de execução real no servidor (mensagem de teste curta tipo «Reply exactly: PONG»):

| Modelo / alias | Resultado típico |
|----------------|------------------|
| `qwen-coder` | HTTP 200, resposta OK |
| `glm-flash` | HTTP 200 |
| `gemini-lite` | HTTP 200 |
| `or-hermes-free` | HTTP 200 |
| `or-nemotron-super-free` | HTTP 200 |
| `openrouter/openrouter/free` | HTTP 200 (respostas podem ser verbosas) |
| `glm-flash-2` | HTTP **400** — nome inválido neste proxy |
| `or-minimax-m2.5-free` | Erro **400** upstream (ex.: limites de contexto / payload) num teste mínimo — rever payload ou doc do modelo |
| `or-step-3.5-free` | Removido do `config.yaml` do repo (404 upstream recorrente) |
| `or-llama-3.3-70b-free` | **429** rate limit upstream (OpenRouter free) — mensagem sugere retry ou chave própria |
| `or-qwen3-coder-free` | Removido do `config.yaml` do repo (quota 429); usar `qwen-coder` (DashScope) |
| `openrouter-free` | Verificar corpo JSON (pode exigir parsing cuidadoso em scripts) |

Conclusão: o caminho **Hermes → LiteLLM → `qwen-coder` / `glm-flash` / `gemini-lite` / `or-hermes-free`** está **saudável** para chamadas simples. Os alias **OpenRouter :free** oscilam com **429** e **404** conforme quota e disponibilidade upstream.

## Ollama (CT200 / AGLSRV1)

O **Ollama com GPU** não corre no agldv03 (CT179). Está no **CT200** do **AGLSRV1** (Proxmox `192.168.0.245`, `pct exec 200`).

| Acesso | URL |
|--------|-----|
| LAN (LiteLLM noutros CTs na mesma rede) | `http://192.168.0.200:11434` |
| Tailscale (CT200) | `http://100.116.57.111:11434` |

No repositório, `config/litellm/config.yaml` usa **`192.168.0.200:11434`** para todas as entradas `api_base` Ollama; `config/litellm/config-remote.yaml` usa o IP Tailscale. Testes de conectividade a partir do contentor `litellm-proxy` no agldv03 devem usar **este IP**, não `127.0.0.1` nem o IP do próprio CT179 — aí o serviço Ollama **não** existe.

## Referências

- Hermes + `~/.hermes`: `docs/HERMES-AGENT-AGLDV03.md`
- Ollama CT200 (API, firewall): `docs/ollama-api-guide.md`
- Matriz de modelos no repo: `config/litellm/config.yaml` (pode diferir ligeiramente do `config.yaml` em produção no CT)

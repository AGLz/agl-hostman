# Bateria LiteLLM full — CT186

**Gerado:** 2026-06-15T15:13:40.901Z  
**Gateway:** `http://100.125.249.8:4000`  
**Modelos:** 103  
**Resultado:** 70 OK · 14 aviso · 19 falha  

## Por provider

| Provider | OK | Aviso | Falha |
|----------|-----|-------|-------|
| anthropic | 10 | 0 | 1 |
| deepseek | 4 | 0 | 6 |
| google | 2 | 6 | 0 |
| groq | 3 | 0 | 2 |
| moonshot | 4 | 0 | 0 |
| ollama | 6 | 0 | 3 |
| openai | 11 | 0 | 1 |
| openrouter | 10 | 8 | 0 |
| zai | 20 | 0 | 6 |

## Falhas

| Modelo | HTTP | Erro |
|--------|------|------|
| `agl-primary-zai-glm-flash` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |
| `glm-4.7` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |
| `deepseek-v3.2` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `deepseek-v4-flash` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `deepseek-v4-pro` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `cursor-claude-opus-4-6` | 400 | litellm.BadRequestError: AnthropicException - {"type":"error","error":{"type":"invalid_request_error","message":"Your cr |
| `cursor-deepseek` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `gpt-4.4-mini` | 404 | litellm.NotFoundError: OpenAIException - The model `gpt-4.4-mini` does not exist or you do not have access to it.No fall |
| `qwen-max` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |
| `openai/qwen3-coder-plus` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `qwen3.5-flash` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |
| `groq-gpt-oss-120b` | 200 | sem content/reasoning útil |
| `groq-gpt-oss-120b-k2` | 200 | sem content/reasoning útil |
| `ollama-qwen3-4b` | 200 | sem content/reasoning útil |
| `openai/ollama-qwen3-4b` | 200 | sem content/reasoning útil |
| `ollama-qwen3-4b-fast` | 200 | sem content/reasoning útil |
| `qwen/qwen-coder` | 402 | litellm.BadRequestError: DeepseekException - {"error":{"message":"Insufficient Balance","type":"unknown_error","param":n |
| `qwen/qwen3.5-plus` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |
| `qwen/qwen-turbo` | 500 | litellm.InternalServerError: InternalServerError: OpenAIException - Invalid response object Traceback (most recent call  |

## Avisos (opcional / rate limit)

| Modelo | HTTP |
|--------|------|
| `gemini-3.1-pro` | 401 |
| `gemini-2.5-pro` | 401 |
| `google/gemini-2.5-flash-lite` | 401 |
| `google/gemini-2.5-flash-lite:free` | 401 |
| `openrouter/google/gemini-2.5-flash-lite:free` | 401 |
| `google/gemini-2.5-flash` | 401 |
| `gemini-2.0` | 401 |
| `or-glm-air-free` | 401 |
| `openrouter/nvidia/nemotron-3-super-120b-a12b:free` | 401 |
| `openrouter/minimax/minimax-m2.5:free` | 401 |
| `openrouter/meta-llama/llama-3.3-70b-instruct:free` | 401 |
| `openrouter/google/gemma-3-4b-it:free` | 401 |
| `openrouter/mistralai/mistral-small-3.1-24b-instruct:free` | 401 |
| `openrouter/nousresearch/hermes-3-llama-3.1-405b:free` | 401 |


JSON completo: `docs/litellm-battery-full-20260615.json`


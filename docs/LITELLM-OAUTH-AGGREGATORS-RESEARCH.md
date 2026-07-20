# LiteLLM vs aggregators OAuth (Plus/Pro)

> **Fonte de verdade:** llm-wiki — [[LLM Aggregators OAuth vs LiteLLM AGL]]  
> Path: `/mnt/overpower/apps/dev/agl/llm-wiki/wiki/LLM-Aggregators-OAuth-vs-LiteLLM-AGL.md`

## Resumo

Não há agregador oficial equivalente ao LiteLLM que autentique via OAuth nas contas **ChatGPT Plus** / **Claude Pro** e exponha isso de forma estável à AI Agency.

| Caminho | Ferramentas |
|---------|-------------|
| Control plane (manter) | LiteLLM CT186 |
| Catálogo / keys | OpenRouter, Portkey, Helicone, Bifrost |
| OAuth consumer → API (lab, ToS risco) | auth2api, shunt, CodeGate, caliber |

Recomendação Agency: LiteLLM + Z.AI/Groq/Ollama; API billing real ou OpenRouter quando houver budget; bridges OAuth só como sidecar experimental.

## Spike auth2api

Ver `docs/AUTH2API-SPIKE.md` — `bash scripts/auth2api/bootstrap.sh` → login → `up.sh`.

# CLAUDE.md — Contexto do workspace (agl-hostman)

## Identidade

Este repositório é **agl-hostman**: infraestrutura e automação AGL, API Node, app Laravel em `src/`, configs LiteLLM, Docker e documentação operacional.  
Contexto **TurboFlow / Ruflo** pode coexistir com **Cursor** (regras em `.cursor/rules/`, incl. Laravel Boost e guia primário em PT).

## Projeto agl-hostman (factos do codebase)

| Área | Local |
|------|--------|
| API Node (Fastify) | `src/api/` — entrada `npm run dev` / `server.js` |
| Laravel 12 + Pest | árvore em `src/` (`artisan`, `composer.json`, `app/`, `tests/`, etc.) |
| Gateway LLM | `config/litellm/config.yaml`, `config/litellm/config-remote.yaml` |
| Cursor + LiteLLM | `docs/CURSOR-LITELLM-INTEGRATION.md`; `cursor-composer*` → **gpt-5.4-mini**; aliases `openai/gpt-5.3-chat-latest` / `gpt-5.3-instant` → mesmo backend |
| OpenClaw + Claude Code → LiteLLM local | `scripts/deploy-openclaw-config.sh` copia `config/openclaw/litellm-gateway-local.env` → `~/.openclaw/litellm-gateway.env` e aplica `openclaw-litellm-local.jq`; `.claude/settings.json` define `ANTHROPIC_BASE_URL` / `LITELLM_GATEWAY_URL` = `http://localhost:4000` |
| OpenClaw (Windows, clone + pnpm) | `docs/OPENCLAW.md` — checkout em disco local (ex. `C:\Users\Administrator\src\openclaw`), `pnpm link --global`; não clonar em shares SMB (symlinks do pnpm). |
| Testes Node (raiz) | `tests/api/`, `tests/unit/`, `tests/integration/` — `npm test` |
| Infra docs | `docs/INFRA.md`, `docs/README.md` |
| Beads / bd | `.beads/`; fluxo em `AGENTS.md` |
| **agl-hostman no agldv03 (CT179)** | `/mnt/overpower/apps/dev/agl/agl-hostman` (NFS overpower; alinhar com U:\… na wk45) |

Antes de alterações amplas: seguir convenções em **sibling files** e em `.cursor/rules/`.

## Protocolo de memória / tarefas (sessão)

### Início
1. `bd ready --json` (se bd configurado) para trabalho desbloqueado  
2. Revisar objetivos da sessão e ficheiros tocados recentemente  
3. Skills AgentDB / Ruflo quando aplicável ao teu fluxo  

### Durante
- Roadmap, blockers, decisões persistentes → **bd** (`bd create`, dependências `discovered-from`)  
- Padrões recorrentes → skills / docs em `docs/`  

### Fim
- Fechar ou abrir issues em bd para continuidade  
- Se alteraste código: correr **`npm test`** (e testes PHP afetados em `src/` quando relevante)  
- Push conforme política da equipa (ver `AGENTS.md`)  

## Isolamento (agentes paralelos)

- Preferir **git worktree** por agente em trabalhos paralelos:  
  `git worktree add .worktrees/agent-N -b agent-N/nome-tarefa`  
- Evitar `--dangerously-skip-permissions` fora de ambientes containerizados  

## Equipas / swarms (Ruflo, opcional)

- `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` pode estar ativo noutros fluxos  
- Limite sensato de profundidade: lead → sub-agentes, sem recursão infinita  
- Muitos agentes bloqueados → escalar humano  

## Routing de modelos (referência)

- Tarefas pesadas / arquitetura: **Claude Opus 4.6** (ou equivalente disponível na tua stack)  
- Implementação padrão: **Claude Sonnet 4.6**  
- Tarefas leves / formatação: **Claude Haiku 4.5**  
No **LiteLLM** deste repo os aliases Cursor aparecem como entradas em `config/litellm/config.yaml` (nomes `cursor-*`).  

## Stack de orquestração (opcional / Ruflo)

- Orquestração: **`ruflo`** (global: `npm i -g ruflo@latest @claude-flow/cli@latest`) ou `npx ruflo@latest` no projeto  
- Binário **`claude-flow`**: pacote **`@claude-flow/cli`** (alinhado com `ruflo`); evitar o pacote npm antigo só `claude-flow`  
- Memória: bd (beads), AgentDB / `ruflo memory` conforme tooling instalado  
- Grafo de código: GitNexus (`npx gitnexus analyze` no root do repo)  
- OpenSpec / plugins: ver documentação Ruflo se ativo na tua máquina  

## GitNexus

- Indexar: `npx gitnexus analyze` (a partir da raiz de **agl-hostman**)  
- Útil para impacto antes de refactors grandes  

## Guardrails de custo

- Preferir tier mais barato para edições mecânicas  
- Monitorizar uso no dashboard do fornecedor / LiteLLM  

## Codebase intelligence

A frase "auto-creates AGENTS.md" nos templates genéricos **não** substitui manutenção manual destes ficheiros — foram atualizados para refletir **agl-hostman** em 2026-03-19.

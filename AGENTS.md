# agl-hostman

> Orquestração multi-agente e gestão de infra AGL (hosts, stacks, gateway LLM)

## Visão do projeto

Repositório **agl-hostman**: automação, documentação operacional e APIs de apoio à infraestrutura AGL (Proxmox, containers, redes, LiteLLM, integrações). Convivem **API Node (Fastify)** e **aplicação Laravel** no ramo `src/`, mais configs e Docker na raiz.

**Stack (resumo)**  
- Node.js 18+ — API em `src/api/` (Fastify, SQLite onde aplicável)  
- PHP / Laravel 12 — app principal em `src/` (Inertia **React**, Pest, Horizon, etc.; convénções em `.cursor/rules/laravel-boost.mdc`)  
- LiteLLM — `config/litellm/config.yaml` (+ `config-remote.yaml`); integração Cursor: `docs/CURSOR-LITELLM-INTEGRATION.md`  
- Docker / Compose — `docker/`, `docker-compose*.yml` na raiz  

**Última revisão deste ficheiro**: 2026-03-19

## Quick start (raiz do repositório)

```bash
npm install          # API Node + tooling da raiz
npm run dev          # API: node --watch src/api/server.js
npm test             # tests/api/*.test.js + tests/unit/*.test.js
```

Laravel (subpasta `src/`): ver `src/README.md`, `composer install`, `php artisan test`.

## Estrutura útil (não esgotativa)

| Caminho | Conteúdo |
|---------|----------|
| `src/api/` | Servidor Fastify (`server.js`, rotas) |
| `src/app`, `src/routes`, `resources/` | Laravel (árvore clássica sob `src/`) |
| `config/litellm/` | Modelos, proxy OpenAI/Anthropic, rota `/cursor` para IDE |
| `docker/` | Stacks (ex.: LiteLLM, monitoring) |
| `docs/` | INFRA, troubleshooting, integrações |
| `scripts/` | Automação (backup, litellm, openclaw, etc.) |
| `tests/api`, `tests/unit`, `tests/integration/` | Testes Node |
| `ai-docs/`, `agent-os/` | Planeamento e specs quando existirem |
| `.cursor/rules/` | Regras Cursor (Laravel Boost, guia primário PT) |
| `/mnt/overpower/apps/dev/agl/agl-hostman` (agldv03) | Clone do mesmo repo via NFS overpower (espelho de `U:\…` na wk45) |

**Nota:** A raiz contém muitos artefactos de projeto (compose, config, Python pontual). **Não** adicionar ficheiros soltos sem propósito; preferir `docs/`, `scripts/`, `config/` ou o módulo `src/` adequado.

## Coordenação de agentes

### Swarm (quando aplicável)

| Definição | Valor |
|-----------|--------|
| Topology | `hierarchical` |
| Max agents | 8 |
| Estratégia | especializada por papel |

**Usar swarm / decomposição:** alterações em 3+ ficheiros, features novas, refactor transversal, APIs com testes, segurança, performance.  
**Evitar:** edição única trivial, typos, só docs de uma linha (avaliar caso a caso).

### Skills (Claude Flow / Cursor)

Referência: `.agents/skills/`, `.claude/skills/`. Exemplos: orquestração de swarm, SPARC, auditoria de segurança, infra AGL (`agl-infra`).

### Papéis típicos

| Tipo | Foco |
|------|------|
| researcher | Âmbito e requisitos |
| architect | Desenho e limites |
| coder | Implementação |
| tester | Testes e regressões |
| reviewer | Qualidade e risco |

## Normas de código

- Ficheiros **&lt; 500 linhas** quando possível; dividir por responsabilidade.
- Sem segredos no Git; usar env / gestão de secrets.
- Validação nas fronteiras (HTTP, forms, paths — anti-traversal).
- **Commits:** `feat|fix|docs|style|refactor|perf|test|chore(scope): mensagem` (ver histórico do repo para estilo da equipa).

## Segurança

- Nunca commitar `.env` com credenciais.
- Queries parametrizadas; saída escapada onde houver HTML.
- Caminhos validados antes de I/O.

## Memória (Claude Flow CLI)

```bash
npx @claude-flow/cli memory store --key "nome" --value "descrição" --namespace patterns
npx @claude-flow/cli memory search --query "termos" --namespace patterns
```

## Infra AGL (operações)

Resumo — detalhe em `docs/INFRA.md`:

| Tema | Nota |
|------|------|
| Restart CT | Preferir **host** ou outra máquina, não de dentro do CT (ex. CT179) |
| CT locked | `pct unlock <vmid>` antes de `pct start` |
| Pi-hole CT102 | `pct unlock 102 && pct start 102` |
| Cloudflared CT117 | `pct exec 117 -- systemctl restart cloudflared` |
| OpenClaw aglwk45 | VM104 — via AGLSRV1 / scripts em `scripts/verify-openclaw-*` |

### OpenClaw (referência rápida)

| Host | Tailscale / verificação |
|------|-------------------------|
| agldv03 | `100.94.221.87` — gateway OpenClaw ativo (fonte) |
| agldv12 | `100.71.217.115` — **OpenClaw desligado** (clone do CT dev; evitar bots duplicados) |
| fgsrv06 | `100.83.51.9` |
| aglwk45 | Via `192.168.0.245` / guest exec |

## LiteLLM + Cursor (Composer)

O modelo **Composer 2** na Cursor é proprietário; no proxy, **`cursor-composer`** / **`cursor-composer-2-fast`** usam **`gpt-5.4-mini`**; aliases **`openai/gpt-5.3-chat-latest`** (e `gpt-5.3-instant`) apontam para o mesmo backend (ver `config/litellm/config.yaml`). Documentação: **`docs/CURSOR-LITELLM-INTEGRATION.md`**.

## Ligações

- Claude Flow: https://github.com/ruvnet/claude-flow  
- LiteLLM Cursor: https://docs.litellm.ai/docs/tutorials/cursor_integration  

<!-- BEGIN BEADS INTEGRATION v:1 profile:full hash:d4f96305 -->
## Issue tracking (bd / beads)

**IMPORTANTE:** Usar **bd** para acompanhamento de trabalho orientado a issues. Evitar TODOs em markdown como sistema único de tracking.

### Comandos úteis

```bash
bd ready --json
bd create "Título" --description="..." -t bug|feature|task -p 0-4 --json
bd update <id> --claim --json
bd close <id> --reason "..." --json
```

**Tipos:** `bug`, `feature`, `task`, `epic`, `chore`  
**Prioridade:** `0` crítico … `4` backlog  
**Dependências:** `--deps discovered-from:bd-XXX`

### Landing the plane (fim de sessão)

Trabalho considerado fechado apenas com **push** bem-sucedido quando há remoto Git:

1. Registar follow-up em bd se necessário  
2. Testes / lint após mudanças de código (`npm test`, `php artisan test` no Laravel afetado)  
3. `git pull --rebase` → `bd dolt push` (quando usas Dolt remoto) → `git push`  
4. `git status`: **up to date** com `origin`  
5. Não deixar alterações críticas só locais sem issue associada  

<!-- END BEADS INTEGRATION -->

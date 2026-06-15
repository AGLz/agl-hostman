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
| `scripts/` | Automação (backup, litellm, agency, etc.) |
| `tests/api`, `tests/unit`, `tests/integration/` | Testes Node |
| `ai-docs/`, `agent-os/` | Planeamento e specs quando existirem |
| `.cursor/rules/` | Regras Cursor (Laravel Boost, guia primário PT) |
| `/mnt/overpower/apps/dev/agl/agl-hostman` (agldv03) | Clone do mesmo repo via NFS overpower (espelho de `U:\…` na wk45) |

## Six Repos (skills multi-harness)

Plano e scripts: [`ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md`](ai-docs/planning/SIX-REPOS-MULTI-AGENT-PLAN.md) · integração llm-wiki: [`docs/LLM-WIKI-AGENCY-INTEGRATION.md`](docs/LLM-WIKI-AGENCY-INTEGRATION.md).

**Dotfiles + live sync (Cursor/Claude/Codex):** configs em `config/dotfiles/`; chats/history em `/mnt/overpower/apps/dev/agl/agl-home-sync/` (NFS overpower). Scripts: `scripts/dotfiles/install-agl-home-sync.sh`, `verify-agl-home-sync.sh`, `propagate-dotfiles.sh`.

```bash
bash scripts/skills/sync-six-repos.sh --repo all
bash scripts/skills/verify-six-repos.sh
bash scripts/skills/propagate-six-repos.sh --host all   # agldv03, ct188, aglwk45
```

**Obsidian CLI:** activar no Obsidian Desktop 1.12+; sem CLI no PATH, `verify-six-repos.sh` reporta WARN (skills já instaladas).

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

Referência: `.agents/skills/`, `.claude/skills/`. Exemplos: orquestração de swarm, SPARC, auditoria de segurança, infra AGL (`agl-infra`), AGLz Agency em contexto AGL (`aglz-agency` — ver `CLAUDE.md`, `docs/AGLZ-AGENCY-HERMES-2026-05.md`).

### Papéis típicos

| Tipo | Foco |
|------|------|
| researcher | Âmbito e requisitos |
| architect | Desenho e limites |
| coder | Implementação |
| tester | Testes e regressões |
| reviewer | Qualidade e risco |

## Normas de código

- Comportamento de implementação para agentes: secção **Karpathy Skills** em `CLAUDE.md` e regra Cursor `.cursor/rules/karpathy-skills.mdc` (Think Before Coding, Simplicity First, Surgical Changes, Goal-Driven Execution); em conflito com convenções do projeto, prevalecem as regras da stack (ex. Laravel Boost, `primary-guide.mdc`).
- Ficheiros **&lt; 500 linhas** quando possível; dividir por responsabilidade.
- Sem segredos no Git; usar env / gestão de secrets.
- Validação nas fronteiras (HTTP, forms, paths — anti-traversal).
- **Commits:** `feat|fix|docs|style|refactor|perf|test|chore(scope): mensagem` (ver histórico do repo para estilo da equipa).

## Segurança

- Nunca commitar `.env` com credenciais.
- Queries parametrizadas; saída escapada onde houver HTML.
- Caminhos validados antes de I/O.

## Orquestração Ruflo / compat Claude Flow

O produto evoluiu para **Ruflo** (CLI `ruflo`); o binário `claude-flow` passa a vir do pacote **`@claude-flow/cli`** (mesmo motor que `ruflo`). **Não** uses o pacote npm antigo só `claude-flow` (versão desalinhada).

**Instalação global (recomendado no host dev, ex. agldv03):**

```bash
npm i -g ruflo@latest @claude-flow/cli@latest
```

**Casos de uso típicos (no diretório do projeto):**

```bash
ruflo doctor                    # diagnóstico (Node, Git, daemon, memória)
ruflo init --minimal            # .claude-flow + integração Claude Code
ruflo status                    # swarm / agentes / tarefas
ruflo memory store --key "nome" --value "descrição" --namespace patterns
ruflo memory search --query "termos" --namespace patterns
# Equivalente (MCP / docs antigos): npx @claude-flow/cli memory …
```

**Referências:** [ruvnet/ruflo](https://github.com/ruvnet/ruflo) · [ruvnet/claude-flow](https://github.com/ruvnet/claude-flow) (repo legado/nome histórico)

**ruv-swarm MCP (`mcp__ruv-swarm__swarm_status`) — erro `getGlobalMetrics` de `null`:** bug conhecido em `ruv-swarm` ≤1.0.20: o servidor MCP despachava ferramentas no singleton sem `RuvSwarm` inicializado. Correr após cada `npm i -g ruv-swarm`:

`python3 scripts/ruflo/apply-ruv-swarm-mcp-fix.py`

**Workers headless (root / ruflo):** o `@claude-flow/cli` invocava `claude --print` sem `--dangerously-skip-permissions`, e o processo MCP muitas vezes **não herda** `IS_SANDBOX` do `~/.zshrc` (Cursor/systemd). Em versões recentes pode aparecer `[INFO] Skipping --dangerously-skip-permissions (not allowed with root/sudo)` porque o **check corre no processo Node** antes do `spawn`, não só no `claude`. Sem `IS_SANDBOX=1` no pai, a flag nem é passada. Workaround documentado na comunidade Anthropic: [claude-code#3490](https://github.com/anthropics/claude-code/issues/3490), [claude-code#927](https://github.com/anthropics/claude-code/issues/927). O script abaixo: DSP no headless, `IS_SANDBOX` no `env` do filho, **default de `IS_SANDBOX` no início de `spawnClaudeCodeInstance`**, e remove a linha `printInfo('Skipping…')` se existir. Correr após cada `npm i -g @claude-flow/cli` (ou `ruflo`):

`python3 scripts/ruflo/apply-claude-flow-headless-dsp.py`

**429 / código 1302 “Rate limit”** ao usar hive-mind: limite do fornecedor do modelo (ex. Z.AI); aguardar, reduzir pedidos paralelos ou usar outro alias no LiteLLM.

## Infra AGL (operações)

Resumo — detalhe em `docs/INFRA.md`:

| Tema | Nota |
|------|------|
| Restart CT | Preferir **host** ou outra máquina, não de dentro do CT (ex. CT179) |
| CT locked | `pct unlock <vmid>` antes de `pct start` |
| Pi-hole CT102 | `pct unlock 102 && pct start 102` |
| Cloudflared CT117 | `pct exec 117 -- systemctl restart cloudflared` |
| AGLz Agency CT188 | Hermes quarteto — via AGLSRV1 `pct exec 188` |

### AGLz Agency — Hermes Quarteto (Maio 2026)

4 agentes Hermes em Docker no CT188 (agl-hermes), imagem custom `Dockerfile.aglz-agency`:

| Agente | Papel | Bot Telegram | Profile |
|--------|-------|-------------|---------|
| Jarvis | CEO | @hermes_jarvis_h_bot | /opt/agl-hermes/profiles/jarvis/ |
| Elon | CPO/CRO | @hermes_jarvis_h_elon_bot | /opt/agl-hermes/profiles/elon/ |
| Satya | COO | @hermes_jarvis_h_satya_bot | /opt/agl-hermes/profiles/satya/ |
| Werner | VP Infra | @hermes_jarvis_h_werner_bot | /opt/agl-hermes/profiles/werner/ |

**Stack**: LiteLLM CT186 (`100.125.249.8`, gpt-5.5) · Honcho CT192 (workspace `aglz-agency`, memória durável) · Linear (teams AGLDV/CBDEV/AGLZ, backlog) · llm-wiki (KB curado, montado ro nos containers)

**Rede**: Tailscale (inter-hosts) + Docker bridge (inter-containers)

**Cron jobs**: Werner health check 9h · Satya work 11h · Elon work 10h · repo scan semanal

**Acesso host CT188**: `ssh root@100.107.113.33 'pct exec 188 -- <cmd>'`

**Deploy**: `docker/hermes/docker-compose.aglz-quartet.ct188.yml`

### AGLSRV1 Troubleshooting (2026-04-06)

**Problema mais frequente**: aglwk45 (VM104) inacessível via RDP.

**Causa raiz recorrente**: meshagent memory leak no host AGLSRV1 (30+ instâncias, 3 podem vazar para 10-22GB cada).

**Diagnóstico rápido** (SSH via Tailscale `100.107.113.33`):
```bash
# 1. Verificar VM
qm status 104 && qm agent 104 ping

# 2. Verificar meshagents com leak (>1GB RSS)
ps aux | grep meshagent | grep -v grep | awk '{if ($6 > 1000000) print "LEAK: PID "$2" RSS "int($6/1024)"MB"}'

# 3. Se leak confirmado → matar + reboot VM
ps aux | grep meshagent | grep -v grep | awk '{if ($6 > 1000000) print $2}' | xargs -r kill -9
qm stop 104 && sleep 3 && qm start 104
```

**Detalhe completo**: `docs/AGLWK45-SETUP.md`, `docs/aglsrv1-key-findings.md`

**NUMA / QPI / NVMe VM104 (2026-06-06)**: erros QPI ~1/s (`rasdaemon`); VM104 `numa: 1` + NVMe passthrough no socket 1 — [`docs/AGLSRV1-NUMA-QPI-OPTIMIZATION.md`](docs/AGLSRV1-NUMA-QPI-OPTIMIZATION.md)

## LiteLLM + Cursor (Composer)

O modelo **Composer 2** na Cursor é proprietário; no proxy, **`cursor-composer`** / **`cursor-composer-2-fast`** usam **`gpt-5.4-mini`**; aliases **`openai/gpt-5.3-chat-latest`** (e `gpt-5.3-instant`) apontam para o mesmo backend (ver `config/litellm/config.yaml`). Documentação: **`docs/CURSOR-LITELLM-INTEGRATION.md`**.

## Ligações

- Ruflo (orquestração): https://github.com/ruvnet/ruflo  
- Claude Flow (histórico / MCP): https://github.com/ruvnet/claude-flow  
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

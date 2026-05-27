# agl-hostman

Repositório de **orquestração multi-agente**, **automação** e **documentação operacional** para a infraestrutura **AGL** (hosts, stacks, redes, gateway LLM e integrações).

Na mesma árvore coexistem uma **API Node (Fastify)** e uma **aplicação Laravel 12** sob `src/`, além de configs Docker, LiteLLM e scripts de operações.

## Requisitos

| Componente | Versão / notas |
|------------|----------------|
| Node.js | 18+ |
| PHP / Composer | Para a app Laravel em `src/` |
| Docker / Compose | Opcional — stacks em `docker/` e ficheiros `docker-compose*.yml` na raiz |

Variáveis de ambiente: ver `.env.example` na raiz e nos diretórios relevantes (ex. serviços Laravel / LiteLLM). **Não** commitar credenciais.

## Início rápido (API Node na raiz)

```bash
npm install
npm run dev      # inicia src/api/server.js com --watch
npm test         # tests/api/*.test.js + tests/unit/*.test.js
```

Outros scripts úteis (ver `package.json`):

- `npm run start` — API sem watch  
- `npm run test:integration:litellm` — teste de integração LiteLLM  
- `npm run lint` / `npm run lint:fix` — ESLint (`src/api/`, `src/services/`, `tests/api/`)  

## Aplicação Laravel (`src/`)

A app PHP vive em **`src/`** (artisan, `composer.json`, `app/`, `resources/`, etc.).

```bash
cd src
composer install
cp .env.example .env   # se ainda não existir
php artisan key:generate
php artisan test       # Pest
```

Mais detalhes: **`src/README.md`** (se existir) e regras do projeto em **`.cursor/rules/laravel-boost.mdc`**.

## Documentação

| Documento | Conteúdo |
|-----------|----------|
| [**docs/README.md**](docs/README.md) | Índice da documentação AGL |
| [**docs/INFRA.md**](docs/INFRA.md) | Mapa de infra, operações recorrentes |
| [**docs/CURSOR-LITELLM-INTEGRATION.md**](docs/CURSOR-LITELLM-INTEGRATION.md) | Cursor IDE + LiteLLM (modelos `cursor-*`, proxy Composer) |
| [**AGENTS.md**](AGENTS.md) | Normas para agentes, bd/beads, OpenClaw, LiteLLM |
| [**CLAUDE.md**](CLAUDE.md) | Contexto do workspace e caminhos-chave |

## Estrutura (resumo)

```
agl-hostman/
├── src/
│   ├── api/                 # API Fastify (entrada npm run dev na raiz)
│   ├── app/                 # Laravel: aplicação PHP
│   ├── routes/, resources/  # Laravel
│   └── ...
├── config/litellm/          # Gateway LLM (config.yaml, integração Cursor)
├── docker/                  # Stacks (ex. LiteLLM, monitoring)
├── docs/                    # Infra, troubleshooting, guias
├── scripts/                 # Automação (backup, litellm, verify-openclaw, …)
├── tests/                   # Testes Node: api/, unit/, integration/
├── infrastructure/          # Terraform / docs de plataforma
├── ops/                     # Runbooks / operações
├── AGENTS.md, CLAUDE.md     # Contexto para humanos e agentes
└── package.json             # Tooling Node da raiz
```

A raiz reúne também compose, configs e ferramentas auxiliares; **novos ficheiros** devem ir para `docs/`, `scripts/`, `config/` ou para o módulo adequado em `src/`, não como ficheiros soltos sem propósito.


## AGLz Agency (Hermes Quarteto)

4 agentes Hermes em Docker no CT188:
- Jarvis (CEO) @hermes_jarvis_h_bot
- Elon (CPO/CRO) @hermes_jarvis_h_elon_bot  
- Satya (COO) @hermes_jarvis_h_satya_bot
- Werner (VP Infra) @hermes_jarvis_h_werner_bot

Stack: LiteLLM CT186 (gpt-5.5), Honcho CT192 (memória), Linear (backlog), llm-wiki (KB)
Deploy: docker/hermes/docker-compose.aglz-quartet.ct188.yml
Profiles: /opt/agl-hermes/profiles/{name}/ → /opt/data

## AGLz Agency (Hermes Quarteto)

A AGLz Agency opera com **4 agentes Hermes** em containers Docker no CT188 (agl-hermes):

- **Jarvis** (CEO) — visão, prioridades, delegação — @hermes_jarvis_h_bot
- **Elon** (CPO/CRO) — produto, pesquisa, specs — @hermes_jarvis_h_elon_bot
- **Satya** (COO) — execução, código, deployment — @hermes_jarvis_h_satya_bot
- **Werner** (VP Infra) — Proxmox, rede, LiteLLM — @hermes_jarvis_h_werner_bot

**Stack**: Hermes Agent via LiteLLM CT186 (gpt-5.5), Honcho CT192 (memória durável), Linear (backlog), llm-wiki (KB curado).
**Deploy**: `docker/hermes/docker-compose.aglz-quartet.ct188.yml`
**Profiles**: `/opt/agl-hermes/profiles/{jarvis,elon,satya,werner}/` montado como `/opt/data`


## LiteLLM e Cursor

Configuração principal: **`config/litellm/config.yaml`** (e **`config-remote.yaml`** onde aplicável).  
Os nomes **`cursor-composer`** / **`cursor-composer-2-fast`** usam **`gpt-5.4-mini`** na OpenAI; no gateway LiteLLM mantêm-se aliases **`openai/gpt-5.3-chat-latest`** / **`gpt-5.3-instant`** com o mesmo backend (Composer 2 da Cursor é proprietário). Setup: **`docs/CURSOR-LITELLM-INTEGRATION.md`**.

## Contribuição e rastreio

- Estilo de commits: `feat|fix|docs|style|refactor|perf|test|chore(scope): descrição` (alinhar com o histórico da equipa).  
- Issues / bd: ver secção **beads** em **`AGENTS.md`**.

---

*Última atualização do README: 2026-05-27.*

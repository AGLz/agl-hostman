---
name: OpenClaw AGL Expert
description: |
  Especialista OpenClaw na infraestrutura AGL (self-hosted agent gateway). Usar em instalação e atualização (Docker em agldv03, Windows clone+pnpm, npm global), gateway e Control UI, configuração de modelos/providers e LiteLLM, canais Telegram (pairing, grupos, streaming), otimização de custo, fallbacks, cron, contentores e redes Docker, propagação agldv03↔aglwk45/VM104, padrões multi-host/HA, integração Cursor/Codex/Codex (ANTHROPIC_BASE_URL, litellm-gateway), troubleshooting (health 503, 401, 429, "All models failed", systemd vs Docker, DashScope intl, SMB/pnpm). Consultar para deploy de config, diagnóstico, validação com scripts e alinhamento com docs/OPENCLAW.md.
---

# OpenClaw AGL — Especialista

## Quando usar

- Instalar, atualizar ou migrar OpenClaw (host, Docker, Windows).
- Configurar LiteLLM como provider `openai`, chaves, aliases e `config/litellm/`.
- Telegram: políticas, pairing, grupos, routings, agentes, streaming.
- Otimizar custo (tiering, fallbacks, modelos primários), cron, skills.
- Contentores, redes (`litellm_litellm-net`, `openclaw-repo_default`), health checks.
- Sincronizar config entre **agldv03**, **aglwk45 (VM104)**, AGLSRV1 (guest agent), sem duplicar monitorização.
- Problemas: gateway parado, modelos a falhar, 401/429, UI 503, env systemd vs container.

**Fonte de verdade no repo:** `docs/OPENCLAW.md` (tabelas de versões, Docker, direct vs LiteLLM), `config/openclaw/`, `scripts/openclaw/`.

**Infra AGL (resumo):**

| Sítio | Papel | Nota |
|------|--------|------|
| **agldv03** (CT179) | OpenClaw **canónico** (Docker), monitorização, cron | `100.94.221.87`; repo em `/mnt/overpower/apps/dev/agl/agl-hostman` |
| **openclaw-repo** (paralelo) | Compose, imagem gateway | Container ex.: `openclaw-repo-openclaw-gateway-1`, portas **28789/28790** |
| **LiteLLM** | Proxy `:4000`, rede `192.168.32.x` / `litellm_litellm-net` | `config/litellm/config.yaml` no agl-hostman |
| **aglwk45** (VM104) | Windows, clone `openclaw` em disco local | Não clonar em SMB (`U:\`); `pnpm link --global` |
| **AGLSRV1** | Proxmox, `qm guest exec 104` para Windows | Propagação via scripts em `scripts/openclaw/` |

## Instalação e modos

### Docker (primário agldv03, 2026+)

- Serviço systemd no host: **desativado**; operar via `docker compose` no checkout `openclaw-repo`.
- Health: `curl -s http://127.0.0.1:28789/healthz`
- Validação: `bash /mnt/overpower/apps/dev/agl/agl-hostman/scripts/openclaw/validate-openclaw-docker.sh`
- Config montada: ex. `/mnt/overpower/apps/dev/agl/openclaw-repo/config/openclaw.json` → `~/.openclaw` no container (confirmar `docker-compose` do repo local).

### Windows (wk45 / dev)

- Clone em **disco local NTFS** (ex. `C:\Users\Administrator\src\openclaw`), nunca em share SMB (falha de symlinks do pnpm).
- Fluxo: `pnpm install` → `pnpm ui:build` → `pnpm build` → `pnpm link --global`
- Se Control UI 503: garantir `dist/control-ui` (`pnpm ui:build`); `openclaw gateway install --force` se `gateway.cmd` apontar para path antigo.

### Modos de providers (AGL)

- **Via LiteLLM** no container: `models.providers.openai.baseUrl` → `http://<IP-LITELLM>:4000`, `apiKey` alinhada ao proxy; `agents.defaults.model.primary` tipo `openai/qwen3.5-flash` (ver `docs/OPENCLAW.md` § Docker).
- **Direct** (sem LiteLLM no path Anthropic): `config/openclaw/zshrc-openclaw-direct.env`, `apply-openclaw-direct-providers.py`, `merge-openclaw-json-patch.py`. Cuidado: `ANTHROPIC_BASE_URL` no systemd **não** deve apontar para LiteLLM em modo direct se o manager misturar chaves.
- **Codex → LiteLLM local:** `scripts/deploy-openclaw-config.sh` e `~/.openclaw/litellm-gateway.env`; `AGENTS.md` do agl-hostman descreve `http://localhost:4000`.

## LiteLLM

- Ficheiros: `config/litellm/config.yaml`, `config/litellm/config-remote.yaml`
- Integração IDE: `docs/CURSOR-LITELLM-INTEGRATION.md` (aliases `cursor-composer*`, `gpt-5.3-chat-latest` → backend comum)
- Teste a partir do contentor OpenClaw: ver exemplo `fetch` em `docs/OPENCLAW.md` (ajustar IP da rede bridge e bearer)

## Telegram

- Canais: `channels.telegram` em `openclaw.json` — `dmPolicy: pairing`, `groupPolicy: allowlist`, `streaming`
- **"All models failed"**: (1) env do gateway sem misturar direct com proxy Anthropic; (2) validar chaves reais (DashScope **internacional** `dashscope-intl` / URL correta); (3) OpenRouter/DeepSeek conforme catálogos do patch AGL; ver secção de troubleshooting em `docs/OPENCLAW.md`
- Multi-agente + bindings: `config/openclaw/openclaw-agents-list.fragment.json` + `scripts/openclaw/merge-openclaw-agents.mjs`

## Otimizações

- Cadeia de **fallbacks** e aliases (`/model …`) — tabela em `docs/OPENCLAW.md`
- **Tiering de custo**: glm-flash / gemini-lite → modelos padrão → premium (mesmo doc)
- **Cron** no contentor: `openclaw cron list` (não depender de `~/.openclaw/cron/` fora do sítio canónico se a equipa definiu agldv03 como única fonte de schedulers de monitorização)
- **Skills**: `skills.allowBundled` em `openclaw.json`; workspace skills em `~/.openclaw/workspace/skills` (docs oficiais tools/skills)

## Docker e redes

- OpenClaw e LiteLLM em redes que se alcancem mutuamente (ex. attach à `litellm_litellm-net`); IPs internos 172.x / 192.168.32.x conforme desenho em `docs/OPENCLAW.md`
- Logs: `docker logs <container> --tail=30`
- Restart: `docker compose restart` no diretório do compose

## HA / multi-host (sem “dois cérebros”)

- **Propagação JSON** agldv03 → wk45: `propagate-openclaw-to-aglwk45-qemu.sh`, `vm104_guest_*.py`, SSH AGLSRV1 + guest agent
- **Monitorização** canónica no agldv03: `config/monitoring/jarvis-openclaw-http-endpoints.example.json`, `ops/runbooks/jarvis-operations.md` — evitar schedulers duplicados no wk45 para os mesmos checks

## Integração: Cursor, Codex, Codex, outros IDEs

| Ferramenta | O que alinhar |
|------------|----------------|
| **Cursor** | `ANTHROPIC_BASE_URL` / variáveis apontando para o gateway ou LiteLLM conforme política; ver `.cursor` e `docs/CURSOR-LITELLM-INTEGRATION.md` |
| **Codex** | `~/.Codex/settings.json` + `litellm-gateway.env` via `deploy-openclaw-config.sh` (root do agl-hostman) |
| **Codex CLI** | Mesmo host/gateway: garantir `OPENAI_BASE_URL` / fornecedor coerente com o que o OpenClaw expõe, sem misturar keys de teste em produção |

Para clientes com **skills** (p.ex. outro IDE com pasta de skills): instalar esta skill **globalmente** (secção abaixo).

## Troubleshooting (atalhos)

| Sintoma | Onde olhar |
|---------|------------|
| `healthz` falha / contentor restarting | `docker ps`, `docker logs`, `validate-openclaw-docker.sh` |
| 401 no provider | API key, token LiteLLM, Z.AI 401 (AI Gateway) |
| 402/429 / quota | `OPENCLAW_SMOKE_TREAT_RATE_LIMIT=1` em smokes; reduzir paralelismo |
| Telegram sem resposta | Modelos, env do processo, streaming, `fix-openclaw-telegram-streaming.sh` se aplicável |
| Systemd vs Docker | Confirmar se o host ainda tem `openclaw-gateway` ativo; doc diz systemd **disabled** no primary |

Scripts úteis (raiz lógica `agl-hostman/scripts/openclaw/`): `diag-agldv03-openclaw.sh`, `sync-systemd-openclaw-env.sh` (legado/hosts mistos), `test-openclaw-direct-providers.sh`, `merge-openclaw-json-patch.py`, `apply-openclaw-direct-bundle.sh`.

## Ficheiros-chave no repositório

- `docs/OPENCLAW.md` — guia longo, Docker, Windows, modelos, env
- `docs/OPENCLAW-*.md` — migrações, fixes, monitoring
- `config/openclaw/*.json`, `zshrc-openclaw-*.env`, `openclaw-models-direct.providers.json`
- `scripts/openclaw/*` — deploy, merge, validação, sync remotos
- `AGENTS.md` (raiz agl-hostman) — atalhos OpenClaw + LiteLLM

## Instalação global desta skill (Codex, Cursor, Codex, outros)

1. **Cópia ou symlink** (Linux/macOS), a partir de uma máquina com o clone do agl-hostman:

```bash
ln -sfn /mnt/overpower/apps/dev/agl/agl-hostman/.Codex/skills/openclaw-agl \
  "$HOME/.Codex/skills/openclaw-agl"
```

2. **Ajustar o primeiro path** se o repositório estiveroutro sítio (ex. `U:\` mapeado — o skill em si é só Markdown; o symlink pode apontar para cópia local em disco local).

3. **Cursor / IDEs** que lêem skills do projeto: a pasta `.Codex/skills/openclaw-agl/` no **agl-hostman** já basta em workspaces deste repo.

4. **Codex / CLI** sem pasta de skills: referenciar `docs/OPENCLAW.md` ou colar o resumo deste `SKILL.md` no `AGENTS.md` local do projeto (opcional).

5. **Atualizar** quando `git pull` alterar a skill: quem usa symlink vê a versão nova automaticamente.

## Relação com outras skills

- **`agl-infra`**: Proxmox, CT179, AGLSRV1, Tailscale, LiteLLM em contexto geral
- **Esta skill**: aprofundamento **OpenClaw** (gateway, canais, configs versionadas, propagação wk45, troubleshooting específico)

---

*Mantida pela equipa AGL; alinhar alterações de infra com `docs/OPENCLAW.md` e review antes de produção.*

# LiteLLM (CT186) + OpenClaw (CT187) em LXC dedicados — AGLSRV1

Objetivo: **CT186** só com LiteLLM (Docker + Postgres) e **CT187** só com OpenClaw (Docker), com o `openclaw.json` a apontar o provider `openai` para `http://<IP_CT186>:4000`.

## Pré-requisitos

- Acesso **root** ao nó **AGLSRV1** (Proxmox; SSH típico via Tailscale).
- VMIDs **186** e **187** livres (`pct list`). **Nota:** em AGLSRV1 os IDs **150** e **151** costumam estar ocupados por **VMs QEMU**, não por LXC — por isso o runbook usa **186/187**.
- Template Debian 12 no storage `local` (ajustar `PROXMOX_TEMPLATE` se o nome do `.tar.zst` for outro).
- Ficheiro `config/litellm/.env` no agl-hostman (ou cópia segura) com chaves reais — **não** commitar.

## GPU + Docker (espelho CT185)

Para GPU NVIDIA dentro de contentores Docker num LXC **não privilegiado**, alinhar o `pct` config ao **CT185** (ou CT179 com o mesmo padrão):

- Entradas **cgroup2** para dispositivos NVIDIA e `nvidia-caps`, mounts de bibliotecas/driver, `dri`, `tun`, e `ip_unprivileged_port_start` conforme o host.
- Se `docker run` / `docker compose` falhar com `permission denied` em sysctl montado ou portas não privilegiadas, no ficheiro do CT (`/etc/pve/lxc/<vmid>.conf` no nó):

  ```text
  lxc.apparmor.profile: unconfined
  ```

  (O Proxmox pode avisar da interacção com `fuse`/`nesting` ao nível AppArmor; é o tradeoff habitual para Docker-in-LXC neste cluster.)

Reiniciar o CT após alterar `*.conf`.

## Tailscale nos CT186 / CT187

Pacote **Tailscale 1.96.x** + serviço **`tailscaled`** já podem estar instalados no CT (repo oficial Debian bookworm). Estado inicial: `tailscale status` → *Logged out.*

**Junção à tailnet (recomendado: chave reutilizável)** — no **AGLSRV1**, com chave criada em [Keys](https://login.tailscale.com/admin/settings/keys) (não commitar a chave):

```bash
cd /caminho/agl-hostman
export TAILSCALE_AUTHKEY='tskey-auth-…'
bash scripts/proxmox/pct-tailscale-up-litellm-openclaw.sh
```

Alternativa interactiva (URL no browser), alinhada a **CT185 / PEGAPROX** (`--accept-dns=false` evita MagicDNS no `resolv.conf`; `--ssh` activa Tailscale SSH; se o SSH ao Proxmox for **via Tailscale**, é obrigatório `--accept-risk=lose-ssh`):

```bash
# CT186 — abrir a URL no browser e concluir login; deixar o comando a correr até terminar (não matar ao cedo)
pct exec 186 -- tailscale up --accept-dns=false --hostname=agl-litellm-ct186 --ssh --accept-routes --accept-risk=lose-ssh

# CT187
pct exec 187 -- tailscale up --accept-dns=false --hostname=agl-openclaw-ct187 --ssh --accept-routes --accept-risk=lose-ssh
```

Se `tailscale status` mostrar *Logged out* com `Log in at: https://login.tailscale.com/a/...`, essa URL continua válida até completares o fluxo no browser (ou até expirar — nesse caso volta a correr `tailscale up` com os mesmos flags).

Após login: `pct exec 186 -- tailscale ip -4` — usar esse IP em clientes (ex. agldv03) quando a LAN entre CTs estiver filtrada.

## 1. Criar os LXC (no Proxmox)

```bash
cd /caminho/agl-hostman
cp scripts/proxmox/agl-litellm-openclaw-lxc.env.example scripts/proxmox/agl-litellm-openclaw-lxc.env
# editar agl-litellm-openclaw-lxc.env (storage, bridge, RAM, template, VMIDs se necessário)

set -a && source scripts/proxmox/agl-litellm-openclaw-lxc.env && set +a
bash scripts/proxmox/pct-create-agl-litellm-openclaw.sh
```

O script `pct-create` usa `nesting=1,keyctl=1,fuse=1,mknod=1` (alinhado a workloads Docker).

Definir password do utilizador root em cada CT (exemplo):

```bash
pct passwd 186
pct passwd 187
```

Ou configurar **SSH por chave** com `pct set` / cloud-init conforme política AGL.

## 2. Obter IPs

```bash
pct exec 186 -- ip -4 addr show eth0
pct exec 187 -- ip -4 addr show eth0
```

Anote o IP do **186** (LiteLLM), ex. `192.168.0.186`.

## 3. Bootstrap CT186 — LiteLLM

Copiar o repositório **agl-hostman** para dentro do CT (git clone, NFS ou `scp -r`), e o `.env` do LiteLLM:

```bash
# No CT186 (pct enter 186 ou SSH)
mkdir -p /opt/agl-litellm
# copiar config/litellm/.env do ambiente actual para /opt/agl-litellm/.env

bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct186-litellm.sh /caminho/agl-hostman
```

Validação:

```bash
curl -sS http://127.0.0.1:4000/health/readiness
```

Firewall: permitir **TCP 4000** do CT187 (e redes que usem Cursor/agents) para o CT186.

## 4. Bootstrap CT187 — OpenClaw

Preparar `config/openclaw.json` (cópia do **openclaw-repo** ou do agldv03) e `.env` a partir de `docker/openclaw/.env.ct187.example`.

```bash
# No CT187
cp docker/openclaw/.env.ct187.example /opt/agl-openclaw/.env
# editar segredos e OPENCLAW_GATEWAY_TOKEN

bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct187-openclaw.sh /caminho/agl-hostman http://IP_DO_CT186:4000
```

O script aplica `chown -R 1000:1000` em `config/` e `workspace/` (utilizador `node` no contentor).

O segundo argumento grava `models.providers.openai.baseUrl` no `openclaw.json`. Para também definir `apiKey` (virtual key LiteLLM):

```bash
python3 scripts/proxmox/patch-openclaw-litellm-baseurl.py /opt/agl-openclaw/config/openclaw.json http://IP_CT186:4000 sk-litellm-...
```

Validação do gateway (porta publicada no host do CT, por omissão **28789**):

```bash
curl -sS http://127.0.0.1:28789/healthz
```

**Troubleshooting:** `curl` a `127.0.0.1:28789` *dentro* do CT (`pct exec 187 -- curl …`) pode dar timeout (proxy Docker / timing) sem o serviço estar caído. Preferir: (1) a partir de outra máquina na LAN, `http://<IP_CT187>:28789/healthz`; ou (2) dentro do contentor, porta **18789** — `docker exec <gateway> node -e "fetch('http://127.0.0.1:18789/healthz').then(r=>r.text()).then(console.log)"`.

Se a imagem for local (ex. `openclaw:infra`), fazer `docker save` no host de build e `docker load` no CT187 antes do `compose pull`.

### Telegram 409 (`getUpdates` conflict)

Só pode haver **um** long-poll `getUpdates` por **token** de bot.

**Compose CT187:** existe **um** serviço `openclaw-gateway` (réplica única). O serviço `openclaw-cli` está sob `profiles: [cli]` e **não** sobe com `up -d` por omissão — não é um segundo gateway.

**409 sem “outro servidor”?** O upstream OpenClaw reportou **dois loops `getUpdates` no mesmo processo** (ex.: health-check a reiniciar o canal antes do poller anterior fechar, ou hot-reload). Referências úteis:

- [openclaw#56566](https://github.com/openclaw/openclaw/issues/56566) — duplicado de long-poll dentro do mesmo gateway.
- [openclaw#43569](https://github.com/openclaw/openclaw/issues/43569) — 409 com várias contas / reinícios do health monitor.
- [openclaw#18671](https://github.com/openclaw/openclaw/issues/18671) — 409 persistente; discussão de *teardown* antes de novo poll (correcções em `main`).
- Checklist geral: [OpenClaw Telegram 409 — kuoo.uk](https://kuoo.uk/en/blog/openclaw-telegram-409-conflict-getupdates-fix-2026/).

**Mitigações (experimentar no CT187):**

1. **Imagem recente:** `OPENCLAW_IMAGE=ghcr.io/openclaw/openclaw:latest` + `docker compose pull` + restart (incluir correccões de Telegram em `main`).
2. Em `openclaw.json`, se existir **`channelHealthCheckMinutes`**, testar **`0`** para reduzir reinícios que competem com o poller (ver issues acima).
3. **`getWebhookInfo`**: se `url` não estiver vazio, `deleteWebhook` e reiniciar (webhook + polling misturam estado).
4. **Offset local:** com o gateway **parado**, no volume montado em `config/` (no host: `/opt/agl-openclaw/config`), remover ficheiros tipo `telegram/update-offset-*.json` se a documentação da tua versão os usar e o polling ficar “preso” após 409.
5. **Não** correr `curl …/getUpdates` ou scripts de diagnóstico em long-poll **enquanto** o gateway está a correr — isso também gera 409 pelo token.

#### Restaurar o token **anterior** no `.env` (CT187)

Cada corrida de `pct187-rotate-telegram-bot-token.sh` grava um backup completo do `.env` em `/opt/agl-openclaw/.env.bak.telegram.<timestamp>` **antes** de aplicar o token novo. O **mais recente** desses ficheiros contém o token **dantes** da última rotação.

No **AGLSRV1**:

```bash
bash /caminho/agl-hostman/scripts/proxmox/pct187-restore-telegram-env-from-backup.sh
# ou, para o segundo backup mais recente:  bash .../pct187-restore-telegram-env-from-backup.sh 1
```

Isto repõe o `.env` a partir do backup escolhido, cria `.env.bak.before-restore.*`, e faz `docker compose restart`.

#### Novo bot (@BotFather) — rotação de token

1. Criar bot: no Telegram, falar com **@BotFather** → `/newbot` → copiar o **token**.
2. No **AGLSRV1**, guardar o token num ficheiro (uma linha, sem espaços) e correr o script (não colocar o token na linha de comandos):

```bash
printf '%s' 'COLAR_TOKEN_AQUI' > /root/ct187-telegram.token.new
chmod 600 /root/ct187-telegram.token.new
bash /caminho/agl-hostman/scripts/proxmox/pct187-rotate-telegram-bot-token.sh /root/ct187-telegram.token.new
rm -f /root/ct187-telegram.token.new
```

O script faz `pct push` para o CT, actualiza `TELEGRAM_BOT_TOKEN` em `/opt/agl-openclaw/.env`, backup do `.env`, e `docker compose restart`. O `openclaw.json` neste stack **não** usa `botToken` no JSON — só o `.env`.

Parar **outros** gateways/scripts que ainda usem o **mesmo** token, senão mantém-se conflito à escala do Telegram (dois consumidores por token).

CLI OpenClaw (opcional, perfil `cli`):

```bash
cd /opt/agl-openclaw
docker compose --profile cli run --rm openclaw-cli cron list
```

## 5. Cutover a partir do agldv03

1. Validar Telegram / cron no CT187.
2. Atualizar monitorização (endpoints Jarvis) para os novos IPs/hostnames — ver `cutoverDedicatedLxc` em `config/monitoring/jarvis-openclaw-http-endpoints.example.json`.
3. Parar LiteLLM + OpenClaw no **agldv03** quando o tráfego estiver estável no 186/187.

**Feito no agldv03 (CT179), 2026-05-01:** `docker compose down` em `/opt/litellm` e em `/root/openclaw-docker` (contentores removidos; **não** voltam após reboot do CT até alguém correr `docker compose up -d` nesses directórios). Marcadores: `/opt/litellm/.STACK_STOPPED_AGLDV03`, `/root/openclaw-docker/.STACK_STOPPED_AGLDV03`.

**Crontab root:** removido (`crontab -r`); backup em `/root/crontab.root.bak.2026-05-01-agldv03` — restaurar com `crontab /root/crontab.root.bak.2026-05-01-agldv03`. Ficheiro de nota: `/root/.CRONTAB_DISABLED_AGLDV03`. O daemon `cron` mantém-se ativo para entradas em `/etc/cron.d/` (sistema, ex. `php`, `cron-apt`).

## Ficheiros no repo

| Ficheiro | Função |
|----------|--------|
| `docker/litellm/docker-compose.ct186.yml` | Compose self-contained em `/opt/agl-litellm` |
| `docker/openclaw/docker-compose.ct187.yml` | OpenClaw sem rede Docker externa LiteLLM |
| `scripts/proxmox/pct-create-agl-litellm-openclaw.sh` | `pct create` + start |
| `scripts/proxmox/bootstrap-ct186-litellm.sh` | Docker + stack LiteLLM |
| `scripts/proxmox/bootstrap-ct187-openclaw.sh` | Docker + stack OpenClaw |
| `scripts/proxmox/bootstrap-ct150-litellm.sh` / `bootstrap-ct151-openclaw.sh` | Wrappers de compat (avisam e chamam 186/187) |
| `scripts/proxmox/patch-openclaw-litellm-baseurl.py` | Ajustar `baseUrl` / `apiKey` |
| `scripts/proxmox/agl-litellm-openclaw-lxc.env.example` | Variáveis do `pct create` |
| `scripts/proxmox/pct-tailscale-up-litellm-openclaw.sh` | `tailscale up` com `TAILSCALE_AUTHKEY` nos CT186/187 |
| `scripts/proxmox/pct187-rotate-telegram-bot-token.sh` | Novo token Telegram (ficheiro + `pct push`) no CT187 |
| `scripts/proxmox/pct187-restore-telegram-env-from-backup.sh` | Repor `.env` no CT187 a partir de `.env.bak.telegram.*` |
| `scripts/proxmox/pct187-openclaw-docker-pull-restart.sh` | `docker compose pull` + `up -d` no CT187 (actualizar imagem OpenClaw) |

### Actualizar imagem OpenClaw no CT187

No **AGLSRV1**:

```bash
bash /caminho/agl-hostman/scripts/proxmox/pct187-openclaw-docker-pull-restart.sh
```

O Compose do CT187 só passa **`TELEGRAM_BOT_TOKEN`** ao gateway. Linhas como **`TELEGRAM_BOT_TOKEN_OLD=`** no mesmo `.env` ficam só no ficheiro (referência); **não** entram no contentor nem duplicam o canal.

Depois do pull, testar Telegram e: `pct exec 187 -- docker logs agl-openclaw-openclaw-gateway-1 --tail 80` (procurar ausência de `409` / `getUpdates`).

## Notas

- **Pin de imagens** em produção: definir `LITELLM_IMAGE` / `OPENCLAW_IMAGE` com tag ou digest estável.
- **Postgres** no compose CT186 usa `LITELLM_POSTGRES_PASSWORD` (default igual ao compose antigo); altere em `.env` + compose se rotacionar segredo.
- Se `pct create` falhar com `--tags`, remover essa linha do script (versões antigas do pve).

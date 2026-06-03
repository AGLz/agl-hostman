# hermes-desktop → Gateway Hermes (CT188)

Guia para ligar o [hermes-desktop](https://github.com/fathah/hermes-desktop) ao **Jarvis** no CT188 (`agl-hermes`, porta **8642**).

## Endpoints

| Rede | URL base |
|------|----------|
| LAN | `http://192.168.0.188:8642` |
| Tailscale | `http://100.81.225.22:8642` ou `http://aglsrv1-hermes.degu-chromatic.ts.net:8642` |

Use **HTTP** (não HTTPS). Pode omitir `/v1` no fim — o desktop normaliza automaticamente.

## Chave API (não confundir com LiteLLM)

O desktop envia `Authorization: Bearer <chave>`.

| Chave | Uso |
|-------|-----|
| **`API_SERVER_KEY`** em `/opt/agl-hermes/.env` (CT188) | hermes-desktop, integrações OpenAI-compatible |
| `sk-litellm-...` | Apenas proxy LiteLLM (CT186) — **não** funciona no gateway |

Obter no CT188:

```bash
grep ^API_SERVER_KEY= /opt/agl-hermes/.env
```

Sincronizar para o `env_file` do Jarvis (se `/v1/models` der 401 com chave “certa”):

```bash
bash /opt/agl-hostman/scripts/proxmox/sync-hermes-api-server-key-ct188.sh --restart-jarvis
```

## Configuração no hermes-desktop

1. **Settings** → **Connection**
2. Modo: **Remote** (não Local)
3. **Remote URL**: uma das URLs da tabela acima
4. **API Key**: valor de `API_SERVER_KEY`
5. Guardar e testar ligação

Modo **SSH** (alternativa): túnel local → gateway remoto; requer SSH no CT188 e a mesma `API_SERVER_KEY` no `.env` remoto.

## Teste rápido (no PC, antes do app)

Substituir `<KEY>` pela `API_SERVER_KEY`:

```bash
# Rede
curl -sS http://192.168.0.188:8642/health

# Auth (como o desktop)
curl -sS -H "Authorization: Bearer <KEY>" http://192.168.0.188:8642/v1/models
```

Script no repo:

```bash
HERMES_URL=http://192.168.0.188:8642 HERMES_API_KEY=<KEY> \
  bash scripts/proxmox/verify-hermes-desktop-remote.sh
```

Tailscale: trocar `HERMES_URL` por `http://100.81.225.22:8642`.

## WebSocket Claw3D / Hermes Office (`ws://…:18789`)

A porta **18789** **não** é o gateway Hermes em si — é o **adaptador WebSocket** ([hermes-office](https://github.com/fathah/hermes-office)) que traduz o protocolo Claw3D/OpenClaw para a API HTTP do Hermes (`:8642`).

| Rede | URL WebSocket |
|------|----------------|
| LAN | `ws://192.168.0.188:18789` |
| Tailscale | `ws://100.81.225.22:18789` (IP TS do CT188; confirmar com `tailscale ip -4` no CT) |

No **hermes-desktop** / Claw3D Studio:

1. Backend: **Hermes** (não OpenClaw puro)
2. Gateway URL: `ws://192.168.0.188:18789` (ou Tailscale)
3. Token: mesma **`API_SERVER_KEY`** do Remote HTTP

### Subir o adaptador no CT188

```bash
# root no CT188
bash /opt/agl-hostman/scripts/proxmox/bootstrap-hermes-claw3d-adapter-ct188.sh /opt/agl-hostman
```

Contentor: `agl-hermes-claw3d-adapter` (compose `hermes-claw3d-adapter` em `docker-compose.aglz-quartet.ct188.yml`).

### Alternativa: adaptador no PC local

Se não quiser expor `:18789` na rede, correr no desktop:

```bash
# dentro do checkout hermes-office
HERMES_API_URL=http://192.168.0.188:8642 HERMES_API_KEY=<API_SERVER_KEY> npm run hermes-adapter
```

E usar `ws://localhost:18789` no Claw3D.

### Nota sobre OpenClaw (CT187)

OpenClaw nativo usa `:18789` **dentro** do contentor; no CT187 a porta publicada no host é **`28789`**, IP **`192.168.0.187`** (LAN pode estar bloqueada entre CTs — preferir Tailscale `100.123.184.125:28789`). Isso é **outro** serviço; para Hermes + hermes-desktop use **CT188 :18789** (adaptador) + **:8642** (API).

## Problemas comuns

| Sintoma | Causa provável | Acção |
|---------|----------------|--------|
| “Cannot reach remote Hermes” | Firewall, PC fora da LAN, Tailscale off | `curl .../health` no PC |
| `/health` OK, chat falha 401 | Chave LiteLLM ou chave errada | Usar `API_SERVER_KEY` de `/opt/agl-hermes/.env` |
| URL com `/v1` no fim | Versões antigas do desktop | Atualizar app; URL base sem `/v1` |
| `https://...` | Gateway só HTTP | Usar `http://` |
| Só Tailscale falha, LAN OK | `accept-routes` no CT | Ver `docs/INFRA.md` (agl-lan-routes) |
| Porta errada | Só **Jarvis** expõe 8642 | Elon/Satya/Werner não têm API pública |

## Infra relacionada

- Mission Control + Claw3D: [`docs/HERMES-MISSION-CONTROL.md`](HERMES-MISSION-CONTROL.md)
- Quartet: [`docs/AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md)
- CT188: [`docs/HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md`](HERMES-EVONEXUS-OPENHUMAN-DEDICATED-LXC.md)
- Smoke: `scripts/proxmox/smoke-hermes-aglz-quartet.sh`

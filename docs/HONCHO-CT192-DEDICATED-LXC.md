# Honcho self-hosted (CT192) — AGLSRV1

Memória persistente cross-session para a **AGLz Agency** (Hermes CT188). Substitui Honcho cloud; dados ficam na LAN/Tailscale AGL.

| VMID | Hostname | IP LAN | Função | RAM / CPU / Disco |
|------|----------|--------|--------|-------------------|
| **192** | agl-honcho | `192.168.0.192` | Honcho API + Postgres + Redis + Deriver | 8 GB / 4 / 48 GB |

**Clientes:** CT188 (`agl-hermes`) — `honcho.json` → **`http://100.124.98.54:8000`** (Tailscale `aglsrv1-honcho.degu-chromatic.ts.net`).

**LLM do Honcho (Deriver/Dialectic):** apontar para **LiteLLM CT186** (Tailscale `http://100.125.249.8:4000/v1`) — modelos baratos (`glm-4.7-flash`, `gemini-lite`).

Upstream: [elkimek/honcho-self-hosted](https://github.com/elkimek/honcho-self-hosted) + [plastic-labs/honcho](https://github.com/plastic-labs/honcho).

---

## 1. Criar LXC (AGLSRV1)

```bash
cd /caminho/agl-hostman
cp scripts/proxmox/agl-honcho-lxc.env.example scripts/proxmox/agl-honcho-lxc.env
set -a && source scripts/proxmox/agl-honcho-lxc.env && set +a
bash scripts/proxmox/pct-create-agl-honcho.sh

bash scripts/proxmox/pct-apply-agldv03-lxc-profile.sh --with-apparmor 192
bash scripts/proxmox/pct-set-static-ip-agl-188-190.sh   # inclui .192 se script actualizado
```

Tailscale:

```bash
export TAILSCALE_AUTHKEY='tskey-auth-…'
# Adicionar 192 ao pct-tailscale-up-agency-cts.sh ou:
pct exec 192 -- tailscale up --accept-dns=false --hostname=aglsrv1-honcho --ssh
```

---

## 2. Bootstrap Honcho (dentro do CT192)

```bash
pct enter 192
bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct192-honcho.sh \
  http://100.125.249.8:4000/v1
```

O script:
- Instala Docker
- Clona `honcho-self-hosted` + `plastic-labs/honcho`
- Configura `.env` com LiteLLM como provider OpenAI-compatible
- Sobe stack (`docker compose up -d`)
- Smoke: `curl http://127.0.0.1:8000/openapi.json`

---

## 3. Ligar Hermes (CT188)

Após obter IP Tailscale do CT192:

```bash
pct exec 188 -- bash /caminho/agl-hostman/scripts/proxmox/bootstrap-ct188-hermes-aglz.sh \
  /caminho/agl-hostman \
  http://100.TS_HONCHO:8000
```

Workspace Honcho: **`aglz-agency`** · peers AI: `jarvis`, `elon`, `satya`, `werner`.

---

## 4. Verificação

```bash
# CT192
curl -sf http://127.0.0.1:8000/openapi.json | head -c 80

# CT188 (Tailscale)
curl -sf http://100.TS_HONCHO:8000/openapi.json | head -c 80

# Hermes (dentro do contentor, se CLI existir)
hermes memory status
```

---

## Manutenção

```bash
cd /opt/agl-honcho/honcho
docker compose pull && docker compose up -d --build
docker compose exec database pg_dump -U honcho honcho > /root/backups/honcho-$(date +%F).sql
```

---

## Referências

- Hermes + Honcho: https://honcho.dev/docs/v3/guides/integrations/hermes
- Agência AGLz: [`AGLZ-HERMES-ONLY-AGENCY.md`](AGLZ-HERMES-ONLY-AGENCY.md)

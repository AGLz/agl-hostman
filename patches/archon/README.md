# Archon — CT183 (AGLSRV1)

> **Last Updated**: 2026-06-09

## Arquitectura AGL

| CT | Hostname | Função |
|----|----------|--------|
| **183** | archon | **Archon v0.4** (workflow engine) — `http://192.168.0.183:3000` |
| **184** | supabase | **Supabase self-hosted** — `http://192.168.0.184:8000` (Kong API) |

**Não** correr Supabase no CT183. O stack legado em `/root/supabase-self-hosted*` foi desactivado; usar **sempre CT184**.

O Archon v0.4 **não** usa a API Supabase/PostgREST — usa PostgreSQL próprio (`archon-postgres`) ou SQLite. O CT184 fica disponível para outros serviços (RAG legado, agency, etc.).

---

## Archon v0.4 (produto actual)

- Imagem: `ghcr.io/coleam00/archon:latest`
- Versão: **0.4.x** (CLI workflow engine — branch `main`)
- Deploy: `/opt/archon/docker-compose.yml` (`docker-compose.v2-ct183.yml` neste repo)
- UI: porta **3000**
- Docs: https://archon.diy

### Comandos

```bash
cd /opt/archon
docker compose pull
docker compose up -d
curl http://localhost:3000/api/health
```

**PostgreSQL (obrigatório com `--profile with-db` / stack CT183):** na 1ª instalação o volume `postgres_data` deve receber o schema. O `docker-compose.v2-ct183.yml` monta `migrations/000_combined.sql` em `docker-entrypoint-initdb.d` (só na criação inicial do volume). Se `/api/codebases` devolver 500 (`relation "remote_agent_codebases" does not exist`), correr:

```bash
bash /opt/archon/init-db-ct183.sh
```

### Variáveis (`.env`)

Ver `env.ct183.example`. Mínimo:

- `PORT=3000`
- `ARCHON_DATA=/opt/archon-data`
- `ARCHON_USER_HOME=/opt/archon-user-home`
- `DATABASE_URL=postgresql://postgres:...@postgres:5432/remote_coding_agent`
- Credenciais Claude (`CLAUDE_CODE_OAUTH_TOKEN` ou `CLAUDE_API_KEY`) antes de workflows

### Cloudflare (CT117)

Túnel **`aglsrv1b`** (`908b1097-e182-4725-9960-626ecc003375`) corre no **CT117** via `cloudflared-archon.service`.

| Hostname | Destino correcto (v0.4) |
|----------|-------------------------|
| `archon.aglz.io` | `http://192.168.0.183:3000` |

**Importante:** este túnel é **remotamente gerido** (Zero Trust). A config em `/root/.cloudflared/config.yml` no CT117 é **sobrescrita** pelo ingress remoto (v34 ainda apontava `:3737` em Jun 2026).

**Workaround activo (CT183):** `archon-v04-proxy.service` — nginx em `:3737` → `:3000` até actualizar o ingress remoto. Ficheiros em `patches/archon/proxy/`.

**Actualizar ingress remoto:**

1. Zero Trust → Networks → Tunnels → `aglsrv1b` → Public Hostname: `archon.aglz.io` → `http://192.168.0.183:3000`
2. Remover hostnames legados `archon-api.aglz.io` / `archon-mcp.aglz.io` (v1)
3. Ou: `scripts/cloudflare/update-archon-tunnel-ingress.sh` (requer `CLOUDFLARE_API_TOKEN` válido)

**Não** correr `cloudflared-archon` no CT183 em paralelo — só CT117.

---

## Supabase (CT184 apenas)

```bash
# API Kong
curl -s -o /dev/null -w "%{http_code}" http://192.168.0.184:8000/rest/v1/

# Studio (via rede interna; expor via tunnel se necessário)
# http://192.168.0.184:8000 ou portas internas do stack
```

Documentação: `docs/CT184-SUPABASE-SETUP-COMPLETE.md`

---

## Legado v1 (archivado)

Branch `archive/v1-task-management-rag` — MCP/RAG/task management. **Descontinuado** no CT183 (Jun 2026). Backup em `/root/backups/pre-archon-v2-*`.

Ficheiros históricos neste repo: `docker-compose-hostnet.yml`, `docker-compose-hostnet-build.yml`.

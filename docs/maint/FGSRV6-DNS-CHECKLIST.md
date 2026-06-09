# FGSRV6 — Checklist DNS / Cloudflare (Fase 0)

Confirmar na consola **Cloudflare** (e registrars externos) antes de formatar o VPS.

**IP alvo actual:** `186.202.57.120`  
**Tunnel:** `aglsrv5e` — ID `863fd93d-73c5-4c3e-90b5-7cbd37643f70`

## Nginx no host (registos A/AAAA prováveis)

| Hostname | Serviço | Porta origem |
|----------|---------|--------------|
| `aglpy01.aguileraz.net` | Python | :80 |
| `aglpy02.aguileraz.net` | Python | :80 |
| `api-v8-dev.falg.com.br` | PHP API | :80 / :443 |
| `api-v8-qa.falg.com.br` | PHP API | :80 |
| `api-v9-dev.falg.com.br` | PHP API | :80 / :443 |

## Cloudflare Tunnel (ingress documentado)

| Hostname | Backend |
|----------|---------|
| `n8n5e.aglz.io` | `https://186.202.57.120:4443` |
| `portainer5e.aglz.io` | `https://186.202.57.120:9443` |

## Outros (verificar zona `aglz.io` / `falg.com.br`)

- Qualquer `*.aglz.io` com A record → `186.202.57.120`
- LiteLLM exposto? (`:4000` — normalmente não público; via TS/outros hosts)
- `vps41772.publiccloud.com.br` — PTR Locaweb

## Verificação rápida

```bash
for h in n8n5e.aglz.io portainer5e.aglz.io api-v9-dev.falg.com.br api-v8-dev.falg.com.br; do
  echo "=== $h ==="
  dig +short "$h" A
done
```

## Dig rápido (2026-06-04)

| Hostname | A record (short) |
|----------|------------------|
| `n8n5e.aglz.io` | Cloudflare proxy (104.21.x / 172.67.x) |
| `portainer5e.aglz.io` | Cloudflare proxy |
| `api-v9-dev.falg.com.br` | Cloudflare proxy |
| `api-v8-dev.falg.com.br` | Cloudflare proxy |
| `aglpy01.aguileraz.net` | *(vazio no dig local)* |

APIs e túneis passam por **Cloudflare** — após migração, actualizar **tunnel ingress** / origin, não só A record.

## Estado

| Item | Feito |
|------|-------|
| Lista hostnames nginx | ✅ 2026-06-04 (audit SSH) |
| Dig público | ✅ 2026-06-04 (proxy CF) |
| Scan DNS Cloudflare dashboard | ⬜ manual |
| Atualizar ingress pós-migração | ⬜ |

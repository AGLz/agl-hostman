# Runbook — Cutover Cloudflare `ah.aglz.io` (dev → prod CT134)

> **Túnel DNS `ah.aglz.io`:** CNAME → **`f7ab6239-5cbd-44ef-83b9-ee8bfb4965ce`** (**aglsrv1**, CT117 `systemd` token).  
> **Não** confundir com **aglsrv1b/archon** (`908b1097-…`) — ingress lá não afecta `ah.aglz.io`.  
> Script: `scripts/cloudflare/update-ah-aglz-tunnel-ingress.sh` (patch só `ah.aglz.io` / `ah-dev.aglz.io`).  
> **Plano:** [`ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md`](../../ai-docs/planning/CT134-IMPLEMENTATION-PLAN.md) (Fase 5)

---

## 1. Objectivo

1. Mover **`https://ah.aglz.io`** do ambiente **dev** para **produção CT134** (`192.168.0.134`).
2. Criar **`https://ah-dev.aglz.io`** apontando para o destino dev **actual** de `ah.aglz.io`.
3. Minimizar downtime e permitir rollback em minutos.

---

## 2. Mapa de domínios (alvo)

| Hostname          | Ambiente     | Origin (service)          | Notas                       |
| ----------------- | ------------ | ------------------------- | --------------------------- |
| `ah.aglz.io`      | **Produção** | `http://192.168.0.134:80` | CT134 — Laravel Docker      |
| `ah-dev.aglz.io`  | Dev          | _origin dev actual_       | CT179 / nginx host — ver §3 |
| `ah-qa.aglz.io`   | QA           | TBD                       | Fase posterior              |
| `ah-uat.aglz.io`  | UAT          | TBD                       | Fase posterior              |
| `pr-N.ah.aglz.io` | Preview PR   | TBD                       | Dokploy preview (opcional)  |

Aliases legados (opcional, mesmo origin prod): `agl-hostman.aglz.io`, `prod-agl.aglz.io`.

---

## 3. Descobrir origin dev actual

Antes de alterar qualquer hostname, documentar o estado **actual**.

### 3.1 DNS / Tunnel (Zero Trust)

1. Cloudflare Dashboard → **Zero Trust** → **Networks** → **Tunnels** → **archon**.
2. Tab **Public Hostname** — localizar entrada `ah.aglz.io`.
3. Anotar **Service** (ex.: `http://192.168.0.179:8080`, `http://192.168.0.x:80`, nginx host).

### 3.2 Via CLI (CT117)

```bash
ssh root@192.168.0.245 'pct exec 117 -- cat /root/.cloudflared/config.yml'
# Se ingress for só remoto (Zero Trust UI), config local pode não listar ah.aglz.io
ssh root@192.168.0.245 'pct exec 117 -- cloudflared tunnel info archon'
```

### 3.3 Dev típico AGL (CT179 agldv03)

Referências no repo:

- Nginx host: `/etc/nginx/sites-available/ah.aglz.io.conf` (ver `scripts/deployment/deploy-mount-path.sh`)
- Docker local: `docker/nginx/conf.d/app.conf` (`server_name ah.aglz.io`)
- Mount NFS: `/mnt/overpower/apps/dev/agl/agl-hostman`

**Origin dev provável:** IP do CT179 ou host que serve nginx na porta **80/443** — confirmar com:

```bash
# De um host LAN
curl -sI -H 'Host: ah.aglz.io' http://<IP-DEV>/ | head -5
```

Preencher aqui antes do cutover:

| Campo              | Valor (preencher)             |
| ------------------ | ----------------------------- |
| Host dev           | ex. CT179 `192.168.0.179`     |
| Porta              | ex. `80` ou `8080`            |
| Service URL tunnel (dev) | `http://192.168.0.181:8055` (agldv04 nginx NFS) |

---

## 4. Pré-requisitos (bloqueadores)

- [ ] CT134 deploy OK — `curl -sf http://192.168.0.134/health/` (LAN)
- [ ] Certificado TLS termina no Cloudflare (modo Full ou Full Strict) — origin CT134 HTTP OK
- [ ] `APP_URL=https://ah.aglz.io` no `.env` CT134 / Dokploy
- [ ] Migrations aplicadas em prod
- [ ] Equipa avisada da janela (~15 min risco)

---

## 5. Procedimento de cutover

### Passo A — Criar `ah-dev.aglz.io` (sem tocar em prod ainda)

**Zero Trust UI:**

1. Tunnels → **archon** → **Public Hostname** → **Add a public hostname**.
2. Subdomain: `ah-dev` · Domain: `aglz.io` · Path: (vazio).
3. Service: **origin dev** anotado em §3 (ex. `http://192.168.0.179:80`).
4. Save.

**Validar:**

```bash
curl -fsS https://ah-dev.aglz.io/health/
# Deve responder como dev actual
```

Se DNS demorar: `dig ah-dev.aglz.io +short` (CNAME para tunnel).

---

### Passo B — Validar prod CT134 (ainda sem tráfego público)

```bash
curl -fsS http://192.168.0.134/health/
curl -fsS -H 'Host: ah.aglz.io' http://192.168.0.134/health/
```

Opcional — hostname temporário interno:

- Adicionar `ah-staging.aglz.io` → CT134, testar, depois remover.

---

### Passo C — Repoint `ah.aglz.io` → CT134

**Zero Trust UI:**

1. Editar public hostname **`ah.aglz.io`** (não apagar até confirmar dev em ah-dev).
2. Alterar Service para: `http://192.168.0.134:80`  
   (ajustar porta se Dokploy expuser outra, ex. `:3000` ou Traefik `:443` interno).
3. Save — cloudflared CT117 actualiza em ~30 s.

**Validar imediato:**

```bash
curl -fsS https://ah.aglz.io/health/
curl -fsS https://ah.aglz.io/health/liveness
npm run test:e2e:ah   # smoke Playwright (opcional)
```

---

### Passo D — Pós-cutover

1. Actualizar GitHub secret `CT134_HEALTH_URL=https://ah.aglz.io/health/`.
2. Verificar cookies/sessions (domínio igual — utilizadores podem precisar re-login).
3. Monitorizar 30 min:
   ```bash
   ssh root@192.168.0.134 'docker compose -f /opt/agl-hostman-prod/docker-compose.yml logs -f app'
   ```

---

## 6. Rollback (≤ 5 min)

1. Zero Trust → `ah.aglz.io` → repor **Service** para origin dev (§3).
2. Confirmar `https://ah.aglz.io` volta ao dev.
3. CT134 continua disponível em LAN: `http://192.168.0.134`.
4. Investigar logs CT134 antes de nova tentativa.

**Não** apagar `ah-dev.aglz.io` até rollback testado.

---

## 7. Config local (alternativa — config.yml)

Se `ah.aglz.io` estiver em `/root/.cloudflared/config.yml` no CT117 (ingress local):

```yaml
ingress:
  - hostname: ah-dev.aglz.io
    service: http://192.168.0.179:80 # DEV — ajustar
  - hostname: ah.aglz.io
    service: http://192.168.0.134:80 # PROD CT134
  - hostname: archon.aglz.io
    service: http://192.168.0.183:8080
  # ... restantes hostnames ...
  - service: http_status:404
```

Depois:

```bash
ssh root@192.168.0.245 'pct exec 117 -- systemctl restart cloudflared'
ssh root@192.168.0.245 'pct exec 117 -- journalctl -u cloudflared -n 20 --no-pager'
```

> **Nota:** Muitos túneis AGL usam config **remota** Zero Trust; nesse caso editar só na UI (passos A/C).

---

## 8. DNS CNAME (referência)

Cloudflare cria automaticamente CNAME `ah.aglz.io` → `<tunnel-id>.cfargotunnel.com` ao adicionar public hostname. Não criar A record manual salvo excepção documentada.

Verificar:

```bash
dig ah.aglz.io CNAME +short
dig ah-dev.aglz.io CNAME +short
```

---

## 9. Troubleshooting

| Sintoma                        | Causa provável            | Acção                                      |
| ------------------------------ | ------------------------- | ------------------------------------------ |
| 502 Bad Gateway                | CT134 down / porta errada | `docker ps` no CT134; corrigir service URL |
| 404                            | Host header / nginx       | `server_name ah.aglz.io` no container      |
| SSL handshake                  | Origin HTTPS inválido     | Usar `http://` no tunnel se TLS só na edge |
| Dev offline após cutover       | Falta `ah-dev`            | Completar passo A                          |
| Health 200 LAN mas 502 público | Tunnel não actualizado    | Restart cloudflared; ver journal           |

---

## 10. Referências

- [`docs/CLOUDFLARE-TUNNELS.md`](../CLOUDFLARE-TUNNELS.md) — CT117 archon
- [`docs/CT134-AGL-HOSTMAN-PRODUCTION.md`](../CT134-AGL-HOSTMAN-PRODUCTION.md)
- Cloudflare: [Public hostnames](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/routing-to-tunnel/)

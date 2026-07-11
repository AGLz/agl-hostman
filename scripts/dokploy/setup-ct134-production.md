# Dokploy + Harbor — CT134 agl-hostman produção

Automatizado via API: `bash scripts/dokploy/setup-ct134-via-api.sh`  
Deploy rolling real: `IMAGE_TAG=prod-<sha> bash scripts/dokploy/trigger-ct134-deploy.sh`

> Dokploy CT180 sem Traefik não aplica compose remoto no CT134; deploy efectivo via SSH (aglsrv1).

UI: https://dok.aglz.io (`scripts/cloudflare/update-dok-aglz-tunnel-ingress.sh`)

## 1. Registar CT134 como Server

1. Dokploy → **Servers** → Add Server
2. IP: `192.168.0.134` (ou Tailscale do CT134)
3. SSH user: `root` (ou deploy user com grupo `docker`)
4. Colar chave SSH gerada pelo Dokploy
5. Test connection → Save

## 2. Harbor — projecto `agl-hostman-prod`

1. https://harbor.aglz.io → New Project `agl-hostman-prod` (private)
2. Robot account `github-actions-prod` — push/pull
3. Guardar credenciais em GitHub Secrets (`HARBOR_*`)
4. Webhook (opcional, redundante com GHA):
   - Event: Artifact pushed
   - URL: webhook da app Dokploy (Settings → Webhooks)

## 3. App Dokploy `agl-hostman-prod`

| Campo | Valor |
|-------|--------|
| Type | Docker Compose **ou** Docker Image |
| Server | CT134 |
| Image | `harbor.aglz.io/agl-hostman-prod/hostman:prod-latest` |
| Registry auth | robot Harbor |
| Compose path | `/opt/agl-hostman-prod/docker-compose.yml` (se compose) |
| Branch | N/A (image-based) |
| Auto Deploy | ON |
| Domain | `ah.aglz.io` |

### Webhook produção

Copiar URL:

```
https://dok.aglz.io/api/webhook/trigger/<applicationId>/<secret>
```

→ GitHub Secret `DOKPLOY_PROD_WEBHOOK_URL`

Payload esperado pelo workflow (JSON):

```json
{"tag":"prod-abc1234","commit":"<sha>","branch":"main"}
```

Ajustar handler Dokploy se usar API nativa `application.deploy` com Bearer token.

## 4. GitHub App Dokploy (alternativa recomendada)

Docs: https://dokploy-dokploy.mintlify.app/integrations/git-providers/github

1. Dokploy → Settings → Git → Install GitHub App
2. Repo: `AGLz/agl-hostman` (ajustar org)
3. App prod: branch `main`, Auto Deploy ON
4. PR previews: ON + **Require Collaborator Permissions**
5. Webhook URL pública: `https://dok.aglz.io/api/deploy/github`

**Nota:** Com GitHub App, o workflow GHA pode ficar só para test+build+push; Dokploy faz deploy no push/PR.

## 5. Cloudflare / DNS

- `ah.aglz.io` → CT134 (produção)
- Futuro: `ah-dev.aglz.io`, `ah-qa.aglz.io`, `ah-uat.aglz.io` → CTs/ambientes respectivos
- Preview PR: `pr-{n}.ah.aglz.io` ou subdomínio dedicado

## 6. Smoke pós-deploy

```bash
curl -fsS https://ah.aglz.io/health/
ssh root@192.168.0.134 'docker ps && docker logs agl-hostman-prod-app --tail 30'
```

## 7. Rollback

Dokploy → Deployments → Redeploy previous **ou**:

```bash
# CT134
cd /opt/agl-hostman-prod
sed -i 's|:prod-.*|:prod-PREV_SHA|' .env
docker compose pull && docker compose up -d
```

Ver [`docs/ROLLBACK-USAGE.md`](../../docs/ROLLBACK-USAGE.md).

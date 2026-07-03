---
name: agl-sast-gate
description: Gate SAST local AGL — Semgrep, composer audit, npm audit, scan secrets. Usar antes de PR, após dependências novas, ou quando security-scan CI falhar.
origin: agl-hostman
---

# SAST Gate AGL

## Sequência (Gather → Scan → Verify)

```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman  # ou repo root

# 1. Node dependencies
npm audit --audit-level=high || true
npm audit --json > /tmp/npm-audit.json 2>/dev/null || true

# 2. PHP/Laravel
cd src && composer audit --no-interaction || true
cd ..

# 3. Semgrep (se instalado)
if command -v semgrep >/dev/null 2>&1; then
  semgrep scan --config auto --error --quiet .
fi

# 4. Secrets em diff (heurística rápida)
git diff --name-only | xargs -r grep -lE 'sk-[a-zA-Z0-9]{20,}|api[_-]?key\s*=\s*["\x27][^"\x27]+' 2>/dev/null \
  && echo "ALERTA: possível secret no diff" || true
```

## Critérios de bloqueio

| Finding | Acção |
|---------|-------|
| CRITICAL npm/composer | Bloquear merge até fix ou aceite documentado |
| Secret verificado no diff | Rotacionar + remover imediatamente |
| Semgrep ERROR | Corrigir ou suprimir com justificação em comentário |

## CI

Workflow canónico: `.github/workflows/security-scan.yml` (Trivy, TruffleHog, npm audit).

Laravel em PRs: job `composer-audit` no mesmo workflow.

## Rollback

Se gate falhar pós-merge: reverter commit; re-correr `agl-stack-testing` + este gate antes de re-deploy.

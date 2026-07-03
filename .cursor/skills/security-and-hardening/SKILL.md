---
name: security-and-hardening
description: OWASP Top 10, auth patterns, secrets, dependency audit, boundaries de confiança no stack AGL. Usar com input de utilizador, novos endpoints API, auth, uploads, ou integrações externas (LiteLLM, webhooks).
origin: addyosmani/agent-skills (adaptado AGL)
---

# Security & Hardening (AGL)

## OWASP — prioridade em agl-hostman

| Risco | Mitigação AGL |
|-------|----------------|
| Injection | Eloquent/PDO; validação FormRequest; Zod em Node API |
| Broken Auth | Laravel Sanctum/session; rate limit Fastify |
| Sensitive Data | `.env`; `SecretsManagementService`; nunca logar tokens |
| SSRF | Allowlist URLs em webhooks; não fetch user URL arbitrária |
| Security Misconfig | `security-scan.yml`; headers em `web-security.mdc` |

## Três boundaries

1. **Público** — validação estrita, rate limit, sem dados internos em erros
2. **Autenticado** — authorization por role/policy
3. **Interno/Agent** — MCP tools, LiteLLM keys — least privilege

## Auth patterns

- Laravel: policies, gates, `authorize()` em controllers
- API Node: middleware auth antes de handlers
- LiteLLM: master key só em env CT186

## Dependency audit

```bash
npm audit --audit-level=high
cd src && composer audit
```

Ver skill `agl-sast-gate`.

## Defense in depth

Combinar com skill `defense-in-depth` — validar em entry + business logic + environment.

## Review obrigatório quando

- Novo endpoint público
- Upload de ficheiros
- Pagamentos / PII
- Alteração CI/CD ou secrets

Invocar `review-security` subagent.

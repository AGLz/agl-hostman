# Pipeline de Entrega Obrigatório (AGL — Claude Code / agentes)

Aplica a todo trabalho com alterações de código ou config versionável.

## Sequência

1. Implementar (diff mínimo)
2. Testar (testes afetados; verde antes de avançar)
3. **code-reviewer** após código novo/alterado (CRITICAL/HIGH corrigidos)
4. Commit — só se o utilizador pedir; conventional commits; sem secrets
5. Push — branch sincronizada com remoto
6. PR — `gh pr create` com resumo + test plan; merge após checks
7. Conflitos — `git pull --rebase`, resolver, retestar, push

## Nunca considerar concluído

- Alterações críticas só locais quando existe remoto Git
- Features/APIs sem review
- Push falhado ou branch divergente não resolvida

## Verificação final

```bash
git status
git diff --stat
```

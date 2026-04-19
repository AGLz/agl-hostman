---
name: git-workflow-complete
version: 1.1.0
description: Complete Git workflow automation including commit, push, merge and code review. Use when user wants to commit changes, push to remote, create PRs, merge branches, or perform code reviews. Automates conventional commits, smart pushing, PR creation with proper descriptions, and comprehensive code review coordination.
category: git
tags: [git, commit, push, merge, pr, code-review, workflow, automation]
author: AGL Hostman
capabilities:
  - Conventional commit message generation
  - Smart staging and pushing
  - PR creation with detailed descriptions
  - Multi-agent code review
  - Automated merge workflows
  - Git status verification
  - Interactive code review assistance
  - Branch synchronization
---

# Git Workflow Complete

Complete Git workflow automation for commit, push, PR creation, code review, and merge operations.

## 🎯 Quick Start

### Commit and Push
```bash
# Stage all changes with conventional commit
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh "feat(scope): descrição"

# Or without message (auto-generates)
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh
```

### Create Pull Request
```bash
# Create PR with comprehensive description
gh pr create --draft --title "feat(scope): descrição" --body "$(cat <<'EOF'
## Summary
Descrição das mudanças

## Motivação
Por que estas mudanças são necessárias

## Alterações
- Mudança 1
- Mudança 2
EOF
)"
```

### Code Review
```bash
# Review PR with assistance
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh <PR_NUMBER>

# Or with gh CLI directly
gh pr view 123 --json files,diff
gh pr checkout 123
```

### Merge PR
```bash
# Interactive merge with checks
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER> [--squash|--merge|--rebase]

# Or with gh CLI
gh pr merge 123 --squash --delete-branch
```

### Repository Status
```bash
# Complete repository status
bash .claude/skills/git-workflow-complete/scripts/status_check.sh
```

---

## 📋 Complete Workflow

### Phase 1: Pre-Commit Checks

```bash
# Check git status
bash .claude/skills/git-workflow-complete/scripts/status_check.sh

# Run pre-commit validations
bash .claude/skills/git-workflow-complete/scripts/pre-commit.sh
```

### Phase 2: Commit

**Conventional Commit Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `docs`: Documentação
- `style`: Formatação (sem mudança de código)
- `refactor`: Refatoração
- `perf`: Performance
- `test`: Testes
- `chore`: Tarefas de build/manutenção

**Scopes para este projeto:**
- `api`: API Node/Fastify
- `laravel`: Aplicação Laravel
- `litellm`: Configurações LiteLLM
- `docker`: Docker/Compose
- `docs`: Documentação
- `scripts`: Scripts de automação
- `config`: Configurações

**Example Commit:**
```bash
git add .
git commit -m "$(cat <<'EOF'
feat(laravel): adicionar autenticação JWT

Implementa autenticação JWT para API endpoints:
- Login com email/senha
- Refresh token
- Logout com blacklist

Testes incluídos para todos os endpoints.
Refs #123
EOF
)"
```

### Phase 3: Push

```bash
# Push com upstream tracking
git push -u origin $(git branch --show-current)

# Verificar status remoto
bash .claude/skills/git-workflow-complete/scripts/status_check.sh
```

### Phase 4: Create PR

**Create PR Command:**
```bash
# Get current branch and commits
BRANCH=$(git branch --show-current)
BASE=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')

# Create draft PR
gh pr create --draft \
  --title "feat(scope): descrição resumida" \
  --body-file .claude/skills/git-workflow-complete/templates/pr_template.md
```

### Phase 5: Code Review

**Review PR:**
```bash
# Interactive review helper
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh <PR_NUMBER>

# Self-Review Checklist:
# - Segredos/credenciais no código
# - console.log / debug statements
# - Código comentado não utilizado
# - Importações não utilizadas
# - Erros de linting
```

**Request Review:**
```bash
# Request specific reviewers
gh pr edit 123 --add-reviewer username

# Add labels
gh pr edit 123 --add-label "needs-review"
```

### Phase 6: Merge

**Before Merge:**
```bash
# Check PR status
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER>

# Verify all checks pass
gh pr checks 123

# Update from base branch
git fetch origin
git rebase origin/$BASE
```

**Merge Options:**
```bash
# Squash merge (recomendado para features)
gh pr merge 123 --squash --delete-branch

# Regular merge (para releases)
gh pr merge 123 --merge --delete-branch

# Rebase merge
gh pr merge 123 --rebase --delete-branch
```

---

## 🔄 Common Workflows

### Feature Development
```bash
# 1. Create feature branch
git checkout -b feature/nome-da-feature

# 2. Make changes and commit
# ... edit files ...
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh "feat(scope): nova feature"

# 3. Create PR
gh pr create --draft --title "feat(scope): nova feature" --body-file .claude/skills/git-workflow-complete/templates/pr_template.md

# 4. Request review
gh pr edit --add-label "needs-review" --add-reviewer @username

# 5. After approval, merge
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER> --squash
```

### Hotfix
```bash
# 1. Create hotfix branch from main
git checkout main
git pull
git checkout -b hotfix/correcao-urgente

# 2. Fix and commit
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh "fix(scope): corrigir bug crítico"

# 3. Create PR (high priority)
gh pr create --title "fix(scope): corrigir bug crítico" \
  --body "## Hotfix..." \
  --label "hotfix,urgent"

# 4. Fast merge
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER> --merge
```

### Code Review
```bash
# View PR details
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh 123

# Review diff
gh pr diff 123

# Checkout PR branch
gh pr checkout 123

# Run tests locally
npm test

# Approve PR
gh pr review 123 --approve --body "LGTM! 🚀"

# Or request changes
gh pr review 123 --request-changes --body "Precisa ajustar..."
```

---

## 🛠️ Scripts Reference

| Script | Descrição | Uso |
|--------|-----------|-----|
| `smart_commit.sh` | Commit inteligente com auto-detecção | `bash smart_commit.sh ["mensagem"]` |
| `pre-commit.sh` | Validações antes do commit | `bash pre-commit.sh` |
| `status_check.sh` | Status completo do repo | `bash status_check.sh` |
| `review_pr.sh` | Assistente de code review | `bash review_pr.sh <PR_NUMBER>` |
| `merge_pr.sh` | Merge com verificações | `bash merge_pr.sh <PR_NUMBER> [--squash]` |

---

## 📝 PR Templates

### Feature PR
```markdown
## Summary
Adiciona [descrição da feature]

## Motivação
[Por que esta feature é necessária]

## Implementação
- [ ] Código segue padrões
- [ ] Testes adicionados
- [ ] Documentação atualizada

## Breaking Changes
[Nenhuma / Descrever]

## Screenshots
[Se aplicável]

## Testes
- [ ] Unitários passam
- [ ] Integração passam
- [ ] E2E passam
```

### Bug Fix PR
```markdown
## Summary
Corrige [descrição do bug]

## Problema
[Descrição do bug encontrado]

## Solução
[Como foi corrigido]

## Testes
- [ ] Bug reproduzido em teste
- [ ] Fix validado
- [ ] Regressão testada

## Referências
Fixes #123
```

---

## 🔒 Security Checklist

- [ ] Nenhum segredo/commit no código
- [ ] `.env` files não commitados
- [ ] Credenciais hardcoded removidas
- [ ] Console.logs de debug removidos
- [ ] Dependências verificadas (`npm audit` / `composer audit`)

---

## 📚 Best Practices

### Commits
- Commits atômicos (uma alteração lógica por commit)
- Mensagens claras e descritivas
- Use Conventional Commits
- Referencie issues quando aplicável

### PRs
- Mantenha PRs pequenos (< 400 linhas)
- Descrição clara do que e por que
- Inclua testes
- Responda a reviews em 24h

### Reviews
- Seja construtivo e respeitoso
- Explique o porquê das sugestões
- Distinguish blocking vs suggestions
- Approve quando estiver satisfeito

---

## 🆘 Troubleshooting

### Push Rejected
```bash
# Fetch latest changes
git fetch origin

# Rebase your changes
git rebase origin/main

# Or merge
git merge origin/main

# Then push
git push
```

### Merge Conflicts
```bash
# See conflicting files
git status

# Resolve each file
# Edit, remove conflict markers

# Mark as resolved
git add <file>

# Complete merge
git commit
```

### Undo Last Commit
```bash
# Keep changes
git reset --soft HEAD~1

# Discard changes
git reset --hard HEAD~1

# Amend commit
git commit --amend
```

---

**Last Updated:** 2026-04-19
**Version:** 1.1.0
**Project:** agl-hostman

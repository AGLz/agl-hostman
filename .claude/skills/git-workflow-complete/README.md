# Git Workflow Complete Skill

Skill completa para workflow Git incluindo commit, push, merge e code review.

## 🎯 Uso Rápido

### Commit e Push Automático
```bash
# Commit com mensagem auto-gerada
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh

# Commit com mensagem específica
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh "feat(api): adicionar endpoint de autenticação"
```

### Pre-Commit Checks
```bash
# Validar alterações já no índice (git add) antes do commit real
git add -p   # ou git add <ficheiros>
bash .claude/skills/git-workflow-complete/scripts/pre-commit.sh
```

O `pre-commit.sh` só analisa ficheiros **staged**. A heurística de segredos (palavras-chave em ficheiros staged) **bloqueia** com exit 1 se encontrar correspondências (como `.env` no índice). Pode gerar **falsos positivos** (ex.: `token` em tipos ou comentários); nesse caso remova o match ou ajuste o ficheiro antes de voltar a fazer `git add`.

### Status do Repositório
```bash
# Verificar status completo
bash .claude/skills/git-workflow-complete/scripts/status_check.sh
```

### Criar Pull Request
```bash
# Usar template
gh pr create --title "feat(scope): descrição" --body-file .claude/skills/git-workflow-complete/templates/pr_template.md
```

### Code Review
```bash
# Assistente de review
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh <PR_NUMBER>

# Comandos úteis
gh pr view 123          # Ver PR
gh pr diff 123          # Ver diff
gh pr checkout 123      # Checkout branch
gh pr review 123 --approve  # Aprovar
```

### Merge PR
```bash
# Merge interativo com verificações
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER> [--squash|--merge|--rebase]

# Merge direto
gh pr merge 123 --squash --delete-branch
```

## 📁 Estrutura

```
git-workflow-complete/
├── SKILL.md              # Documentação principal da skill
├── README.md             # Este arquivo
├── scripts/
│   ├── smart_commit.sh   # Script de commit inteligente
│   ├── pre-commit.sh     # Pre-commit hooks
│   ├── status_check.sh   # Verificação de status
│   ├── review_pr.sh      # Assistente de code review
│   └── merge_pr.sh       # Merge com verificações
└── templates/
    └── pr_template.md    # Template para PRs
```

## 🔧 Funcionalidades

### Smart Commit
- ✅ Auto-detecção de escopo (api, laravel, litellm, docker, docs, scripts, tests)
- ✅ Auto-detecção de tipo (feat, fix, docs, test, refactor)
- ✅ Mensagem automática: se o índice estiver vazio, usa o working tree (`git status --porcelain`) para contar ficheiros e inferir tipo/escopo **antes** do `git add -A` (evita “0 arquivo(s)”)
- ✅ Conventional Commits format
- ✅ Footer com autor e data
- ✅ Push automático com upstream

### Pre-Commit
- ✅ Verificação de segredos/credenciais nos ficheiros staged — **falha o script** (não só aviso) até corrigir ou retirar do índice
- ✅ Detecção de arquivos .env
- ✅ Encontrar console.log/debug statements
- ✅ Execução de linter (npm run lint / pint)
- ✅ Validação de mensagem de commit

### Status Check
- ✅ Branch atual
- ✅ Alterações pendentes
- ✅ Commits recentes
- ✅ Status das branches remotas
- ✅ PRs abertos
- ✅ Stashes

### PR Review
- ✅ Informações do PR
- ✅ Estatísticas de alterações
- ✅ Status dos checks
- ✅ Checklist de review
- ✅ Comandos úteis

### PR Merge
- ✅ Verificação do estado do PR
- ✅ Validação de checks
- ✅ Confirmação interativa
- ✅ Delete automático da branch

## 📝 Conventional Commits

Formato: `<type>(<scope>): <subject>`

**Types:**
- `feat`: Nova funcionalidade
- `fix`: Correção de bug
- `docs`: Documentação
- `style`: Formatação
- `refactor`: Refatoração
- `perf`: Performance
- `test`: Testes
- `chore`: Tarefas de manutenção

**Scopes para este projeto:**
- `api`: API Node/Fastify
- `laravel`: Aplicação Laravel
- `litellm`: Configurações LiteLLM
- `docker`: Docker/Compose
- `docs`: Documentação
- `scripts`: Scripts de automação
- `tests`: Testes

## 🔄 Workflows

### Feature Development
```bash
# 1. Criar branch
git checkout -b feature/nome-feature

# 2. Fazer alterações
# ... código ...

# 3. Commit e push
bash .claude/skills/git-workflow-complete/scripts/smart_commit.sh

# 4. Criar PR
gh pr create --title "feat(scope): feature name" --body-file .claude/skills/git-workflow-complete/templates/pr_template.md

# 5. Code review
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh <PR_NUMBER>

# 6. Merge
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh <PR_NUMBER> --squash
```

### Quick Code Review
```bash
# Ver PR
bash .claude/skills/git-workflow-complete/scripts/review_pr.sh 123

# Aprovar
gh pr review 123 --approve

# Merge
bash .claude/skills/git-workflow-complete/scripts/merge_pr.sh 123 --squash
```

---

**Part of:** agl-hostman project
**Version:** 1.1.1
**Last Updated:** 2026-04-19

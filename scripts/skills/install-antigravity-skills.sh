#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_REPO="https://github.com/sickn33/antigravity-awesome-skills.git"
TEMP_DIR="/tmp/antigravity-skills-$$"
CURSOR_SKILLS_DIR="$HOME/.cursor/skills"

YELLOW='\033[1;33m'
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

cleanup() {
    if [ -d "$TEMP_DIR" ]; then
        log_info "Limpando diretório temporário..."
        rm -rf "$TEMP_DIR"
    fi
}

trap cleanup EXIT

PRIORITY_SKILLS=(
    "concise-planning"
    "lint-and-validate"
    "git-pushing"
    "systematic-debugging"
    "kaizen"
    "nodejs-backend-patterns"
    "nodejs-best-practices"
    "api-patterns"
    "api-security-best-practices"
    "backend-security-coder"
    "docker-expert"
    "bash-linux"
    "deployment-procedures"
    "observability-engineer"
    "incident-responder"
    "test-driven-development"
    "testing-patterns"
    "javascript-testing-patterns"
    "mcp-builder"
    "ai-agents-architect"
    "agent-memory-systems"
    "prompt-engineering"
    "architecture"
    "architecture-decision-records"
    "clean-code"
    "commit"
    "create-pr"
    "github-workflow-automation"
    "vulnerability-scanner"
    "security-auditor"
)

OPTIONAL_SKILLS=(
    "database-design"
    "database-migration"
    "sql-optimization-patterns"
    "environment-setup-guide"
    "postmortem-writing"
    "auth-implementation-patterns"
    "changelog-automation"
    "git-advanced-workflows"
)

check_dependencies() {
    log_info "Verificando dependências..."
    
    if ! command -v git &> /dev/null; then
        log_error "Git não encontrado. Instale o Git primeiro."
        exit 1
    fi
    
    log_success "Dependências verificadas"
}

clone_repository() {
    log_info "Clonando repositório antigravity-awesome-skills..."
    
    if [ -d "$TEMP_DIR" ]; then
        rm -rf "$TEMP_DIR"
    fi
    
    git clone --depth 1 "$SKILLS_REPO" "$TEMP_DIR" 2>&1 | grep -v "Cloning into" || true
    
    if [ ! -d "$TEMP_DIR/skills" ]; then
        log_error "Falha ao clonar repositório ou estrutura inválida"
        exit 1
    fi
    
    log_success "Repositório clonado com sucesso"
}

create_skills_directory() {
    log_info "Criando diretório de skills..."
    
    if [ ! -d "$CURSOR_SKILLS_DIR" ]; then
        mkdir -p "$CURSOR_SKILLS_DIR"
        log_success "Diretório criado: $CURSOR_SKILLS_DIR"
    else
        log_info "Diretório já existe: $CURSOR_SKILLS_DIR"
    fi
}

install_skill() {
    local skill_name="$1"
    local source_dir="$TEMP_DIR/skills/$skill_name"
    local target_dir="$CURSOR_SKILLS_DIR/$skill_name"
    
    if [ ! -d "$source_dir" ]; then
        log_warning "Skill não encontrada: $skill_name"
        return 1
    fi
    
    if [ -d "$target_dir" ]; then
        log_info "Atualizando skill: $skill_name"
        rm -rf "$target_dir"
    else
        log_info "Instalando skill: $skill_name"
    fi
    
    cp -r "$source_dir" "$target_dir"
    
    if [ -d "$target_dir" ]; then
        log_success "✓ $skill_name"
        return 0
    else
        log_error "✗ $skill_name"
        return 1
    fi
}

install_priority_skills() {
    log_info "Instalando skills prioritárias..."
    echo ""
    
    local installed=0
    local failed=0
    
    for skill in "${PRIORITY_SKILLS[@]}"; do
        if install_skill "$skill"; then
            ((installed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    log_success "Skills prioritárias instaladas: $installed"
    if [ $failed -gt 0 ]; then
        log_warning "Skills não encontradas: $failed"
    fi
}

install_optional_skills() {
    log_info "Instalando skills opcionais..."
    echo ""
    
    local installed=0
    local failed=0
    
    for skill in "${OPTIONAL_SKILLS[@]}"; do
        if install_skill "$skill"; then
            ((installed++))
        else
            ((failed++))
        fi
    done
    
    echo ""
    log_success "Skills opcionais instaladas: $installed"
    if [ $failed -gt 0 ]; then
        log_warning "Skills não encontradas: $failed"
    fi
}

generate_documentation() {
    log_info "Gerando documentação..."
    
    local doc_file="$PROJECT_ROOT/ai-docs/ANTIGRAVITY_SKILLS_INSTALLED.md"
    
    cat > "$doc_file" << 'EOF'
# Skills Antigravity Instaladas - AGL Hostman

> Instalação automatizada das skills do [antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills)

## Localização

- **Diretório**: `~/.cursor/skills`
- **Uso no Cursor**: `@skill-name` no chat

## Skills Instaladas

### Essenciais

| Skill | Uso | Comando |
|-------|-----|---------|
| concise-planning | Planejamento estruturado de tarefas | `@concise-planning` |
| lint-and-validate | Validação e lint automáticos | `@lint-and-validate` |
| git-pushing | Commits convencionais e push seguro | `@git-pushing` |
| systematic-debugging | Debug estruturado e metódico | `@systematic-debugging` |
| kaizen | Melhoria contínua de código | `@kaizen` |

### Backend & API

| Skill | Uso | Comando |
|-------|-----|---------|
| nodejs-backend-patterns | Padrões Node.js/Express | `@nodejs-backend-patterns` |
| nodejs-best-practices | Boas práticas Node.js | `@nodejs-best-practices` |
| api-patterns | Design de APIs REST/GraphQL | `@api-patterns` |
| api-security-best-practices | Segurança de APIs | `@api-security-best-practices` |
| backend-security-coder | Código backend seguro | `@backend-security-coder` |

### DevOps & Infraestrutura

| Skill | Uso | Comando |
|-------|-----|---------|
| docker-expert | Docker e containers | `@docker-expert` |
| bash-linux | Scripts shell e automação | `@bash-linux` |
| deployment-procedures | Estratégias de deploy | `@deployment-procedures` |
| observability-engineer | Monitoramento e métricas | `@observability-engineer` |
| incident-responder | Resposta a incidentes | `@incident-responder` |

### Testes

| Skill | Uso | Comando |
|-------|-----|---------|
| test-driven-development | TDD red-green-refactor | `@test-driven-development` |
| testing-patterns | Jest, mocking, factories | `@testing-patterns` |
| javascript-testing-patterns | Testes JavaScript/Node | `@javascript-testing-patterns` |

### AI & Agentes

| Skill | Uso | Comando |
|-------|-----|---------|
| mcp-builder | Construção de ferramentas MCP | `@mcp-builder` |
| ai-agents-architect | Arquitetura de agentes | `@ai-agents-architect` |
| agent-memory-systems | Sistemas de memória | `@agent-memory-systems` |
| prompt-engineering | Engenharia de prompts | `@prompt-engineering` |

### Arquitetura

| Skill | Uso | Comando |
|-------|-----|---------|
| architecture | Decisões arquiteturais | `@architecture` |
| architecture-decision-records | ADRs | `@architecture-decision-records` |
| clean-code | Código limpo | `@clean-code` |

### GitHub & OSS

| Skill | Uso | Comando |
|-------|-----|---------|
| commit | Conventional commits | `@commit` |
| create-pr | Pull requests estruturados | `@create-pr` |
| github-workflow-automation | GitHub Actions | `@github-workflow-automation` |

### Segurança

| Skill | Uso | Comando |
|-------|-----|---------|
| vulnerability-scanner | Scanner de vulnerabilidades | `@vulnerability-scanner` |
| security-auditor | Auditoria de segurança | `@security-auditor` |

### Opcionais

| Skill | Uso | Comando |
|-------|-----|---------|
| database-design | Design de schemas | `@database-design` |
| database-migration | Migrações seguras | `@database-migration` |
| sql-optimization-patterns | Otimização SQL | `@sql-optimization-patterns` |
| environment-setup-guide | Setup de ambientes | `@environment-setup-guide` |
| postmortem-writing | Postmortems | `@postmortem-writing` |
| auth-implementation-patterns | Autenticação e autorização | `@auth-implementation-patterns` |
| changelog-automation | Changelogs automáticos | `@changelog-automation` |
| git-advanced-workflows | Git avançado | `@git-advanced-workflows` |

## Workflows Recomendados

### 1. Nova Feature
```
@concise-planning → @test-driven-development → @nodejs-backend-patterns → @lint-and-validate → @git-pushing
```

### 2. Bug Fix
```
@systematic-debugging → @testing-patterns → @kaizen → @lint-and-validate → @git-pushing
```

### 3. Deploy
```
@deployment-procedures → @docker-expert → @observability-engineer
```

### 4. Code Review
```
@clean-code → @security-auditor → @architecture
```

### 5. Incident Response
```
@incident-responder → @systematic-debugging → @postmortem-writing
```

## Atualização

Para atualizar as skills:

```bash
cd /r:/apps/dev/agl/agl-hostman
./scripts/skills/install-antigravity-skills.sh
```

## Referências

- [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills)
- [Catálogo Completo](https://github.com/sickn33/antigravity-awesome-skills/blob/main/CATALOG.md)
- [Bundles](https://github.com/sickn33/antigravity-awesome-skills/blob/main/docs/BUNDLES.md)
EOF
    
    log_success "Documentação gerada: $doc_file"
}

show_summary() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_success "Instalação concluída!"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "📍 Localização: $CURSOR_SKILLS_DIR"
    echo "📚 Documentação: $PROJECT_ROOT/ai-docs/ANTIGRAVITY_SKILLS_INSTALLED.md"
    echo ""
    echo "💡 Uso no Cursor:"
    echo "   Digite @skill-name no chat para usar uma skill"
    echo "   Exemplo: @concise-planning para planejar uma tarefa"
    echo ""
    echo "🔄 Para atualizar:"
    echo "   ./scripts/skills/install-antigravity-skills.sh"
    echo ""
}

main() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Instalador de Skills Antigravity - AGL Hostman"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    check_dependencies
    create_skills_directory
    clone_repository
    install_priority_skills
    install_optional_skills
    generate_documentation
    show_summary
}

main "$@"

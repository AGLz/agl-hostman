# Instalador de Skills Antigravity - AGL Hostman
# PowerShell Script para Windows

param(
    [switch]$SkipOptional = $false
)

$ErrorActionPreference = "Stop"

$SKILLS_REPO = "https://github.com/sickn33/antigravity-awesome-skills.git"
$TEMP_DIR = "$env:TEMP\antigravity-skills-$(Get-Random)"
$CURSOR_SKILLS_DIR = "$env:USERPROFILE\.cursor\skills"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $color = switch ($Type) {
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error" { "Red" }
        "Info" { "Cyan" }
        default { "White" }
    }
    
    $prefix = switch ($Type) {
        "Success" { "[✓]" }
        "Warning" { "[!]" }
        "Error" { "[✗]" }
        "Info" { "[i]" }
        default { "   " }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $color
}

$PRIORITY_SKILLS = @(
    "concise-planning",
    "lint-and-validate",
    "git-pushing",
    "systematic-debugging",
    "kaizen",
    "nodejs-backend-patterns",
    "nodejs-best-practices",
    "api-patterns",
    "api-security-best-practices",
    "backend-security-coder",
    "docker-expert",
    "bash-linux",
    "deployment-procedures",
    "observability-engineer",
    "incident-responder",
    "test-driven-development",
    "testing-patterns",
    "javascript-testing-patterns",
    "mcp-builder",
    "ai-agents-architect",
    "agent-memory-systems",
    "prompt-engineering",
    "architecture",
    "architecture-decision-records",
    "clean-code",
    "commit",
    "create-pr",
    "github-workflow-automation",
    "vulnerability-scanner",
    "security-auditor"
)

$OPTIONAL_SKILLS = @(
    "database-design",
    "database-migration",
    "sql-optimization-patterns",
    "environment-setup-guide",
    "postmortem-writing",
    "auth-implementation-patterns",
    "changelog-automation",
    "git-advanced-workflows"
)

function Test-Dependencies {
    Write-ColorOutput "Verificando dependências..." "Info"
    
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-ColorOutput "Git não encontrado. Instale o Git primeiro." "Error"
        exit 1
    }
    
    Write-ColorOutput "Dependências verificadas" "Success"
}

function Initialize-SkillsDirectory {
    Write-ColorOutput "Criando diretório de skills..." "Info"
    
    if (-not (Test-Path $CURSOR_SKILLS_DIR)) {
        New-Item -ItemType Directory -Path $CURSOR_SKILLS_DIR -Force | Out-Null
        Write-ColorOutput "Diretório criado: $CURSOR_SKILLS_DIR" "Success"
    } else {
        Write-ColorOutput "Diretório já existe: $CURSOR_SKILLS_DIR" "Info"
    }
}

function Get-SkillsRepository {
    Write-ColorOutput "Clonando repositório antigravity-awesome-skills..." "Info"
    
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Path $TEMP_DIR -Recurse -Force
    }
    
    git clone --depth 1 $SKILLS_REPO $TEMP_DIR 2>&1 | Out-Null
    
    if (-not (Test-Path "$TEMP_DIR\skills")) {
        Write-ColorOutput "Falha ao clonar repositório ou estrutura inválida" "Error"
        exit 1
    }
    
    Write-ColorOutput "Repositório clonado com sucesso" "Success"
}

function Install-Skill {
    param(
        [string]$SkillName
    )
    
    $sourcePath = Join-Path $TEMP_DIR "skills\$SkillName"
    $targetPath = Join-Path $CURSOR_SKILLS_DIR $SkillName
    
    if (-not (Test-Path $sourcePath)) {
        Write-ColorOutput "Skill não encontrada: $SkillName" "Warning"
        return $false
    }
    
    if (Test-Path $targetPath) {
        Remove-Item -Path $targetPath -Recurse -Force
    }
    
    Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
    
    if (Test-Path $targetPath) {
        Write-ColorOutput "✓ $SkillName" "Success"
        return $true
    } else {
        Write-ColorOutput "✗ $SkillName" "Error"
        return $false
    }
}

function Install-PrioritySkills {
    Write-ColorOutput "Instalando skills prioritárias..." "Info"
    Write-Host ""
    
    $installed = 0
    $failed = 0
    
    foreach ($skill in $PRIORITY_SKILLS) {
        if (Install-Skill -SkillName $skill) {
            $installed++
        } else {
            $failed++
        }
    }
    
    Write-Host ""
    Write-ColorOutput "Skills prioritárias instaladas: $installed" "Success"
    if ($failed -gt 0) {
        Write-ColorOutput "Skills não encontradas: $failed" "Warning"
    }
}

function Install-OptionalSkills {
    if ($SkipOptional) {
        Write-ColorOutput "Pulando skills opcionais..." "Info"
        return
    }
    
    Write-ColorOutput "Instalando skills opcionais..." "Info"
    Write-Host ""
    
    $installed = 0
    $failed = 0
    
    foreach ($skill in $OPTIONAL_SKILLS) {
        if (Install-Skill -SkillName $skill) {
            $installed++
        } else {
            $failed++
        }
    }
    
    Write-Host ""
    Write-ColorOutput "Skills opcionais instaladas: $installed" "Success"
    if ($failed -gt 0) {
        Write-ColorOutput "Skills não encontradas: $failed" "Warning"
    }
}

function New-Documentation {
    Write-ColorOutput "Gerando documentação..." "Info"
    
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $docFile = Join-Path $projectRoot "ai-docs\ANTIGRAVITY_SKILLS_INSTALLED.md"
    
    $docContent = @'
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

```powershell
.\scripts\skills\install-antigravity-skills.ps1
```

## Referências

- [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills)
- [Catálogo Completo](https://github.com/sickn33/antigravity-awesome-skills/blob/main/CATALOG.md)
- [Bundles](https://github.com/sickn33/antigravity-awesome-skills/blob/main/docs/BUNDLES.md)
'@
    
    Set-Content -Path $docFile -Value $docContent -Encoding UTF8
    Write-ColorOutput "Documentação gerada: $docFile" "Success"
}

function Show-Summary {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-ColorOutput "Instalação concluída!" "Success"
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📍 Localização: $CURSOR_SKILLS_DIR" -ForegroundColor White
    Write-Host "📚 Documentação: ai-docs\ANTIGRAVITY_SKILLS_INSTALLED.md" -ForegroundColor White
    Write-Host ""
    Write-Host "💡 Uso no Cursor:" -ForegroundColor Yellow
    Write-Host "   Digite @skill-name no chat para usar uma skill" -ForegroundColor White
    Write-Host "   Exemplo: @concise-planning para planejar uma tarefa" -ForegroundColor White
    Write-Host ""
    Write-Host "🔄 Para atualizar:" -ForegroundColor Yellow
    Write-Host "   .\scripts\skills\install-antigravity-skills.ps1" -ForegroundColor White
    Write-Host ""
}

function Invoke-Cleanup {
    if (Test-Path $TEMP_DIR) {
        Write-ColorOutput "Limpando diretório temporário..." "Info"
        Remove-Item -Path $TEMP_DIR -Recurse -Force -ErrorAction SilentlyContinue
    }
}

try {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host "  Instalador de Skills Antigravity - AGL Hostman" -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host ""
    
    Test-Dependencies
    Initialize-SkillsDirectory
    Get-SkillsRepository
    Install-PrioritySkills
    Install-OptionalSkills
    New-Documentation
    Show-Summary
}
catch {
    Write-ColorOutput "Erro durante a instalação: $_" "Error"
    exit 1
}
finally {
    Invoke-Cleanup
}

# Skills Antigravity - Guia de Integração

Este documento descreve como as skills do antigravity-awesome-skills foram integradas ao projeto AGL Hostman.

## Instalação Realizada

✅ **38 skills instaladas com sucesso**
- 30 skills prioritárias
- 8 skills opcionais

📍 **Localização**: `C:\Users\kakos\.cursor\skills`

## Como Usar no Cursor

### Sintaxe Básica
```
@skill-name sua pergunta ou comando
```

### Exemplos Práticos

#### 1. Planejamento de Tarefas
```
@concise-planning Preciso implementar autenticação JWT no backend
```

#### 2. Desenvolvimento Backend
```
@nodejs-backend-patterns Como estruturar um middleware de autenticação?
@api-patterns Qual a melhor forma de versionar esta API?
```

#### 3. Testes
```
@test-driven-development Vou criar testes para o módulo de usuários
@testing-patterns Como mockar chamadas ao banco de dados?
```

#### 4. DevOps
```
@docker-expert Otimizar este Dockerfile para produção
@deployment-procedures Estratégia de deploy zero-downtime
```

#### 5. Debug
```
@systematic-debugging Erro intermitente no container Docker
@observability-engineer Configurar métricas para este serviço
```

#### 6. Git & Commits
```
@git-pushing Revisar e commitar estas mudanças
@commit Gerar mensagem de commit convencional
```

## Workflows Recomendados

### Nova Feature
```mermaid
graph LR
    A[@concise-planning] --> B[@test-driven-development]
    B --> C[@nodejs-backend-patterns]
    C --> D[@lint-and-validate]
    D --> E[@git-pushing]
```

**Comandos:**
1. `@concise-planning Implementar endpoint de login`
2. `@test-driven-development Criar testes para autenticação`
3. `@nodejs-backend-patterns Implementar middleware JWT`
4. `@lint-and-validate Validar código antes do commit`
5. `@git-pushing Commitar e fazer push`

### Bug Fix
```mermaid
graph LR
    A[@systematic-debugging] --> B[@testing-patterns]
    B --> C[@kaizen]
    C --> D[@git-pushing]
```

**Comandos:**
1. `@systematic-debugging Analisar erro no login`
2. `@testing-patterns Criar teste de regressão`
3. `@kaizen Melhorar tratamento de erros`
4. `@git-pushing Commitar correção`

### Deploy
```mermaid
graph LR
    A[@deployment-procedures] --> B[@docker-expert]
    B --> C[@observability-engineer]
```

**Comandos:**
1. `@deployment-procedures Planejar deploy em produção`
2. `@docker-expert Otimizar imagens Docker`
3. `@observability-engineer Configurar monitoramento`

### Code Review
```mermaid
graph LR
    A[@clean-code] --> B[@security-auditor]
    B --> C[@architecture]
```

**Comandos:**
1. `@clean-code Revisar qualidade do código`
2. `@security-auditor Verificar vulnerabilidades`
3. `@architecture Validar decisões arquiteturais`

## Skills por Categoria

### 🎯 Essenciais (Uso Diário)
- `@concise-planning` - Planejamento estruturado
- `@lint-and-validate` - Validação automática
- `@git-pushing` - Commits seguros
- `@systematic-debugging` - Debug metódico
- `@kaizen` - Melhoria contínua

### 🔧 Backend & API
- `@nodejs-backend-patterns` - Padrões Node.js/Express
- `@nodejs-best-practices` - Boas práticas Node.js
- `@api-patterns` - Design de APIs
- `@api-security-best-practices` - Segurança de APIs
- `@backend-security-coder` - Código seguro

### 🐳 DevOps & Infraestrutura
- `@docker-expert` - Docker e containers
- `@bash-linux` - Scripts shell
- `@deployment-procedures` - Estratégias de deploy
- `@observability-engineer` - Monitoramento
- `@incident-responder` - Resposta a incidentes

### 🧪 Testes
- `@test-driven-development` - TDD
- `@testing-patterns` - Jest e mocking
- `@javascript-testing-patterns` - Testes JS/Node

### 🤖 AI & Agentes
- `@mcp-builder` - Ferramentas MCP
- `@ai-agents-architect` - Arquitetura de agentes
- `@agent-memory-systems` - Sistemas de memória
- `@prompt-engineering` - Engenharia de prompts

### 🏗️ Arquitetura
- `@architecture` - Decisões arquiteturais
- `@architecture-decision-records` - ADRs
- `@clean-code` - Código limpo

### 🔐 Segurança
- `@vulnerability-scanner` - Scanner de vulnerabilidades
- `@security-auditor` - Auditoria de segurança

### 💾 Banco de Dados
- `@database-design` - Design de schemas
- `@database-migration` - Migrações seguras
- `@sql-optimization-patterns` - Otimização SQL

### 🔄 Git & OSS
- `@commit` - Conventional commits
- `@create-pr` - Pull requests
- `@github-workflow-automation` - GitHub Actions
- `@git-advanced-workflows` - Git avançado
- `@changelog-automation` - Changelogs

### 🛠️ Utilitários
- `@environment-setup-guide` - Setup de ambientes
- `@postmortem-writing` - Postmortems
- `@auth-implementation-patterns` - Autenticação

## Integração com o Projeto

### Estrutura de Diretórios
```
agl-hostman/
├── scripts/
│   └── skills/
│       ├── install-antigravity-skills.ps1  # Instalador Windows
│       └── install-antigravity-skills.sh   # Instalador Linux/Mac
├── ai-docs/
│   ├── ANTIGRAVITY_SKILLS_INSTALLED.md     # Este arquivo
│   └── ANTIGRAVITY_SKILLS_RECOMMENDED.md   # Recomendações originais
└── ~/.cursor/skills/                        # Skills instaladas
```

### Atualização das Skills

**Windows (PowerShell):**
```powershell
.\scripts\skills\install-antigravity-skills.ps1
```

**Linux/Mac (Bash):**
```bash
./scripts/skills/install-antigravity-skills.sh
```

### Verificação da Instalação

No Cursor, digite `@` no chat e verifique se as skills aparecem na lista de sugestões.

## Casos de Uso Específicos do Projeto

### 1. Desenvolvimento de API REST
```
@concise-planning Criar endpoint para gerenciar hosts Proxmox
@api-patterns Definir estrutura de resposta da API
@nodejs-backend-patterns Implementar controller e service
@test-driven-development Criar testes unitários
@api-security-best-practices Adicionar autenticação JWT
@lint-and-validate Validar código
@git-pushing Commitar mudanças
```

### 2. Configuração de Container Docker
```
@docker-expert Otimizar Dockerfile do backend
@deployment-procedures Configurar health checks
@observability-engineer Adicionar métricas Prometheus
```

### 3. Implementação de Agente AI
```
@ai-agents-architect Projetar arquitetura do agente
@mcp-builder Criar ferramentas MCP customizadas
@agent-memory-systems Implementar memória persistente
@prompt-engineering Otimizar prompts do agente
```

### 4. Troubleshooting em Produção
```
@incident-responder Analisar falha no serviço
@systematic-debugging Investigar logs e métricas
@observability-engineer Melhorar observabilidade
@postmortem-writing Documentar incidente
```

### 5. Refatoração de Código Legacy
```
@clean-code Identificar code smells
@architecture Propor melhorias arquiteturais
@kaizen Implementar melhorias incrementais
@testing-patterns Adicionar cobertura de testes
```

## Dicas de Uso

### ✅ Boas Práticas

1. **Combine skills em sequência**
   ```
   @concise-planning → @test-driven-development → @git-pushing
   ```

2. **Use skills específicas para contextos específicos**
   - Backend: `@nodejs-backend-patterns`
   - Frontend: `@tailwind-patterns`
   - DevOps: `@docker-expert`

3. **Sempre valide antes de commitar**
   ```
   @lint-and-validate antes de @git-pushing
   ```

4. **Documente decisões importantes**
   ```
   @architecture-decision-records para ADRs
   ```

### ❌ Evite

1. Usar skills genéricas quando existem específicas
2. Pular validação antes de commits
3. Não documentar decisões arquiteturais
4. Ignorar sugestões de segurança

## Troubleshooting

### Skills não aparecem no Cursor

1. Verifique se o diretório existe:
   ```powershell
   Test-Path "$env:USERPROFILE\.cursor\skills"
   ```

2. Reinstale as skills:
   ```powershell
   .\scripts\skills\install-antigravity-skills.ps1
   ```

3. Reinicie o Cursor

### Skill não funciona como esperado

1. Verifique a documentação da skill:
   ```powershell
   Get-Content "$env:USERPROFILE\.cursor\skills\<skill-name>\README.md"
   ```

2. Tente reformular a pergunta
3. Combine com outras skills

## Recursos Adicionais

- [Antigravity Awesome Skills](https://github.com/sickn33/antigravity-awesome-skills)
- [Catálogo Completo](https://github.com/sickn33/antigravity-awesome-skills/blob/main/CATALOG.md)
- [Bundles](https://github.com/sickn33/antigravity-awesome-skills/blob/main/docs/BUNDLES.md)
- [Documentação do Cursor](https://cursor.sh/docs)

## Contribuindo

Para adicionar novas skills ao projeto:

1. Identifique a necessidade
2. Verifique se existe no catálogo
3. Adicione ao array correspondente no script de instalação
4. Execute o script de atualização
5. Documente o uso neste arquivo

## Changelog

### 2025-02-08
- ✅ Instalação inicial de 38 skills
- ✅ Criação de scripts de instalação (PowerShell e Bash)
- ✅ Documentação de integração e uso
- ✅ Workflows recomendados para o projeto

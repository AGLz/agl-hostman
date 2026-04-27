# MCP CLI - Melhores Práticas e Otimização de Tokens

**Data**: 2026-02-14 | **Versão**: 1.0.0 | **Fonte**: Pesquisa Web 2026

## 📋 Resumo Executivo

Este documento compila as melhores práticas de Model Context Protocol (MCP) para implementação de CLI e otimização de uso de tokens, baseado em pesquisa atualizada com especialistas da Anthropic, The New Stack e comunidade MCP.

**Principais Descobertas**:
- Redução de **98.7%** no uso de tokens com code execution
- **50-60%** de redução com subagentes especializados
- **30-60%** de economia com schema minimization
- Progressive disclosure e semantic caching como estratégias-chave

---

## 🎯 10 Estratégias para Reduzir Token Bloat

### 1. Design Tools with Intent (Ferramentas com Propósito)

**Problema**: Wrappers 1:1 de APIs existentes
```typescript
// ❌ RUIM - Wrapper genérico
mcpTools.push(wrapApiEndpoint(githubApi.getRepo))
mcpTools.push(wrapApiEndpoint(githubApi.getIssues))
mcpTools.push(wrapApiEndpoint(githubApi.createPR))

// ✅ BOM - Ferramenta intencional
mcpTools.push({
  name: "github_contribute_to_repo",
  description: "Comprehensive tool for repository contributions: finds issues, creates branches, submits PRs",
  parameters: {
    repo: "string (required)",
    contributionType: "enum: [bugfix, feature, refactor, docs]"
  }
})
```

**Benefícios**:
- 40-50% menos metadata de ferramentas
- Maior precisão na seleção de tools
- Melhor UX para agentes

### 2. Minimize Upfront Context (Contexto Inicial Mínimo)

**Estratégia**: Carregar schemas mínimas primeiro
```typescript
// ❌ RUIM - Carrega tudo upfront
await mcpClient.loadAllTools() // 150,000 tokens

// ✅ BOM - Carrega sob demanda
const toolRegistry = await mcpClient.loadMinimalRegistry()
// Apenas nomes e descrições breves: ~2,000 tokens

// Expande quando necessário
const fullSchema = await toolRegistry.getFullTool('github_search_issues')
```

**Implementação**:
```typescript
interface MinimalTool {
  name: string
  shortDescription: string  // 1-2 sentences
  category: string
}

interface FullTool extends MinimalTool {
  parameters: JSONSchema
  examples: Example[]
  errorHandling: ErrorSpec
}
```

**Redução**: 30-60% de tokens

### 3. Progressive Disclosure (Revelação Progressiva)

**Conceito**: Expor apenas ferramentas relevantes
```typescript
// Meta-tool para descoberta
interface ToolRouter {
  findTools(query: string): Promise<Tool[]>
}

// Uso
const githubTools = await router.findTools("github repository management")
// Retorna apenas tools relevantes, não todas as 500+ ferramentas
```

**Hierarquia de Ferramentas**:
```
mcp_router (meta-tool)
├── infrastructure/
│   ├── docker_containers
│   ├── kubernetes_pods
│   └── wireguard_peers
├── development/
│   ├── code_execution
│   ├── testing_framework
│   └── documentation
└── monitoring/
    ├── metrics_collection
    ├── log_analysis
    └── alerting
```

**Recomendação**: 10-15 ferramentas por vez

### 4. Automated Tool Discovery (Descoberta Automatizada)

**MCP Registry Pattern**:
```typescript
interface MCPRegistry {
  // Descoberta semântica
  searchTools(query: string, filters: ToolFilter): Promise<Tool[]>

  // Descoberta por categoria
  listToolsByCategory(category: string): Promise<Tool[]>

  // Descoberta por capacidade
  findToolsWithCapability(capability: string): Promise<Tool[]>
}

// Exemplo de uso
const monitoringTools = await registry.searchTools("container metrics", {
  authType: "none",
  maxLatency: 100,
  tokenCost: "low"
})
```

**Semantic Routing**:
```typescript
// Roteamento semântico - Carrega apenas 3 tools relevantes
const relevantTools = await semanticRouter.route(
  "restart container ct179",
  toolDatabase  // 500+ tools
)
// Retorna apenas: docker.restart, lxc.restart, container.healthCheck
```

### 5. Use Subagents (Subagentes Especializados)

**Arquitetura**:
```
Main Agent
├── Infrastructure Subagent (wireguard, docker, proxmox tools)
├── Development Subagent (code, testing, docs tools)
├── Monitoring Subagent (metrics, logs, alerts tools)
└── Documentation Subagent (search, create, update tools)
```

**Implementação**:
```typescript
interface Subagent {
  name: string
  domain: string
  tools: string[]  // Apenas tools do domínio
}

class InfrastructureSubagent implements Subagent {
  name = "infrastructure"
  domain = "infrastructure_management"
  tools = [
    "wireguard_status",
    "docker_container_info",
    "proxmox_vm_list"
  ]
  // Token overhead cai 50-60%
}
```

**Benefícios**:
- 50-60% redução de token overhead
- Sem confusão sobre roles
- Escalabilidade horizontal

### 6. Code-Based Execution (Execução Baseada em Código)

**Conceito**: LLM escreve código, não orquestra tool calls
```typescript
// ❌ RUIM - LLM orquestra tudo
TOOL_CALL: gdrive.getDocument("abc123")
  → returns 50,000 tokens (transcrição)
TOOL_CALL: salesforce.updateRecord({...data: transcript})
  → LLM precisa escrever 50k tokens novamente

// ✅ BOM - LLM escreve código
// Código gerado pelo LLM:
const transcript = await gdrive.getDocument({documentId: "abc123"})
await salesforce.updateRecord({
  objectType: "SalesMeeting",
  recordId: "00Q5f000001abcXYZ",
  data: {Notes: transcript}
})
// Código executa fora do contexto do LLM
```

**Filesystem API Pattern**:
```typescript
// Estrutura de arquivos
servers/
├── google-drive/
│   ├── getDocument.ts
│   ├── createDocument.ts
│   └── index.ts
├── salesforce/
│   ├── updateRecord.ts
│   ├── queryRecords.ts
│   └── index.ts
└── ...

// Cada tool é um arquivo TypeScript
export async function getDocument(input: GetDocumentInput): Promise<GetDocumentResponse> {
  return callMCPTool<GetDocumentResponse>('google_drive__get_document', input)
}
```

**Redução**: 98.7% (150k → 2k tokens)

### 7. Semantic Caching (Cache Semântico)

**Implementação**:
```typescript
interface SemanticCache {
  // Cache de descobertas de ferramentas
  getCachedTools(query: string): Promise<Tool[] | null>

  // Cache de respostas de ferramentas
  getCachedResponse(toolCall: ToolCall): Promise<Response | null>

  // Invalidação inteligente
  invalidate(pattern: string): Promise<void>
}

// Uso
let tools = await cache.getCachedTools("github repository tools")
if (!tools) {
  tools = await registry.searchTools("github repository")
  await cache.storeTools("github repository tools", tools)
}
```

### 8. Prompt Engineering

**Boas Práticas**:
```typescript
// ❌ RUIM - Descrição vaga
{
  name: "search",
  description: "Searches stuff"
}

// ✅ BOM - Descrição clara e específica
{
  name: "search_github_issues",
  description: "Searches GitHub issues with filters. Returns concise results by default.",
  parameters: {
    query: {
      type: "string",
      description: "Search query (supports GitHub search syntax)",
      required: true
    },
    responseFormat: {
      type: "enum",
      enum: ["concise", "detailed"],
      description: "Concise: title+status (72 tokens). Detailed: full metadata (206 tokens)",
      default: "concise"
    }
  }
}
```

### 9. Data Hygiene (Higiene de Dados)

**Princípios**:
```typescript
// ❌ RUIM - Retorna tudo
async function getAllLogs() {
  return await db.query("SELECT * FROM logs")  // 10,000 rows
}

// ✅ BOM - Busca incremental
async function searchLogs(query: LogQuery) {
  // Primeiro: resumido
  const summary = await db.query(`
    SELECT COUNT(*), MIN(timestamp), MAX(timestamp)
    FROM logs
    WHERE ${query.where}
  `)

  // Segundo: dados específicos se necessário
  if (query.needDetails) {
    return await db.query(`
      SELECT timestamp, level, message
      FROM logs
      WHERE ${query.where}
      LIMIT 100
    `)
  }

  return summary
}
```

### 10. Externalize Control (Externalizar Controle)

**Runtime Layer Pattern**:
```typescript
// Runtime centraliza lógica de autenticação, rate limiting, etc.
class MCPRuntimeLayer {
  async callTool(toolName: string, params: any) {
    // Autenticação
    await this.authenticate(toolName)

    // Rate limiting
    await this.checkRateLimit(toolName)

    // Error handling
    try {
      return await this.mcpClient.callTool(toolName, params)
    } catch (error) {
      return await this.handleError(error, toolName, params)
    }
  }
}
```

---

## 🏗️ Implementação de Ferramentas Eficientes

### Naming (Nomeação)

```typescript
// ✅ BOM - Namespace claro
{
  name: "github_repository_search_issues",
  category: "github/repository",
  subcategory: "search"
}

// Hierarquia
github_repository_search
github_repository_create
github_repository_update

github_issues_search
github_issues_create
github_issues_close
```

### Response Format (Formato de Resposta)

```typescript
interface ToolResponse {
  // Modo conciso: 72 tokens
  concise: {
    title: string
    content: string
    summary: string
  }

  // Modo detalhado: 206 tokens
  detailed: {
    title: string
    content: string
    metadata: {...}
    ids: {...}
  }
}

// Uso
{
  name: "get_slack_messages",
  responseFormat: {
    type: "enum",
    enum: ["concise", "detailed"],
    default: "concise",
    description: "Concise: messages only. Detailed: includes thread_ts for replies."
  }
}
```

### Error Handling (Tratamento de Erros)

```typescript
// ❌ RUIM
throw new Error("Invalid input")

// ✅ BOM
{
  error: {
    message: "Invalid repository name format",
    example: "Use 'owner/repo' format (e.g., 'anthropics/claude-code')",
    documentation: "https://docs.github.com/repos"
  }
}
```

---

## 🔄 Workflow de Desenvolvimento

### 1. Prototipagem Rápida
```bash
# Criar servidor MCP local
npm init mcp-server-mytools
cd mcp-server-mytools

# Conectar ao Claude Code
claude mcp add mytools-local "npx mcp-server-mytools"

# Testar ferramentas
claude mcp list
claude mcp test mytools-local
```

### 2. Avaliação Sistemática
```typescript
// Gerar tarefas de avaliação
const evaluationTasks = [
  {
    prompt: "Schedule a meeting with Jane next week to discuss Q4 goals",
    expectedOutcome: "Meeting created with attachments from last planning"
  },
  {
    prompt: "Find all customers affected by issue #9182",
    expectedOutcome: "List of affected customers with full details"
  }
]

// Rodar avaliação
for (const task of evaluationTasks) {
  const result = await agent.execute(task.prompt)
  const verification = await verifier.verify(result, task.expectedOutcome)
  console.log(`${task.prompt}: ${verification.score}`)
}
```

### 3. Análise de Resultados
```typescript
// Onde o agente se confunde
const confusionPoints = await analysis.findConfusionPoints(transcripts)

// O que o agente omite (mais importante que o que inclui)
const omissions = await analysis.findOmissions(transcripts)

// Feedback dos agentes
const feedback = await analysis.analyzeFeedback(transcripts)
```

---

## 📊 Métricas de Performance

### Métricas-Chave

| Métrica | Antes | Depois | Melhoria |
|----------|-------|--------|----------|
| Tokens de tool definitions | 150,000 | 2,000 | 98.7% |
| Tokens de respostas de tools | 50,000 | 5,000 | 90% |
| Latência média | 2.5s | 0.8s | 68% |
| Precisão de seleção de tools | 72% | 94% | 31% |

### Benchmarks

**Case Study: Slack Tools**
- Before: 45% success rate
- After: 89% success rate
- Improvement: 98%

**Case Study: Asana Tools**
- Before: 38% success rate
- After: 92% success rate
- Improvement: 142%

---

## 🚀 Implementação no AGL Hostman

### Estrutura de Diretórios

```bash
agl-hostman/
├── mcp-servers/              # Servidores MCP customizados
│   ├── infrastructure/          # Tools de infraestrutura
│   │   ├── docker/
│   │   ├── proxmox/
│   │   └── wireguard/
│   ├── development/              # Tools de desenvolvimento
│   │   ├── testing/
│   │   ├── documentation/
│   │   └── code-execution/
│   └── monitoring/               # Tools de monitoramento
│       ├── metrics/
│       ├── logs/
│       └── alerts/
├── mcp-runtime/                # Runtime layer
│   ├── authentication/
│   ├── rate-limiting/
│   ├── error-handling/
│   └── caching/
└── mcp-registry/               # Registry de ferramentas
    ├── tool-index.json
    ├── semantic-index/
    └── categories/
```

### Próximos Passos

1. ✅ Criar documento de melhores práticas
2. ⏳ Implementar runtime layer
3. ⏳ Criar MCP server de infraestrutura
4. ⏳ Implementar semantic caching
5. ⏳ Configurar subagentes
6. ⏳ Criar sistema de avaliação
7. ⏳ Documentar ferramentas existentes
8. ⏳ Otimizar tool descriptions

---

## 📚 Referências

- [MCP Best Practices - Official Guide](https://modelcontextprotocol.info/docs/best-practices/)
- [10 Strategies to Reduce MCP Token Bloat - The New Stack](https://thenewstack.io/how-to-reduce-mcp-token-bloat/)
- [Code Execution with MCP - Anthropic Engineering](https://www.anthropic.com/engineering/code-execution-with-mcp)
- [Writing Effective Tools for Agents - MCP Tutorial](https://modelcontextprotocol.info/docs/tutorials/writing-effective-tools/)

---

**Versão**: 1.0.0
**Autor**: Claude Code (agl-hostman)
**Data**: 2026-02-14

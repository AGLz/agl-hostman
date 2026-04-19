# Claude Flow — Exemplo Completo: Hive Mind, Múltiplos Agentes, Hooks e Route

> **Objetivo**: Mostrar um fluxo end-to-end com spawn de agentes, hooks e roteamento.

---

## 1. Visão geral do fluxo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Usuário envia prompt: "Implemente API REST e escreva testes"               │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HOOK UserPromptSubmit → node .claude/helpers/hook-handler.cjs route       │
│  - intelligence.getContext(prompt)  → contexto PageRank                     │
│  - router.routeTask(prompt)         → agent recomendado (backend-dev, tester)│
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  ROUTE (3-tier / SONA) — via Ruflo CLI:                                     │
│  npx ruflo@latest hooks intel route "Implemente API REST" --top-k 3         │
│  → Agent: backend-dev | Confidence: 96% | Latency: 0.34ms                   │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  HIVE MIND SPAWN — múltiplos agentes em paralelo:                           │
│  npx ruflo hive-mind spawn "Build API + Tests" --queen-type tactical        │
│  ou via HiveMindWorkerPool.spawnAgentsParallel([...])                       │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  LiteLLM (localhost:4000) → modelos (glm, claude-sonnet, etc.)             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Hooks configurados (.claude/settings.json)

```json
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "node .claude/helpers/hook-handler.cjs route",
            "timeout": 10000
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [{ "type": "command", "command": "node .claude/helpers/hook-handler.cjs pre-bash" }]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [{ "type": "command", "command": "node .claude/helpers/hook-handler.cjs post-edit" }]
      }
    ],
    "SessionStart": [
      { "type": "command", "command": "node .claude/helpers/hook-handler.cjs session-restore" },
      { "type": "command", "command": "node .claude/helpers/auto-memory-hook.mjs import" }
    ],
    "SessionEnd": [
      { "type": "command", "command": "node .claude/helpers/hook-handler.cjs session-end" }
    ],
    "SubagentStart": [
      { "type": "command", "command": "node .claude/helpers/hook-handler.cjs status" }
    ]
  }
}
```

**Ordem de execução:**
- `SessionStart` → session-restore + auto-memory import
- `UserPromptSubmit` → **route** (intelligence + router)
- `PreToolUse` (Bash) → pre-bash (validação de comandos)
- `PostToolUse` (Write/Edit) → post-edit (registra edição)
- `SubagentStart` → status (quando subagente inicia)
- `SessionEnd` → session-end (consolida intelligence)

---

## 3. Route — roteamento por tipo de tarefa

### 3.1 Via hook (router.js local)

```bash
# Simula o que o hook faz
node .claude/helpers/router.js "Implemente API REST com Fastify"
# {"agent":"backend-dev","confidence":0.8,"reason":"Matched pattern: api|endpoint|server|backend|database"}
```

### 3.2 Via Ruflo (SONA 3-tier)

```bash
# Roteamento semântico — escolhe modelo/agente ideal antes de chamar LiteLLM
npx ruflo@latest hooks intel route "Implemente API REST com Fastify" --top-k 3
npx ruflo@latest hooks intel route "Otimize queries do banco" --top-k 3
npx ruflo@latest hooks intel route "Escreva testes unitários" --top-k 3
```

**Exemplo de saída:**
```
Agent: backend-dev | Confidence: 96.2% | Latency: 0.34ms
Alternative Agents:
  | coder      | 85.0% | Code generation specialist
  | architect  | 72.0% | System design
```

---

## 4. Hive Mind spawn — múltiplos agentes

### 4.1 Via Ruflo CLI

```bash
# Inicializar
npx ruflo hive-mind init

# Spawn com queen tática (coordena workers)
npx ruflo hive-mind spawn "Build API REST completa" --queen-type tactical

# Spawn com consenso byzantine (máxima tolerância a falhas)
npx ruflo hive-mind spawn "Pesquisa sobre IA" --consensus byzantine --claude

# Status
npx ruflo hive-mind status
```

### 4.2 Via HiveMindWorkerPool (código)

```javascript
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');
const path = require('path');

const pool = new HiveMindWorkerPool({
  maxWorkers: 4,
  hiveMindDbPath: path.join(process.env.HOME, '.hive-mind/hive.db'),
  enableMetrics: true
});

// Spawn de 4 agentes em paralelo
const agentConfigs = [
  { type: 'researcher', name: 'Research-1', complexity: 1 },
  { type: 'coder', name: 'Dev-1', complexity: 2 },
  { type: 'tester', name: 'Tester-1', complexity: 1 },
  { type: 'reviewer', name: 'Reviewer-1', complexity: 1 }
];

const agents = await pool.spawnAgentsParallel(agentConfigs, 'swarm-api-build');
// ✅ Spawned 4 agents in 120ms (parallel)
```

### 4.3 Swarm com agentes

```javascript
const swarm = await pool.createSwarmWithAgents('API-Swarm', {
  objective: 'Build REST API + tests',
  queenType: 'tactical',
  agentCount: 6
});
// swarm.swarmId, swarm.agents (researcher, coder, tester, architect, ...)
```

---

## 5. Exemplo completo — script de orquestração

```javascript
#!/usr/bin/env node
/**
 * Exemplo: Route → Hive Mind spawn → múltiplos agentes
 * Uso: node scripts/exemplo-claude-flow-completo.js "Implemente API e testes"
 */

const { HiveMindWorkerPool } = require('../src/hive-mind-integration');
const { routeTask } = require('../.claude/helpers/router');
const path = require('path');

async function main() {
  const prompt = process.argv[2] || 'Implemente API REST e escreva testes';

  // 1. Route — qual agente para esta tarefa?
  const route = routeTask(prompt);
  console.log(`[ROUTE] ${route.agent} (${(route.confidence * 100).toFixed(0)}%) — ${route.reason}`);

  // 2. Mapear para configs de agentes (ex.: backend-dev + tester)
  const agentTypes = route.agent === 'backend-dev'
    ? ['backend-dev', 'tester', 'reviewer']
    : [route.agent, 'coder', 'reviewer'];

  const agentConfigs = agentTypes.map((type, i) => ({
    type,
    name: `${type}-${i + 1}`,
    complexity: type === 'tester' ? 1 : 2
  }));

  // 3. Hive Mind spawn
  const pool = new HiveMindWorkerPool({
    maxWorkers: 4,
    hiveMindDbPath: path.join(process.env.HOME, '.hive-mind/hive.db')
  });

  const agents = await pool.spawnAgentsParallel(agentConfigs, 'orchestration-demo');
  console.log(`[SPAWN] ${agents.length} agentes:`, agents.map(a => a.result.agentId).join(', '));

  await pool.terminate();
}

main().catch(console.error);
```

---

## 6. Fluxo resumido

| Etapa | Ferramenta | Comando / Código |
|-------|------------|------------------|
| **1. Prompt** | Claude Code | Usuário digita no chat |
| **2. Route (hook)** | hook-handler.cjs | `UserPromptSubmit` → `route` |
| **3. Intelligence** | intelligence.cjs | `getContext(prompt)` — PageRank |
| **4. Router** | router.js | `routeTask(prompt)` — keyword match |
| **5. SONA (opcional)** | Ruflo CLI | `npx ruflo hooks intel route "task" --top-k 3` |
| **6. Hive Mind spawn** | Ruflo / HiveMindWorkerPool | `hive-mind spawn` ou `spawnAgentsParallel()` |
| **7. LiteLLM** | Gateway | `localhost:4000` → modelos (glm, claude, etc.) |

---

## 7. Executar o exemplo

```bash
# Route + spawn (spawn real requer hive.db; caso contrário mostra config)
node scripts/exemplo-claude-flow-completo.js "Implemente API REST e escreva testes"
```

**Nota:** O spawn via `HiveMindWorkerPool` depende da stack hive-mind estar configurada. Para spawn real, use `npx ruflo hive-mind spawn "tarefa"`.

## 8. Referências

- **Ruflo Advanced**: `docs/RUFLO-ADVANCED.md`
- **Claude Flow + LiteLLM**: `docs/CLAUDE-FLOW-LITELLM.md`
- **Hive Mind setup**: `./scripts/ruflo/setup-hive-mind.sh`
- **Teste Hive Mind**: `node tests/hive-mind/test-hive-mind-integration.js`

---
name: "Swarm Orchestration"
description: "Orchestrate multi-agent swarms with agentic-flow for parallel task execution, dynamic topology selection (mesh, hierarchical, adaptive), intelligent coordination with automatic task distribution, load balancing across agents, and fault tolerance with automatic recovery. Use this skill when initializing swarms with `npx agentic-flow hooks swarm-init --topology mesh --max-agents 5` for distributed coordination, spawning specialized agents with `npx agentic-flow hooks agent-spawn --type coder|tester|reviewer` creating role-specific agents, orchestrating tasks with `npx agentic-flow hooks task-orchestrate --task "Build REST API with tests" --mode parallel` for concurrent execution, implementing mesh topology with `await swarm.init({ topology: 'mesh', agents: ['coder', 'tester', 'reviewer'], communication: 'broadcast' })` for peer-to-peer equal collaboration and distributed decision-making, using hierarchical topology with `await swarm.init({ topology: 'hierarchical', queen: 'coordinator', workers: ['coder', 'tester'] })` for centralized coordination with specialized workers, applying adaptive topology that dynamically switches between patterns based on task complexity, team size, or performance metrics, implementing automatic task distribution analyzing task requirements and agent capabilities to assign optimal agents, balancing load across agents monitoring workload and redistributing tasks to prevent bottlenecks, ensuring fault tolerance with agent health monitoring, automatic replacement of failed agents, and task reassignment, coordinating parallel execution where multiple agents work simultaneously on independent tasks with 2.8-4.4x speed improvements, managing sequential workflows where task dependencies require ordered execution with automatic dependency resolution, implementing hybrid workflows mixing parallel and sequential execution based on task relationships, scaling swarms dynamically from 2 to dozens of agents based on workload complexity, coordinating communication patterns including broadcast (all agents), unicast (specific agent), or multicast (agent groups), managing swarm lifecycle with initialization, agent spawning, task orchestration, monitoring, and graceful shutdown, tracking swarm metrics including agent utilization, task completion rates, average latency, and bottleneck identification, implementing distributed decision-making where agents vote or reach consensus on approaches, using shared memory for cross-agent knowledge coordination via `mcp__claude-flow__memory_usage`, implementing work-stealing where idle agents take tasks from busy agents' queues, or troubleshooting coordination failures, load imbalances, communication bottlenecks, agent crashes, or task deadlocks. Essential for scaling AI systems beyond single-agent limitations, implementing complex multi-step workflows requiring parallel execution, building robust distributed systems with fault tolerance and automatic recovery, optimizing resource utilization through intelligent load balancing, coordinating heterogeneous agents with different specializations, achieving 2.8-4.4x performance improvements through parallelization, and managing production AI systems requiring high availability and scalability."
---

# Swarm Orchestration

## What This Skill Does

Orchestrates multi-agent swarms using agentic-flow's advanced coordination system. Supports mesh, hierarchical, and adaptive topologies with automatic task distribution, load balancing, and fault tolerance.

## Prerequisites

- agentic-flow v1.5.11+
- Node.js 18+
- Understanding of distributed systems (helpful)

## Quick Start

```bash
# Initialize swarm
npx agentic-flow hooks swarm-init --topology mesh --max-agents 5

# Spawn agents
npx agentic-flow hooks agent-spawn --type coder
npx agentic-flow hooks agent-spawn --type tester
npx agentic-flow hooks agent-spawn --type reviewer

# Orchestrate task
npx agentic-flow hooks task-orchestrate \
  --task "Build REST API with tests" \
  --mode parallel
```

## Topology Patterns

### 1. Mesh (Peer-to-Peer)
```typescript
// Equal peers, distributed decision-making
await swarm.init({
  topology: 'mesh',
  agents: ['coder', 'tester', 'reviewer'],
  communication: 'broadcast'
});
```

### 2. Hierarchical (Queen-Worker)
```typescript
// Centralized coordination, specialized workers
await swarm.init({
  topology: 'hierarchical',
  queen: 'architect',
  workers: ['backend-dev', 'frontend-dev', 'db-designer']
});
```

### 3. Adaptive (Dynamic)
```typescript
// Automatically switches topology based on task
await swarm.init({
  topology: 'adaptive',
  optimization: 'task-complexity'
});
```

## Task Orchestration

### Parallel Execution
```typescript
// Execute tasks concurrently
const results = await swarm.execute({
  tasks: [
    { agent: 'coder', task: 'Implement API endpoints' },
    { agent: 'frontend', task: 'Build UI components' },
    { agent: 'tester', task: 'Write test suite' }
  ],
  mode: 'parallel',
  timeout: 300000 // 5 minutes
});
```

### Pipeline Execution
```typescript
// Sequential pipeline with dependencies
await swarm.pipeline([
  { stage: 'design', agent: 'architect' },
  { stage: 'implement', agent: 'coder', after: 'design' },
  { stage: 'test', agent: 'tester', after: 'implement' },
  { stage: 'review', agent: 'reviewer', after: 'test' }
]);
```

### Adaptive Execution
```typescript
// Let swarm decide execution strategy
await swarm.autoOrchestrate({
  goal: 'Build production-ready API',
  constraints: {
    maxTime: 3600,
    maxAgents: 8,
    quality: 'high'
  }
});
```

## Memory Coordination

```typescript
// Share state across swarm
await swarm.memory.store('api-schema', {
  endpoints: [...],
  models: [...]
});

// Agents read shared memory
const schema = await swarm.memory.retrieve('api-schema');
```

## Advanced Features

### Load Balancing
```typescript
// Automatic work distribution
await swarm.enableLoadBalancing({
  strategy: 'dynamic',
  metrics: ['cpu', 'memory', 'task-queue']
});
```

### Fault Tolerance
```typescript
// Handle agent failures
await swarm.setResiliency({
  retry: { maxAttempts: 3, backoff: 'exponential' },
  fallback: 'reassign-task'
});
```

### Performance Monitoring
```typescript
// Track swarm metrics
const metrics = await swarm.getMetrics();
// { throughput, latency, success_rate, agent_utilization }
```

## Integration with Hooks

```bash
# Pre-task coordination
npx agentic-flow hooks pre-task --description "Build API"

# Post-task synchronization
npx agentic-flow hooks post-task --task-id "task-123"

# Session restore
npx agentic-flow hooks session-restore --session-id "swarm-001"
```

## Best Practices

1. **Start small**: Begin with 2-3 agents, scale up
2. **Use memory**: Share context through swarm memory
3. **Monitor metrics**: Track performance and bottlenecks
4. **Enable hooks**: Automatic coordination and sync
5. **Set timeouts**: Prevent hung tasks

## Troubleshooting

### Issue: Agents not coordinating
**Solution**: Verify memory access and enable hooks

### Issue: Poor performance
**Solution**: Check topology (use adaptive) and enable load balancing

## Learn More

- Swarm Guide: docs/swarm/orchestration.md
- Topology Patterns: docs/swarm/topologies.md
- Hooks Integration: docs/hooks/coordination.md

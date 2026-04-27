# Agent Spawning

**Category**: Coordination | **Priority**: High | **Agent Type**: Queen Coordinator

## Overview

Agent Spawning manages the creation, specialization, and lifecycle management of worker agents in hierarchical swarm systems. It handles resource allocation, capability matching, and load balancing to optimize swarm performance.

## Core Capabilities

### 1. Worker Agent Creation
```yaml
Spawn Operations:
  - Provision: Initialize new agent instances
  - Configure: Set capabilities and parameters
  - Register: Add to swarm coordination
  - Initialize: Set up memory and hooks
```

### 2. Specialization Patterns
```yaml
Agent Types:
  - Researcher: Information gathering and analysis
  - Coder: Implementation and development
  - Tester: Quality assurance and validation
  - Reviewer: Code review and optimization
  - Architect: System design and structure
  - Analyst: Data analysis and metrics
```

### 3. Resource Allocation
```yaml
Resources:
  - CPU: Processing power allocation
  - Memory: RAM usage limits
  - Tokens: LLM token budget
  - Time: Task duration limits
```

### 4. Load Balancing
```yaml
Balancing Strategies:
  - Capability-Based: Match skills to tasks
  - Workload-Based: Distribute by current load
  - Performance-Based: Assign by success rate
  - Hybrid: Combine multiple factors
```

## MCP Tool Integration

### Spawn New Agent
```bash
# Spawn with specific capabilities
mcp__claude-flow__agent_spawn \
  --type="coder" \
  --capabilities="code_generation,testing,optimization" \
  --priority=1 \
  --max-tokens=50000 \
  --timeout=3600

# Spawn researcher agent
mcp__claude-flow__agent_spawn \
  --type="researcher" \
  --capabilities="research,analysis,information_gathering" \
  --priority=2 \
  --max-tokens=30000 \
  --timeout=1800

# Spawn tester agent
mcp__claude-flow__agent_spawn \
  --type="tester" \
  --capabilities="testing,validation,quality_assurance" \
  --priority=3 \
  --max-tokens=40000 \
  --timeout=2400
```

### List Active Agents
```bash
# Get all registered agents
mcp__claude-flow__agent_list \
  --namespace="hive-mind" \
  --status="active"

# Get agents by type
mcp__claude-flow__agent_list \
  --type="coder" \
  --status="active"
```

### Get Agent Metrics
```bash
# Performance metrics for an agent
mcp__claude-flow__agent_metrics \
  --agent-id="worker-1" \
  --metrics="success_rate,avg_duration,tasks_completed"

# Resource usage
mcp__claude-flow__agent_metrics \
  --agent-id="worker-1" \
  --metrics="tokens_used,cpu_time,memory_usage"
```

### Terminate Agent
```bash
# Graceful shutdown
mcp__claude-flow__agent_spawn \
  --action="terminate" \
  --agent-id="worker-1" \
  --grace-period=30

# Immediate termination
mcp__claude-flow__agent_spawn \
  --action="terminate" \
  --agent-id="worker-2" \
  --force=true
```

## Memory Coordination Protocol

### 1. Register New Agent
```javascript
// Coordinator registers spawned agent
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/agents/registry",
  namespace: "coordination",
  value: JSON.stringify({
    agents: [
      {
        agent_id: "worker-1",
        agent_type: "coder",
        status: "initializing",
        capabilities: ["code_generation", "testing", "optimization"],
        resources: {
          max_tokens: 50000,
          timeout: 3600,
          priority: 1
        },
        spawned_at: Date.now(),
        spawned_by: "hive-mind-coordinator"
      }
    ],
    total_agents: 1,
    last_updated: Date.now()
  })
}
```

### 2. Agent Self-Initialization
```javascript
// Agent writes its initial state
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/worker-1/status",
  namespace: "coordination",
  value: JSON.stringify({
    agent_id: "worker-1",
    agent_type: "coder",
    status: "ready",
    current_task: null,
    capabilities: ["code_generation", "testing", "optimization"],
    performance: {
      tasks_completed: 0,
      success_rate: 100,
      avg_duration: 0
    },
    resources: {
      tokens_used: 0,
      tokens_remaining: 50000,
      cpu_time: 0
    },
    initialized_at: Date.now()
  })
}
```

### 3. Capability Advertisement
```javascript
// Agent advertises specific capabilities
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/shared/capabilities",
  namespace: "coordination",
  value: JSON.stringify({
    "worker-1": {
      languages: ["python", "javascript", "typescript"],
      frameworks: ["fastapi", "react", "django"],
      specialties: ["api_development", "database_design"],
      experience: "senior"
    },
    "worker-2": {
      languages: ["python", "go"],
      frameworks: ["pytest", "unittest"],
      specialties: ["testing", "quality_assurance"],
      experience: "senior"
    },
    "worker-3": {
      languages: ["javascript", "typescript"],
      frameworks: ["jest", "cypress"],
      specialties: ["frontend_testing", "e2e_testing"],
      experience: "mid"
    }
  })
}
```

### 4. Resource Pool Registration
```javascript
// Track available resource pool
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/resources/pool",
  namespace: "coordination",
  value: JSON.stringify({
    total_tokens: 200000,
    allocated_tokens: 150000,
    available_tokens: 50000,
    agents: [
      { agent_id: "worker-1", allocated: 50000, used: 12500 },
      { agent_id: "worker-2", allocated: 50000, used: 30000 },
      { agent_id: "worker-3", allocated: 50000, used: 45000 }
    ],
    last_updated: Date.now()
  })
}
```

### 5. Specialization Groups
```javascript
// Organize agents by specialization
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/agents/specialization",
  namespace: "coordination",
  value: JSON.stringify({
    groups: {
      "backend": {
        agents: ["worker-1", "worker-4"],
        capabilities: ["api", "database", "auth"],
        current_load: 60
      },
      "frontend": {
        agents: ["worker-2", "worker-5"],
        capabilities: ["ui", "components", "state"],
        current_load: 40
      },
      "testing": {
        agents: ["worker-3", "worker-6"],
        capabilities: ["unit", "integration", "e2e"],
        current_load: 80
      }
    },
    total_groups: 3
  })
}
```

## Claude Code Task Tool Integration

### Spawn Agents via Task Tool
```javascript
// Parallel agent spawning for full-stack development
Task("Backend Developer", "Build REST API with FastAPI. Initialize hooks and memory coordination.", "backend-dev")
Task("Frontend Developer", "Create React UI with TypeScript. Coordinate with backend via memory.", "coder")
Task("Database Architect", "Design PostgreSQL schema and migrations. Store schema in shared memory.", "code-analyzer")
Task("Test Engineer", "Write comprehensive test suite with 90% coverage. Check memory for API contracts.", "tester")
Task("DevOps Engineer", "Setup Docker and GitHub Actions CI/CD. Document configuration in memory.", "cicd-engineer")
Task("Security Reviewer", "Review authentication implementation. Report findings via shared memory.", "reviewer")
```

## Specialization Patterns

### 1. Role-Based Specialization
```javascript
// Define agent roles
const agentRoles = {
  researcher: {
    capabilities: ["research", "analysis", "documentation"],
    tools: ["web_search", "doc_reader", "knowledge_base"],
    priority: 1,
    max_concurrent_tasks: 3
  },
  coder: {
    capabilities: ["code_generation", "refactoring", "optimization"],
    tools: ["file_editor", "code_analyzer", "linter"],
    priority: 2,
    max_concurrent_tasks: 2
  },
  tester: {
    capabilities: ["testing", "validation", "quality_assurance"],
    tools: ["test_runner", "coverage_analyzer", "mutation_testing"],
    priority: 3,
    max_concurrent_tasks: 4
  },
  architect: {
    capabilities: ["system_design", "architecture", "patterns"],
    tools: ["diagram_generator", "pattern_library"],
    priority: 1,
    max_concurrent_tasks: 1
  }
}
```

### 2. Skill-Based Specialization
```javascript
// Define skill matrices
const skillMatrix = {
  languages: {
    python: ["worker-1", "worker-4"],
    javascript: ["worker-2", "worker-3", "worker-5"],
    go: ["worker-6"],
    rust: ["worker-7"]
  },
  frameworks: {
    fastapi: ["worker-1"],
    react: ["worker-2", "worker-3"],
    django: ["worker-4"],
    gin: ["worker-6"]
  },
  domains: {
    backend: ["worker-1", "worker-4", "worker-6"],
    frontend: ["worker-2", "worker-3", "worker-5"],
    devops: ["worker-8"],
    security: ["worker-9"]
  }
}
```

### 3. Adaptive Specialization
```javascript
// Learn optimal assignments from performance
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/learning/specialization",
  namespace: "coordination",
  value: JSON.stringify({
    patterns: [
      {
        task_type: "api_development",
        best_agent: "worker-1",
        success_rate: 98,
        avg_duration: 1800
      },
      {
        task_type: "frontend_testing",
        best_agent: "worker-3",
        success_rate: 95,
        avg_duration: 2400
      }
    ],
    updated_at: Date.now()
  })
}
```

## Load Balancing Algorithms

### 1. Capability-Based Matching
```python
def match_agent_by_capability(task, agents):
    """
    Assign task to agent with best capability match
    """
    best_match = None
    best_score = 0

    for agent in agents:
        # Calculate capability overlap
        required_capabilities = set(task.required_capabilities)
        agent_capabilities = set(agent.capabilities)

        overlap = required_capabilities.intersection(agent_capabilities)
        score = len(overlap) / len(required_capabilities)

        if score > best_score:
            best_score = score
            best_match = agent

    return best_match
```

### 2. Workload-Based Distribution
```python
def distribute_by_workload(tasks, agents):
    """
    Distribute tasks evenly across agents
    """
    # Sort agents by current workload
    sorted_agents = sorted(agents, key=lambda a: a.current_tasks)

    # Assign tasks to least loaded agents
    assignments = []
    for task in tasks:
        agent = sorted_agents[0]
        assignments.append((task, agent))
        agent.current_tasks += 1
        sorted_agents.sort(key=lambda a: a.current_tasks)

    return assignments
```

### 3. Performance-Based Selection
```python
def select_by_performance(task, agents):
    """
    Select agent based on historical performance
    """
    scored_agents = []

    for agent in agents:
        # Calculate performance score
        score = (
            agent.success_rate * 0.4 +
            (1 / agent.avg_duration) * 0.3 +
            (1 - agent.current_load) * 0.3
        )
        scored_agents.append((agent, score))

    # Return highest scoring agent
    return max(scored_agents, key=lambda x: x[1])[0]
```

## Resource Allocation

### Token Budget Management
```javascript
// Allocate token budget across agents
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/resources/token-allocation",
  namespace: "coordination",
  value: JSON.stringify({
    total_budget: 200000,
    allocations: [
      { agent_id: "worker-1", allocation: 50000, used: 12000, remaining: 38000 },
      { agent_id: "worker-2", allocation: 50000, used: 35000, remaining: 15000 },
      { agent_id: "worker-3", allocation: 50000, used: 8000, remaining: 42000 },
      { agent_id: "worker-4", allocation: 50000, used: 25000, remaining: 25000 }
    ],
    utilization_rate: 40,
    last_updated: Date.now()
  })
}
```

### Dynamic Resource Scaling
```javascript
// Scale resources based on demand
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/resources/scaling-policy",
  namespace: "coordination",
  value: JSON.stringify({
    scale_up_threshold: 80, // percentage
    scale_down_threshold: 30,
    min_agents: 2,
    max_agents: 10,
    auto_scale: true,
    scaling_factor: 1.5
  })
}
```

## Lifecycle Management

### Agent Lifecycle States
```yaml
States:
  initializing: Agent is being set up
  ready: Agent is ready to receive tasks
  active: Agent is working on a task
  idle: Agent has no current tasks
  draining: Agent is finishing current tasks
  terminated: Agent has been shut down

Transitions:
  initializing -> ready
  ready <-> active <-> idle
  idle <-> active
  active/idle -> draining -> terminated
```

### Health Monitoring
```javascript
// Monitor agent health
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/agents/health",
  namespace: "coordination",
  value: JSON.stringify({
    agents: [
      {
        agent_id: "worker-1",
        status: "healthy",
        last_heartbeat: Date.now(),
        tasks_completed: 5,
        errors: 0,
        uptime: 7200000
      },
      {
        agent_id: "worker-2",
        status: "degraded",
        last_heartbeat: Date.now() - 120000,
        tasks_completed: 3,
        errors: 2,
        uptime: 5400000
      }
    ],
    unhealthy_count: 1
  })
}
```

## Best Practices

### 1. Spawn Strategies
- Start with minimum viable agents
- Scale up based on workload
- Use specialization for complex tasks
- Maintain resource headroom (20%)

### 2. Capability Management
- Clearly define agent capabilities
- Update capabilities based on performance
- Track skill development over time
- Share capability information in memory

### 3. Resource Optimization
- Monitor token usage continuously
- Implement graceful degradation
- Prioritize critical tasks
- Reclaim resources from idle agents

### 4. Error Handling
- Implement automatic retry logic
- Quarantine failing agents
- Scale up to compensate for failures
- Log all termination events

## Monitoring and Metrics

### Spawning Metrics
```bash
# Track spawn operations
mcp__claude-flow__metrics_collect \
  --component="agent-spawning" \
  --metrics="spawn_count,spawn_duration,spawn_failures"

# Analyze agent utilization
mcp__claude-flow__performance_report \
  --format="agent-utilization" \
  --timeframe="24h"
```

## Usage Example

```bash
# Initialize agent spawning
claude-flow skill agent-spawning

# Spawn specialized workers
mcp__claude-flow__agent_spawn --type="coder" --capabilities="python,fastapi"
mcp__claude-flow__agent_spawn --type="tester" --capabilities="pytest,coverage"
mcp__claude-flow__agent_spawn --type="researcher" --capabilities="analysis,docs"

# Monitor spawned agents
mcp__claude-flow__agent_list --status="active"
mcp__claude-flow__agent_metrics --agent-id="worker-1"
```

## Related Skills

- **hive-mind-coordinator**: Strategic coordination
- **swarm-communication**: Memory sharing protocols
- **task-distribution**: Workload distribution
- **byzantine-consensus**: Fault tolerance

## Metrics Targets

- Spawn Success Rate: >99%
- Spawn Latency: <5 seconds
- Agent Utilization: 70-90%
- Resource Efficiency: >85%

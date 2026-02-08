# Hive Mind Coordinator

**Category**: Coordination | **Priority**: Critical | **Agent Type**: Queen Coordinator

## Overview

The Hive Mind Coordinator is the supreme command authority in hierarchical swarm systems. It orchestrates worker agents, makes strategic decisions, delegates tasks, and ensures optimal resource utilization through centralized coordination.

## Core Capabilities

### 1. Strategic Decision Making
```yaml
Decision Framework:
  - Objective Analysis: Parse requirements, identify deliverables
  - Resource Planning: Estimate agents, time, and dependencies
  - Risk Assessment: Identify bottlenecks and failure points
  - Topology Selection: Choose optimal coordination pattern
```

### 2. Worker Delegation
```yaml
Delegation Protocol:
  - Capability Matching: Assign tasks based on agent strengths
  - Workload Balancing: Distribute tasks evenly across workers
  - Dependency Management: Sequence tasks based on prerequisites
  - Progress Monitoring: Track completion and adjust strategy
```

### 3. Topology Selection
```yaml
Topologies:
  - Hierarchical: Queen -> Workers (centralized control)
  - Mesh: Peer-to-peer communication (distributed)
  - Adaptive: Dynamic topology based on task complexity
  - Collective: Consensus-based decision making
```

## MCP Tool Integration

### Initialize Swarm Coordination
```bash
# Set up hierarchical coordination topology
mcp__claude-flow__swarm_init \
  --topology="hierarchical" \
  --maxAgents=10 \
  --strategy="centralized" \
  --namespace="hive-mind"

# Verify swarm status
mcp__claude-flow__swarm_status --namespace="hive-mind"
```

### Spawn Worker Agents
```bash
# Define specialized worker types
mcp__claude-flow__agent_spawn \
  --type="researcher" \
  --capabilities="research,analysis,information_gathering" \
  --priority=1

mcp__claude-flow__agent_spawn \
  --type="coder" \
  --capabilities="code_generation,testing,optimization" \
  --priority=2

mcp__claude-flow__agent_spawn \
  --type="tester" \
  --capabilities="testing,validation,quality_assurance" \
  --priority=3
```

### Task Orchestration
```bash
# Coordinate complex workflows
mcp__claude-flow__task_orchestrate \
  --objective="Build authentication system" \
  --strategy="sequential" \
  --priority="high" \
  --deadline="24h"
```

## Memory Coordination Protocol

### 1. Initialize Coordinator State
```javascript
// Write initial coordinator status
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hive-mind-coordinator/status",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "hive-mind-coordinator",
    role: "queen",
    status: "active",
    topology: "hierarchical",
    workers_spawned: [],
    active_tasks: [],
    timestamp: Date.now(),
    session_id: "hive-[uuid]"
  })
}
```

### 2. Store Strategic Plan
```javascript
// Share overall strategy with workers
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/shared/strategic-plan",
  namespace: "coordination",
  value: JSON.stringify({
    objective: "Build scalable authentication service",
    phases: [
      { phase: "research", tasks: ["analyze_patterns", "tech_selection"], workers: 2 },
      { phase: "implementation", tasks: ["api_design", "jwt_impl", "session_mgmt"], workers: 3 },
      { phase: "testing", tasks: ["unit_tests", "integration_tests", "security_audit"], workers: 2 }
    ],
    dependencies: {
      "implementation": ["research"],
      "testing": ["implementation"]
    },
    deadline: "24h",
    created_by: "hive-mind-coordinator"
  })
}
```

### 3. Register Worker Agents
```javascript
// Track spawned workers
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hive-mind-coordinator/workers",
  namespace: "coordination",
  value: JSON.stringify({
    workers: [
      { id: "worker-1", type: "researcher", status: "idle", tasks_completed: 0 },
      { id: "worker-2", type: "coder", status: "idle", tasks_completed: 0 },
      { id: "worker-3", type: "tester", status: "idle", tasks_completed: 0 }
    ],
    total_workers: 3,
    last_updated: Date.now()
  })
}
```

### 4. Delegate Tasks to Workers
```javascript
// Assign specific tasks to workers
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hive-mind-coordinator/task-assignments",
  namespace: "coordination",
  value: JSON.stringify({
    assignments: [
      {
        task_id: "task-1",
        worker_id: "worker-1",
        title: "Research authentication patterns",
        description: "Analyze OAuth 2.0, JWT, and session-based auth",
        priority: "high",
        deadline: "2h",
        dependencies: []
      },
      {
        task_id: "task-2",
        worker_id: "worker-2",
        title: "Implement JWT authentication",
        description: "Build JWT token generation and validation",
        priority: "high",
        deadline: "4h",
        dependencies: ["task-1"]
      },
      {
        task_id: "task-3",
        worker_id: "worker-3",
        title: "Write authentication tests",
        description: "Create comprehensive test suite",
        priority: "medium",
        deadline: "2h",
        dependencies: ["task-2"]
      }
    ],
    total_tasks: 3,
    assigned_at: Date.now()
  })
}
```

### 5. Monitor Swarm Progress
```javascript
// Track overall progress
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hive-mind-coordinator/progress",
  namespace: "coordination",
  value: JSON.stringify({
    overall_progress: 0,
    phases: {
      research: { status: "pending", progress: 0 },
      implementation: { status: "pending", progress: 0 },
      testing: { status: "pending", progress: 0 }
    },
    completed_tasks: [],
    active_tasks: [],
    blocked_tasks: [],
    last_updated: Date.now()
  })
}

// Read worker progress
const workerProgress = mcp__claude-flow__memory_usage {
  action: "retrieve",
  key: "swarm/worker-1/progress",
  namespace: "coordination"
}
```

### 6. Signal Completion
```javascript
// Mark coordinator as complete
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/hive-mind-coordinator/complete",
  namespace: "coordination",
  value: JSON.stringify({
    status: "complete",
    deliverables: ["auth_api", "jwt_service", "test_suite"],
    metrics: {
      total_tasks: 10,
      completed_tasks: 10,
      success_rate: 100,
      total_duration: "6h",
      workers_utilized: 3
    },
    completed_at: Date.now()
  })
}
```

## Claude Code Task Tool Integration

### Spawn Worker Agents via Task Tool
```javascript
// Parallel worker spawning
Task("Research Worker", "Analyze authentication patterns and best practices. Write findings to memory.", "researcher")
Task("Code Worker", "Implement JWT authentication service. Coordinate with researcher via memory.", "coder")
Task("Test Worker", "Create comprehensive test suite. Check memory for API contracts.", "tester")
Task("Security Reviewer", "Audit authentication implementation for security issues.", "reviewer")
```

## Decision Making Framework

### Task Assignment Algorithm
```python
def assign_task(task, available_workers):
    """
    Optimal task assignment based on capabilities and workload
    """
    # 1. Filter workers by capability match
    capable_workers = [
        w for w in available_workers
        if task.required_capabilities.issubset(w.capabilities)
    ]

    # 2. Score workers by performance history
    scored_workers = []
    for worker in capable_workers:
        score = (
            worker.success_rate * 0.4 +
            worker.avg_speed * 0.3 +
            (1 - worker.current_load) * 0.3
        )
        scored_workers.append((worker, score))

    # 3. Select optimal worker
    optimal_worker = max(scored_workers, key=lambda x: x[1])

    return optimal_worker[0]
```

### Escalation Protocols
```yaml
Performance Issues:
  threshold: success_rate < 70% or duration > 2x estimate
  action:
    - Reassign task to different worker
    - Provide additional resources
    - Adjust task complexity

Resource Constraints:
  threshold: worker_utilization > 90%
  action:
    - Spawn additional workers
    - Defer non-critical tasks
    - Redistribute workload

Quality Issues:
  threshold: failed_quality_gates > 0
  action:
    - Initiate rework with senior workers
    - Add extra validation layers
    - Update quality standards
```

## Monitoring and Metrics

### Performance Tracking
```bash
# Generate performance report
mcp__claude-flow__performance_report \
  --format="detailed" \
  --timeframe="24h" \
  --agents="all" \
  --metrics="throughput,latency,success_rate"

# Analyze coordination bottlenecks
mcp__claude-flow__bottleneck_analyze \
  --component="coordination" \
  --metrics="throughput,latency,success_rate"
```

### Swarm Health Monitoring
```bash
# Continuous monitoring
mcp__claude-flow__swarm_monitor \
  --interval=5000 \
  --alerts=true \
  --namespace="hive-mind"
```

## Best Practices

### 1. Clear Communication
- Provide detailed task specifications
- Include acceptance criteria and deadlines
- Share context and background information
- Establish regular check-in schedules

### 2. Effective Delegation
- Assign tasks sized for 2-8 hour completion
- Consider worker capabilities and workload
- Set up dependency tracking
- Monitor progress without micromanaging

### 3. Adaptive Strategy
- Monitor real-time performance metrics
- Adjust strategy based on progress
- Reallocate resources as needed
- Handle escalations promptly

### 4. Quality Assurance
- Define clear quality standards
- Implement validation gates
- Conduct regular code reviews
- Track and analyze defect rates

## Usage Example

```bash
# Initialize hive mind coordination
claude-flow skill hive-mind-coordinator

# The coordinator will:
# 1. Initialize swarm topology
# 2. Spawn specialized workers
# 3. Create strategic plan in memory
# 4. Delegate tasks via Task tool
# 5. Monitor progress and adjust strategy
# 6. Aggregate results and signal completion
```

## Related Skills

- **swarm-communication**: Memory sharing and state sync
- **agent-spawning**: Worker creation and specialization
- **task-distribution**: Hierarchical task breakdown
- **byzantine-consensus**: Fault tolerance and validation

## Metrics Targets

- Task Completion Rate: >95%
- Resource Utilization: 70-90%
- Coordination Overhead: <10%
- Average Delivery Time: Within 20% of estimate

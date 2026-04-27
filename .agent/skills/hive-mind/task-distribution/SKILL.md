# Task Distribution

**Category**: Coordination | **Priority**: High | **Agent Type**: Queen Coordinator

## Overview

Task Distribution manages the breakdown, allocation, and coordination of work across hierarchical swarm systems. It handles dependency management, parallel execution strategies, and result aggregation to optimize task completion.

## Core Capabilities

### 1. Hierarchical Task Breakdown
```yaml
Decomposition:
  - Objective: High-level goal
  - Phases: Major work stages
  - Work Packages: Grouped tasks
  - Atomic Tasks: Individual work units
```

### 2. Dependency Management
```yaml
Dependency Types:
  - Sequential: Task A must complete before Task B
  - Parallel: Tasks can run simultaneously
  - Conditional: Task depends on condition/state
  - Resource: Tasks share limited resources
```

### 3. Parallel Execution
```yaml
Execution Strategies:
  - Pipeline: Sequential stages, parallel tasks within
  - Map-Reduce: Decompose, process, aggregate
  - Fork-Join: Split into parallel streams
  - Batch: Process groups of tasks
```

### 4. Result Aggregation
```yaml
Aggregation Methods:
  - Sequential: Collect in dependency order
  - Parallel: Collect as tasks complete
  - Incremental: Update partial results
  - Event-Driven: Trigger on completion
```

## MCP Tool Integration

### Orchestrate Complex Workflows
```bash
# Orchestrate multi-phase workflow
mcp__claude-flow__task_orchestrate \
  --objective="Build authentication system" \
  --strategy="pipeline" \
  --phases="research,implementation,testing" \
  --priority="high" \
  --deadline="24h"

# Parallel task execution
mcp__claude-flow__task_orchestrate \
  --objective="Execute test suite" \
  --strategy="parallel" \
  --tasks="unit,integration,e2e,performance" \
  --max-concurrent=4
```

### Load Balance Tasks
```bash
# Distribute tasks across workers
mcp__claude-flow__load_balance \
  --tasks="auth_api,auth_tests,auth_docs,auth_deployment" \
  --strategy="capability_based" \
  --workers="worker-1,worker-2,worker-3"

# Dynamic workload balancing
mcp__claude-flow__load_balance \
  --strategy="performance_based" \
  --rebalance-interval=300
```

### Monitor Task Status
```bash
# Get all task statuses
mcp__claude-flow__task_status \
  --namespace="hive-mind" \
  --filter="active"

# Get specific task details
mcp__claude-flow__task_status \
  --task-id="task-001" \
  --details=true
```

### Retrieve Task Results
```bash
# Get completed task results
mcp__claude-flow__task_results \
  --task-ids="task-001,task-002,task-003" \
  --format="json"

# Get aggregated results
mcp__claude-flow__task_results \
  --phase="implementation" \
  --aggregate=true
```

## Memory Coordination Protocol

### 1. Define Task Hierarchy
```javascript
// Break down objective into tasks
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/tasks/hierarchy",
  namespace: "coordination",
  value: JSON.stringify({
    objective: "Build scalable authentication service",
    phases: [
      {
        phase_id: "phase-1",
        name: "Research",
        tasks: [
          { task_id: "task-1", title: "Analyze auth patterns", priority: "high", estimate: "2h" },
          { task_id: "task-2", title: "Select technology stack", priority: "high", estimate: "1h" }
        ]
      },
      {
        phase_id: "phase-2",
        name: "Implementation",
        tasks: [
          { task_id: "task-3", title: "Design database schema", priority: "high", estimate: "2h" },
          { task_id: "task-4", title: "Implement JWT service", priority: "high", estimate: "3h" },
          { task_id: "task-5", title: "Build API endpoints", priority: "high", estimate: "4h" }
        ]
      },
      {
        phase_id: "phase-3",
        name: "Testing",
        tasks: [
          { task_id: "task-6", title: "Write unit tests", priority: "medium", estimate: "2h" },
          { task_id: "task-7", title: "Write integration tests", priority: "medium", estimate: "2h" },
          { task_id: "task-8", title: "Security audit", priority: "high", estimate: "2h" }
        ]
      }
    ],
    total_tasks: 8,
    created_by: "hive-mind-coordinator"
  })
}
```

### 2. Define Task Dependencies
```javascript
// Specify task dependencies
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/tasks/dependencies",
  namespace: "coordination",
  value: JSON.stringify({
    dependencies: [
      {
        task_id: "task-3",
        depends_on: ["task-1", "task-2"],
        reason: "Need patterns and stack before schema design"
      },
      {
        task_id: "task-4",
        depends_on: ["task-3"],
        reason: "Need schema before JWT implementation"
      },
      {
        task_id: "task-5",
        depends_on: ["task-4"],
        reason: "Need JWT before API endpoints"
      },
      {
        task_id: "task-6",
        depends_on: ["task-5"],
        reason: "Need implementation before unit tests"
      },
      {
        task_id: "task-7",
        depends_on: ["task-5"],
        reason: "Need implementation before integration tests"
      },
      {
        task_id: "task-8",
        depends_on: ["task-5"],
        reason: "Need implementation before security audit"
      }
    ],
    dependency_graph: {
      "task-1": ["task-3"],
      "task-2": ["task-3"],
      "task-3": ["task-4"],
      "task-4": ["task-5", "task-6", "task-7", "task-8"]
    }
  })
}
```

### 3. Assign Tasks to Workers
```javascript
// Delegate tasks to specific workers
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/tasks/assignments",
  namespace: "coordination",
  value: JSON.stringify({
    assignments: [
      {
        task_id: "task-1",
        worker_id: "worker-1",
        status: "assigned",
        assigned_at: Date.now(),
        deadline: Date.now() + 7200000 // 2 hours
      },
      {
        task_id: "task-2",
        worker_id: "worker-1",
        status: "assigned",
        assigned_at: Date.now(),
        deadline: Date.now() + 3600000 // 1 hour
      },
      {
        task_id: "task-3",
        worker_id: "worker-2",
        status: "pending",
        depends_on: ["task-1", "task-2"]
      },
      {
        task_id: "task-4",
        worker_id: "worker-3",
        status: "pending",
        depends_on: ["task-3"]
      }
    ],
    total_assigned: 2,
    total_pending: 6
  })
}
```

### 4. Track Task Progress
```javascript
// Monitor task completion
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/tasks/progress",
  namespace: "coordination",
  value: JSON.stringify({
    overall: {
      total: 8,
      completed: 2,
      in_progress: 2,
      pending: 4,
      percentage: 25
    },
    by_phase: {
      "phase-1": { total: 2, completed: 2, percentage: 100 },
      "phase-2": { total: 3, completed: 0, in_progress: 2, percentage: 0 },
      "phase-3": { total: 3, completed: 0, percentage: 0 }
    },
    by_worker: {
      "worker-1": { assigned: 2, completed: 2, success_rate: 100 },
      "worker-2": { assigned: 1, in_progress: 1 },
      "worker-3": { assigned: 1, in_progress: 1 }
    },
    last_updated: Date.now()
  })
}
```

### 5. Aggregate Task Results
```javascript
// Collect and combine results
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/tasks/results",
  namespace: "coordination",
  value: JSON.stringify({
    phase: "phase-2",
    results: [
      {
        task_id: "task-3",
        worker_id: "worker-2",
        status: "completed",
        deliverables: ["schema.sql", "models.py"],
        completed_at: Date.now()
      },
      {
        task_id: "task-4",
        worker_id: "worker-3",
        status: "completed",
        deliverables: ["jwt_service.py", "jwt_test.py"],
        completed_at: Date.now()
      },
      {
        task_id: "task-5",
        worker_id: "worker-2",
        status: "completed",
        deliverables: ["api_routes.py", "api_docs.md"],
        completed_at: Date.now()
      }
    ],
    aggregated_deliverables: [
      "schema.sql", "models.py", "jwt_service.py",
      "jwt_test.py", "api_routes.py", "api_docs.md"
    ],
    phase_status: "complete",
    aggregated_at: Date.now()
  })
}
```

### 6. Signal Phase Transition
```javascript
// Notify workers of phase completion
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/events/phase-2-complete",
  namespace: "coordination",
  value: JSON.stringify({
    event_type: "phase_completed",
    phase_id: "phase-2",
    phase_name: "Implementation",
    completed_at: Date.now(),
    next_phase: "phase-3",
    next_phase_name: "Testing",
    notify: ["worker-1", "worker-2", "worker-3", "coordinator"],
    artifacts_available: [
      "swart/shared/database-schema",
      "swarm/shared/jwt-service",
      "swarm/shared/api-routes"
    ]
  })
}
```

## Task Distribution Algorithms

### 1. Topological Sort for Dependencies
```python
def topological_sort(tasks, dependencies):
    """
    Sort tasks respecting dependencies
    Returns execution order
    """
    from collections import defaultdict, deque

    # Build graph
    graph = defaultdict(list)
    in_degree = {task: 0 for task in tasks}

    for task, deps in dependencies.items():
        for dep in deps:
            graph[dep].append(task)
            in_degree[task] += 1

    # Find tasks with no dependencies
    queue = deque([task for task in tasks if in_degree[task] == 0])
    result = []

    while queue:
        task = queue.popleft()
        result.append(task)

        # Reduce in-degree for dependents
        for dependent in graph[task]:
            in_degree[dependent] -= 1
            if in_degree[dependent] == 0:
                queue.append(dependent)

    return result if len(result) == len(tasks) else None
```

### 2. Critical Path Analysis
```python
def find_critical_path(tasks, dependencies, estimates):
    """
    Identify the longest dependency path
    Determines minimum project duration
    """
    # Calculate earliest start/finish times
    earliest = {}
    for task in topological_sort(tasks, dependencies):
        deps = dependencies.get(task, [])
        earliest[task] = max([earliest[d] + estimates[d] for d in deps], default=0)

    # Calculate latest start/finish times
    latest = {}
    max_time = max([earliest[t] + estimates[t] for t in tasks])
    for task in reversed(topological_sort(tasks, dependencies)):
        dependents = [t for t, deps in dependencies.items() if task in deps]
        if dependents:
            latest[task] = min([latest[d] for d in dependents]) - estimates[task]
        else:
            latest[task] = max_time - estimates[task]

    # Find critical path (slack = 0)
    critical = [t for t in tasks if earliest[t] == latest[t]]

    return critical, max_time
```

### 3. Parallel Task Scheduling
```python
def schedule_parallel(tasks, dependencies, workers, estimates):
    """
    Schedule tasks across workers for parallel execution
    """
    import heapq

    schedule = []
    worker_queues = {w: [] for w in workers}
    worker availability = {w: 0 for w in workers}

    # Sort tasks by topological order
    ordered_tasks = topological_sort(tasks, dependencies)

    for task in ordered_tasks:
        # Find earliest time task can start (dependencies)
        dep_complete = max([
            schedule[t]['finish']
            for t in dependencies.get(task, [])
        ], default=0)

        # Find available worker
        available_workers = [
            (availability_time, worker)
            for worker, availability_time in worker_availability.items()
            if availability_time <= dep_complete
        ]

        if available_workers:
            _, worker = min(available_workers)
            start = dep_complete
        else:
            # All workers busy, pick earliest available
            worker = min(worker_availability, key=worker_availability.get)
            start = max(dep_complete, worker_availability[worker])

        finish = start + estimates[task]

        schedule.append({
            'task': task,
            'worker': worker,
            'start': start,
            'finish': finish
        })

        worker_availability[worker] = finish

    return schedule
```

## Execution Patterns

### 1. Pipeline Pattern
```yaml
Pipeline: Sequential phases, parallel within phases
Example:
  Phase 1 (Research):
    - Task 1.1: Analyze patterns (Worker 1)
    - Task 1.2: Select stack (Worker 1)
  Phase 2 (Implementation):
    - Task 2.1: Schema (Worker 2)
    - Task 2.2: JWT (Worker 3) [parallel with 2.1]
    - Task 2.3: API (Worker 4) [depends on 2.2]
  Phase 3 (Testing):
    - Task 3.1: Unit tests (Worker 5)
    - Task 3.2: Integration (Worker 6) [parallel with 3.1]
```

### 2. Map-Reduce Pattern
```yaml
Map: Decompose task into subtasks
  - Task: Test entire codebase
  - Map: Split into [unit, integration, e2e, performance]

Reduce: Aggregate results
  - Collect: Coverage reports, test results, metrics
  - Reduce: Generate summary report
```

### 3. Fork-Join Pattern
```yaml
Fork: Split into parallel streams
  Stream A: Backend development (Worker 1, 2)
  Stream B: Frontend development (Worker 3, 4)
  Stream C: Documentation (Worker 5)

Join: Merge streams when complete
  - Integration: Connect backend and frontend
  - Validation: Review against requirements
```

## Result Aggregation

### Sequential Aggregation
```javascript
// Collect results in dependency order
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/results/sequential",
  namespace: "coordination",
  value: JSON.stringify({
    aggregation_strategy: "sequential",
    execution_order: ["task-1", "task-2", "task-3"],
    results: {
      "task-1": { status: "completed", output: "patterns.md" },
      "task-2": { status: "completed", output: "stack.md" },
      "task-3": { status: "completed", output: "schema.sql" }
    },
    aggregated_output: ["patterns.md", "stack.md", "schema.sql"],
    complete: true
  })
}
```

### Parallel Aggregation
```javascript
// Collect results as tasks complete
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/results/parallel",
  namespace: "coordination",
  value: JSON.stringify({
    aggregation_strategy: "parallel",
    total_tasks: 4,
    completed_tasks: 3,
    results: {
      "task-1": { status: "completed", output: "unit_tests.py" },
      "task-3": { status: "completed", output: "e2e_tests.py" },
      "task-4": { status: "completed", output: "performance_tests.py" }
    },
    pending: ["task-2"],
    partial_aggregation: true
  })
}
```

## Best Practices

### 1. Task Granularity
- Ideal task size: 2-8 hours of work
- Too small: Excessive coordination overhead
- Too large: Reduced parallelism, harder to recover from failures

### 2. Dependency Management
- Minimize cross-task dependencies
- Use well-defined interfaces between tasks
- Document dependency reasons clearly
- Implement circular dependency detection

### 3. Progress Monitoring
- Track progress at multiple levels (task, phase, overall)
- Update progress frequently (every 5-10 minutes)
- Alert on blockers and delays
- Estimate completion time dynamically

### 4. Error Handling
- Implement retry logic for transient failures
- Quarantine persistently failing tasks
- Provide clear error context
- Enable graceful degradation

## Monitoring and Metrics

### Distribution Metrics
```bash
# Track task distribution
mcp__claude-flow__metrics_collect \
  --component="task-distribution" \
  --metrics="tasks_assigned,tasks_completed,assignment_latency"

# Analyze execution patterns
mcp__claude-flow__performance_report \
  --format="task-execution" \
  --timeframe="24h"
```

### Bottleneck Detection
```bash
# Find blocking tasks
mcp__claude-flow__bottleneck_analyze \
  --component="task-distribution" \
  --metrics="blocked_tasks,wait_time,dependencies"

# Analyze worker utilization
mcp__claude-flow__performance_report \
  --format="worker-utilization" \
  --by-worker=true
```

## Usage Example

```bash
# Initialize task distribution
claude-flow skill task-distribution

# Orchestrate complex workflow
mcp__claude-flow__task_orchestrate \
  --objective="Build authentication system" \
  --strategy="pipeline" \
  --phases="research,implementation,testing,deployment"

# Monitor progress
mcp__claude-flow__task_status --namespace="hive-mind"

# Get aggregated results
mcp__claude-flow__task_results --phase="implementation" --aggregate=true
```

## Related Skills

- **hive-mind-coordinator**: Strategic coordination
- **swarm-communication**: Memory sharing and notifications
- **agent-spawning**: Worker creation and management
- **byzantine-consensus**: Fault tolerance

## Metrics Targets

- Task Assignment Latency: <1 second
- Distribution Efficiency: >95%
- Dependency Resolution: >99%
- Parallel Speedup: 2-4x for parallelizable tasks

# Swarm Communication

**Category**: Coordination | **Priority**: Critical | **Agent Type**: All Agents

## Overview

Swarm Communication enables efficient information exchange, state synchronization, and collaborative decision making across distributed agent systems through structured memory sharing protocols and broadcast patterns.

## Core Capabilities

### 1. Memory Sharing Protocols
```yaml
Memory Operations:
  - Store: Write artifacts to shared memory
  - Retrieve: Read artifacts from shared memory
  - Update: Modify existing memory entries
  - Broadcast: Send updates to all subscribed agents
```

### 2. State Synchronization
```yaml
Sync Patterns:
  - Event-Based: Trigger on state changes
  - Polling: Periodic state checks
  - Pub-Sub: Subscribe to memory keys
  - Gossip: Peer-to-peer state exchange
```

### 3. Consensus Building
```yaml
Consensus Methods:
  - Voting: Majority decision making
  - Quorum: Minimum agreement threshold
  - Conflict Resolution: Merge strategies
  - Validation: Quality and consistency checks
```

### 4. Broadcast Patterns
```yaml
Broadcast Types:
  - One-to-All: Coordinator to all workers
  - One-to-Many: Agent to specific subset
  - Many-to-One: Workers to coordinator
  - Many-to-Many: Peer-to-peer exchange
```

## MCP Tool Integration

### Memory Storage Operations
```bash
# Store artifacts in shared memory
mcp__claude-flow__memory_usage \
  --action="store" \
  --key="swarm/shared/artifact-name" \
  --namespace="coordination" \
  --value='{"type": "interface", "definition": "..."}'

# Batch store multiple artifacts
mcp__claude-flow__memory_usage \
  --action="store-batch" \
  --namespace="coordination" \
  --values='{
    "swarm/shared/api": {...},
    "swarm/shared/schema": {...},
    "swarm/shared/config": {...}
  }'
```

### Memory Retrieval Operations
```bash
# Retrieve specific artifact
mcp__claude-flow__memory_usage \
  --action="retrieve" \
  --key="swarm/shared/artifact-name" \
  --namespace="coordination"

# Retrieve all keys with pattern
mcp__claude-flow__memory_usage \
  --action="retrieve-pattern" \
  --pattern="swarm/shared/*" \
  --namespace="coordination"
```

### Memory Update Operations
```bash
# Update existing artifact
mcp__claude-flow__memory_usage \
  --action="update" \
  --key="swarm/shared/artifact-name" \
  --namespace="coordination" \
  --value='{"updated": true, "version": 2}'

# Atomic update with version check
mcp__claude-flow__memory_usage \
  --action="update-atomic" \
  --key="swarm/shared/artifact" \
  --namespace="coordination" \
  --expected-version=1 \
  --value='{"version": 2}'
```

### Subscribe to Memory Changes
```bash
# Subscribe to key changes
mcp__claude-flow__memory_usage \
  --action="subscribe" \
  --key="swarm/shared/*" \
  --namespace="coordination" \
  --callback="handle_change"

# Unsubscribe from updates
mcp__claude-flow__memory_usage \
  --action="unsubscribe" \
  --key="swarm/shared/*" \
  --namespace="coordination"
```

## Memory Coordination Protocol

### 1. Agent State Broadcasting
```javascript
// Broadcast agent status to swarm
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/worker-1/status",
  namespace: "coordination",
  value: JSON.stringify({
    agent_id: "worker-1",
    agent_type: "coder",
    status: "active",
    current_task: "task-2",
    progress: 45,
    capabilities: ["code_generation", "testing"],
    started_at: Date.now(),
    last_heartbeat: Date.now(),
    metadata: {
      language: "python",
      framework: "fastapi"
    }
  })
}
```

### 2. Artifact Sharing
```javascript
// Share code artifact with swarm
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/shared/auth-interface",
  namespace: "coordination",
  value: JSON.stringify({
    type: "interface",
    name: "AuthService",
    version: "1.0.0",
    definition: `
      interface AuthService {
        login(credentials: LoginRequest): Promise<AuthResponse>
        logout(token: string): Promise<void>
        verify(token: string): Promise<UserInfo>
        refresh(token: string): Promise<AuthResponse>
      }
    `,
    methods: ["login", "logout", "verify", "refresh"],
    dependencies: ["JWT", "Redis"],
    created_by: "worker-2",
    created_at: Date.now(),
    validation_status: "pending"
  })
}
```

### 3. Progress Updates
```javascript
// Update task progress
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/worker-2/progress",
  namespace: "coordination",
  value: JSON.stringify({
    task_id: "task-2",
    completed_steps: ["setup", "models", "routes"],
    current_step: "middleware",
    remaining_steps: ["testing", "docs"],
    progress_percentage: 60,
    estimated_completion: Date.now() + 3600000, // 1 hour from now
    blockers: [],
    files_created: [
      "src/services/auth.py",
      "src/models/user.py",
      "src/routes/auth.py"
    ]
  })
}
```

### 4. Dependency Signaling
```javascript
// Signal waiting for dependency
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/worker-3/waiting",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "worker-3",
    waiting_for: "auth-interface",
    from: "worker-2",
    reason: "Need AuthService interface to implement tests",
    timeout: 3600000, // 1 hour timeout
    notified_at: Date.now()
  })
}

// Check if dependency is ready
const depCheck = mcp__claude-flow__memory_usage {
  action: "retrieve",
  key: "swarm/shared/auth-interface",
  namespace: "coordination"
}

if (depCheck.found && depCheck.value.validation_status === "approved") {
  // Dependency ready, proceed with work
}
```

### 5. Consensus Voting
```javascript
// Initiate consensus vote
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/consensus/vote-001",
  namespace: "coordination",
  value: JSON.stringify({
    proposal_id: "vote-001",
    proposal: "Use OAuth 2.0 for authentication",
    proposed_by: "worker-1",
    voters: ["worker-1", "worker-2", "worker-3"],
    votes: {
      "worker-1": "approve",
      "worker-2": "pending",
      "worker-3": "pending"
    },
    quorum: 3,
    deadline: Date.now() + 1800000, // 30 minutes
    status: "pending"
  })
}

// Cast vote
mcp__claude-flow__memory_usage {
  action: "update",
  key: "swarm/consensus/vote-001",
  namespace: "coordination",
  value: JSON.stringify({
    votes: {
      "worker-1": "approve",
      "worker-2": "approve",
      "worker-3": "approve"
    },
    status: "approved",
    decided_at: Date.now()
  })
}
```

### 6. Event Broadcasting
```javascript
// Broadcast event to all agents
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/events/task-2-completed",
  namespace: "coordination",
  value: JSON.stringify({
    event_type: "task_completed",
    task_id: "task-2",
    completed_by: "worker-2",
    completed_at: Date.now(),
    deliverables: ["auth_service.py", "auth_tests.py"],
    next_tasks: ["task-3", "task-4"],
    notify: ["worker-1", "worker-3", "coordinator"]
  })
}
```

## Communication Patterns

### Pattern 1: Request-Response
```javascript
// Worker A requests information
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/requests/req-001",
  namespace: "coordination",
  value: JSON.stringify({
    request_id: "req-001",
    from: "worker-1",
    to: "worker-2",
    request: "What database schema are you using?",
    timestamp: Date.now(),
    status: "pending"
  })
}

// Worker B responds
mcp__claude-flow__memory_usage {
  action: "update",
  key: "swarm/requests/req-001",
  namespace: "coordination",
  value: JSON.stringify({
    response: "PostgreSQL with users, sessions, and tokens tables",
    responded_by: "worker-2",
    responded_at: Date.now(),
    status: "completed"
  })
}
```

### Pattern 2: Publish-Subscribe
```javascript
// Subscribe to updates
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/subscriptions/worker-1",
  namespace: "coordination",
  value: JSON.stringify({
    subscriber: "worker-1",
    subscriptions: [
      "swarm/shared/*",
      "swarm/events/*",
      "swarm/consensus/*"
    ],
    subscribed_at: Date.now()
  })
}

// Publisher updates shared artifact
// Subscribers automatically notified via memory change events
```

### Pattern 3: Gossip Protocol
```javascript
// Agent shares its state with peers
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/gossip/worker-1",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "worker-1",
    known_peers: ["worker-2", "worker-3"],
    peer_states: {
      "worker-2": { status: "active", last_seen: Date.now() },
      "worker-3": { status: "idle", last_seen: Date.now() - 60000 }
    },
    shared_artifacts: ["schema-v1", "api-v2"],
    last_gossip: Date.now()
  })
}
```

## State Synchronization

### Sync Strategies
```yaml
Event-Driven Sync:
  trigger: State change in shared memory
  action: Immediate notification to subscribers
  use_case: Real-time collaboration

Polling-Based Sync:
  trigger: Periodic interval (e.g., 30 seconds)
  action: Check for updates in subscribed keys
  use_case: Background tasks, batch processing

Hybrid Sync:
  trigger: Event + polling fallback
  action: Event-driven with polling backup
  use_case: Critical systems requiring redundancy
```

### Conflict Resolution
```javascript
// Detect and resolve conflicts
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/shared/schema",
  namespace: "coordination",
  value: JSON.stringify({
    type: "database_schema",
    versions: {
      "v1": { author: "worker-1", created_at: Date.now() - 3600000 },
      "v2": { author: "worker-2", created_at: Date.now() }
    },
    conflict_status: "detected",
    resolution_strategy: "merge",
    merged_version: "v3",
    resolved_by: "coordinator"
  })
}
```

## Best Practices

### 1. Memory Key Structure
```yaml
Naming Convention:
  - swarm/[agent]/status: Individual agent status
  - swarm/shared/[artifact]: Shared artifacts
  - swarm/events/[event]: Event notifications
  - swarm/consensus/[vote]: Consensus votes
  - swarm/requests/[request]: Request-response pairs

Namespace: Always use "coordination"
```

### 2. Efficient Communication
- Batch multiple memory operations in single calls
- Use subscriptions instead of polling for real-time updates
- Implement message compression for large payloads
- Cache frequently accessed artifacts locally

### 3. Error Handling
```javascript
// Handle memory operation failures
try {
  const result = mcp__claude-flow__memory_usage {
    action: "store",
    key: "swarm/shared/data",
    namespace: "coordination",
    value: JSON.stringify(data)
  }

  if (!result.success) {
    // Retry with exponential backoff
    // Log error for monitoring
    // Notify coordinator of persistent failures
  }
} catch (error) {
  // Implement fallback strategy
}
```

### 4. Security Considerations
- Validate all memory inputs
- Implement access control for sensitive data
- Encrypt confidential information
- Audit memory access patterns

## Monitoring and Debugging

### Communication Metrics
```bash
# Monitor message throughput
mcp__claude-flow__metrics_collect \
  --component="communication" \
  --metrics="message_count,latency,errors"

# Analyze communication patterns
mcp__claude-flow__performance_report \
  --format="communication" \
  --timeframe="1h"
```

### Debug Communication Issues
```javascript
// Enable debug logging
mcp__claude-flow__memory_usage {
  action: "store",
  key: "swarm/debug/communication",
  namespace: "coordination",
  value: JSON.stringify({
    debug_enabled: true,
    log_level: "verbose",
    track_operations: ["store", "retrieve", "update"],
    log_retention: "24h"
  })
}
```

## Usage Example

```bash
# Agent A shares an interface
mcp__claude-flow__memory_usage --action="store" \
  --key="swarm/shared/api-interface" \
  --namespace="coordination" \
  --value='{"type": "interface", "definition": "..."}'

# Agent B waits for and retrieves the interface
while true; do
  result=$(mcp__claude-flow__memory_usage --action="retrieve" \
    --key="swarm/shared/api-interface" \
    --namespace="coordination")

  if [ "$result" != "not_found" ]; then
    break
  fi
  sleep 5
done

# Agent C subscribes to updates
mcp__claude-flow__memory_usage --action="subscribe" \
  --key="swarm/shared/*" \
  --namespace="coordination"
```

## Related Skills

- **hive-mind-coordinator**: Strategic coordination
- **agent-spawning**: Worker creation and setup
- **task-distribution**: Task dependency management
- **byzantine-consensus**: Fault tolerance and validation

## Metrics Targets

- Message Latency: <100ms for local operations
- Throughput: >1000 messages/second
- Sync Consistency: 99.9%
- Error Rate: <0.1%

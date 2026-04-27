# Hive Mind Training Materials
**Version**: 1.0.0
**Date**: 2026-02-10
**Status**: Active Training Program
**Audience**: AGL Infrastructure Team, Developers, System Administrators

---

## Table of Contents
1. [Training Overview](#training-overview)
2. [Getting Started](#getting-started)
3. [Core Concepts](#core-concepts)
4. [Agent Development](#agent-development)
5. [Operations Training](#operations-training)
6. [Troubleshooting Training](#troubleshooting-training)
7. [Advanced Topics](#advanced-topics)
8. [Certification](#certification)
9. [Resources](#resources)

---

## Training Overview

### Learning Objectives

Upon completion of this training program, participants will be able to:

1. **Understand** the Hive Mind architecture and design principles
2. **Operate** the Hive Mind system effectively in production
3. **Develop** custom agents for specific use cases
4. **Troubleshoot** common issues and optimize performance
5. **Integrate** Hive Mind with external systems
6. **Monitor** system health and respond to incidents

### Training Pathways

#### Path 1: Infrastructure Operator
- Duration: 2 weeks
- Focus: System operation, monitoring, basic troubleshooting
- Prerequisites: Linux administration, basic networking

#### Path 2: Developer
- Duration: 4 weeks
- Focus: Agent development, integration, customization
- Prerequisites: JavaScript/TypeScript, Node.js, API development

#### Path 3: System Architect
- Duration: 6 weeks
- Focus: Architecture, scaling, security design
- Prerequisites: Experience with distributed systems, DevOps

### Training Methods

1. **Self-Paced Learning**: Online materials and exercises
2. **Instructor-Led**: Virtual classroom sessions
3. **Hands-On Labs**: Practical exercises and simulations
4. **Mentorship**: Pair programming with experienced team members
5. **Case Studies**: Real-world scenarios and examples

---

## Getting Started

### Prerequisites

#### Technical Requirements
- **Hardware**: 8GB+ RAM, 4+ CPU cores, 50GB+ disk space
- **Software**: Node.js 20+, Docker, Git
- **Network**: Internet access for downloading dependencies
- **IDE**: VS Code with recommended extensions

#### Knowledge Requirements
- **Linux**: Basic command line proficiency
- **JavaScript**: ES6+ syntax, async/await
- **APIs**: RESTful web services basics
- **Networking**: TCP/IP, HTTP/HTTPS fundamentals

### Environment Setup

#### 1. Development Environment
```bash
# Clone repository
git clone https://github.com/ruvnet/agl-hostman.git
cd agl-hostman

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
npm install

# Configure environment
cp .env.example .env
nano .env
```

#### 2. Development Tools
```json
// .vscode/settings.json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll.eslint": true
  },
  "typescript.preferences.preferTypeOnlyAutoImports": true,
  "eslint.validate": ["javascript", "typescript"]
}
```

#### 3. Testing Environment
```bash
# Install test tools
npm install -g jest typescript ts-node

# Run initial diagnostics
npm run test:diagnostics

# Verify environment
npm run verify:env
```

### Basic Concepts

#### Hive Mind Architecture
```
┌─────────────────────────────────────────────────────────────┐
│                    Queen Node                                │
│                (Coordinator & Control)                       │
└─────────────────────────────────────────────────────────────┘
                          │
    ┌─────────────────────┼─────────────────────┐
    ▼                     ▼                     ▼
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│ Worker 1    │   │ Worker 2    │   │ Worker 3    │
│ (Research)  │   │ (Coder)     │   │ (Tester)    │
└─────────────┘   └─────────────┘   └─────────────┘
```

#### Key Terms
- **Queen Node**: Central coordinator for task distribution and consensus
- **Worker Agent**: Specialized AI agent for specific tasks
- **Task**: Unit of work assigned to agents
- **Consensus**: Agreement mechanism for multi-agent results
- **Memory Store**: Persistent storage for shared knowledge

---

## Core Concepts

### 1. Architecture Overview

#### Master-Worker Pattern
The Hive Mind system uses a master-worker architecture where:

1. **Queen Node**: Coordinates all activities, distributes tasks, and consolidates results
2. **Worker Agents**: Execute specific tasks and report back
3. **Message Queue**: Handles communication between components
4. **Memory Store**: Maintains state across sessions

```javascript
// Understanding the Architecture
class QueenNode {
  constructor() {
    this.workers = [];
    this.taskQueue = [];
    this.memoryStore = new MemoryStore();
  }

  async distributeTask(task) {
    // 1. Decompose task into sub-tasks
    const subTasks = this.decomposeTask(task);

    // 2. Assign sub-tasks to workers
    const assignments = await this.assignSubTasks(subTasks);

    // 3. Wait for results
    const results = await this.waitForResults(assignments);

    // 4. Consolidate results
    return this.consolidateResults(results);
  }
}
```

#### Communication Flow
1. Task creation with Queen node
2. Task distribution to workers
3. Worker execution and progress reporting
4. Result collection and consensus building
5. Final result delivery

### 2. Agent Types and Capabilities

#### Agent Specializations
| Agent Type | Primary Role | Key Skills | Use Cases |
|------------|-------------|------------|-----------|
| **Researcher** | Information gathering | Web search, document analysis | Market research, technical investigation |
| **Coder** | Implementation | Programming, debugging, testing | Feature development, bug fixes |
| **Tester** | Quality assurance | Test creation, performance testing | Regression testing, validation |
| **Analyst** | Data analysis | Statistics, visualization | Performance analysis, reporting |
| **Coordinator** | Task management | Resource allocation, monitoring | Multi-agent coordination |

#### Agent Development Patterns
```javascript
// Agent Interface
class Agent {
  constructor(id, capabilities) {
    this.id = id;
    this.capabilities = capabilities;
    this.status = 'idle';
  }

  async execute(task) {
    this.status = 'working';

    // Validate task matches capabilities
    if (!this.canHandle(task)) {
      throw new Error('Task not supported');
    }

    // Execute task
    const result = await this.processTask(task);

    this.status = 'idle';
    return result;
  }

  canHandle(task) {
    return task.type in this.capabilities;
  }
}
```

### 3. Task Management

#### Task Lifecycle
1. **Creation**: Task defined with parameters and requirements
2. **Distribution**: Queen breaks down and assigns to workers
3. **Execution**: Workers perform assigned tasks
4. **Consensus**: Results compared and verified
5. **Completion**: Final result delivered

#### Task Types
```javascript
// Task Definition
const taskTypes = {
  RESEARCH: {
    name: 'research',
    input: { query: String, sources: Array },
    output: { results: Array, confidence: Number }
  },

  CODE: {
    name: 'code',
    input: { requirements: Object, context: Object },
    output: { code: String, tests: String, explanation: String }
  },

  TEST: {
    name: 'test',
    input: { target: String, criteria: Object },
    output: { results: Object, coverage: Number, issues: Array }
  },

  ANALYZE: {
    name: 'analyze',
    input: { data: Object, parameters: Object },
    output: { insights: Object, metrics: Object, recommendations: Array }
  }
};
```

#### Task Management API
```bash
# Create task
curl -X POST http://localhost:8080/api/tasks \
  -H "Content-Type: application/json" \
  -d '{
    "type": "research",
    "description": "Analyze cloud migration options",
    "priority": "high",
    "parameters": {
      "query": "best cloud migration strategies",
      "sources": ["web", "documents"]
    }
  }'

# Monitor progress
curl http://localhost:8080/api/tasks/123/progress

# Get results
curl http://localhost:8080/api/tasks/123/result
```

### 4. Memory and State Management

#### Memory Architecture
```javascript
// Memory Store Implementation
class MemoryStore {
  constructor() {
    this.cache = new Map();
    this.database = new Database('memory.db');
    this.archive = new Archive('archive/');
  }

  // Three-tier storage
  async get(key) {
    // 1. Check cache
    if (this.cache.has(key)) {
      return this.cache.get(key);
    }

    // 2. Check database
    const dbResult = await this.database.get(key);
    if (dbResult) {
      this.cache.set(key, dbResult);
      return dbResult;
    }

    // 3. Check archive
    return this.archive.get(key);
  }

  async set(key, value, options = {}) {
    this.cache.set(key, value);
    await this.database.set(key, value);

    if (!options.tempOnly) {
      await this.archive.set(key, value);
    }
  }
}
```

#### State Management Patterns
```javascript
// State Context
class StateContext {
  constructor() {
    this.currentSession = null;
    this.activeTasks = new Map();
    this.workerStates = new Map();
    this.memory = new MemoryStore();
  }

  async saveState(key, state) {
    await this.memory.set(`state:${key}`, state);
  }

  async loadState(key) {
    return this.memory.get(`state:${key}`);
  }

  async createSession(sessionId) {
    this.currentSession = {
      id: sessionId,
      startTime: Date.now(),
      tasks: [],
      agents: []
    };

    await this.saveState('currentSession', this.currentSession);
  }
}
```

---

## Agent Development

### Creating Custom Agents

#### Agent Development Workflow
1. **Define Agent Type**: Determine role and capabilities
2. **Implement Agent Class**: Extend base Agent class
3. **Add Capabilities**: Define supported task types
4. **Implement Logic**: Write task processing methods
5. **Test Agent**: Validate functionality and performance
6. **Register Agent**: Add to Hive Mind system

#### Basic Agent Template
```javascript
// Basic Agent Template
class CustomAgent extends Agent {
  constructor(id) {
    super(id, {
      research: 1,  // Capability level for research tasks
      code: 1,      // Capability level for code tasks
      test: 0       // Not capable of testing
    });

    this.initialize();
  }

  async initialize() {
    // Initialize agent-specific resources
    this.resources = await this.loadResources();
    this.cache = new Map();
  }

  async processTask(task) {
    switch (task.type) {
      case 'research':
        return await this.handleResearch(task);
      case 'code':
        return await this.handleCode(task);
      default:
        throw new Error(`Unsupported task type: ${task.type}`);
    }
  }

  async handleResearch(task) {
    // Implement research logic
    const results = await this.performResearch(task.parameters);

    return {
      results,
      confidence: this.calculateConfidence(results),
      metadata: {
        agentId: this.id,
        timestamp: Date.now(),
        sources: results.sources
      }
    };
  }

  async handleCode(task) {
    // Implement code generation logic
    const code = await this.generateCode(task.parameters);

    return {
      code,
      explanation: this.explainCode(code),
      tests: await this.generateTests(code)
    };
  }
}
```

### Advanced Agent Features

#### 1. Resource Management
```javascript
// Resource Management
class ResourceManager {
  constructor(agent) {
    this.agent = agent;
    this.resources = new Map();
    this.limits = {
      memory: '2GB',
      cpu: '1 core',
      network: '100 Mbps'
    };
  }

  async allocateResources(task) {
    // Check resource availability
    if (!this.checkAvailability(task)) {
      throw new Error('Insufficient resources');
    }

    // Allocate resources
    const allocation = {
      id: task.id,
      resources: this.calculateNeeded(task),
      timestamp: Date.now()
    };

    this.resources.set(task.id, allocation);
    return allocation;
  }

  async releaseResources(taskId) {
    const allocation = this.resources.get(taskId);
    if (allocation) {
      // Clean up resources
      await this.cleanup(allocation);
      this.resources.delete(taskId);
    }
  }
}
```

#### 2. Error Handling and Recovery
```javascript
// Advanced Error Handling
class ErrorHandler {
  constructor(agent) {
    this.agent = agent;
    this.retryStrategies = new Map();
    this.fallbackHandlers = new Map();
  }

  async executeWithRetry(task, maxRetries = 3) {
    let attempt = 0;
    let lastError;

    while (attempt < maxRetries) {
      try {
        const result = await this.agent.processTask(task);
        return result;
      } catch (error) {
        lastError = error;
        attempt++;

        // Log error
        this.logError(task, error, attempt);

        // Check if we should retry
        if (!this.shouldRetry(error, attempt)) {
          break;
        }

        // Wait before retry
        await this.waitBeforeRetry(attempt);
      }
    }

    // Try fallback
    if (this.fallbackHandlers.has(task.type)) {
      return this.fallbackHandlers.get(task.type)(task);
    }

    throw lastError;
  }

  shouldRetry(error, attempt) {
    // Retry on network errors, temporary failures
    if (error.code === 'NETWORK_ERROR' ||
        error.code === 'TIMEOUT' ||
        error.code === 'RESOURCE_EXHAUSTED') {
      return true;
    }

    // Don't retry on validation errors
    if (error.code === 'VALIDATION_ERROR') {
      return false;
    }

    return attempt < 3;
  }
}
```

#### 3. Performance Optimization
```javascript
// Performance Optimization
class PerformanceOptimizer {
  constructor(agent) {
    this.agent = agent;
    this.metrics = new MetricsCollector();
    this.cache = new LRUCache(1000);
    this.batchProcessor = new BatchProcessor();
  }

  async optimizeTaskExecution(task) {
    // Check cache first
    const cacheKey = this.generateCacheKey(task);
    if (this.cache.has(cacheKey)) {
      this.metrics.increment('cache.hits');
      return this.cache.get(cacheKey);
    }

    // Batch processing if possible
    if (this.canBatch(task)) {
      return this.batchProcessor.process([task]);
    }

    // Regular execution with timeout
    const timeout = this.calculateTimeout(task);
    const result = await this.executeWithTimeout(task, timeout);

    // Cache result
    this.cache.set(cacheKey, result);
    this.metrics.increment('cache.misses');

    return result;
  }

  executeWithTimeout(task, timeout) {
    return Promise.race([
      this.agent.processTask(task),
      new Promise((_, reject) =>
        setTimeout(() => reject(new Error('Timeout')), timeout)
      )
    ]);
  }
}
```

### Testing Agents

#### Unit Testing
```javascript
// Agent Unit Tests
describe('CustomAgent', () => {
  let agent;
  let mockResources;

  beforeEach(() => {
    mockResources = new ResourceManager();
    agent = new CustomAgent('test-agent');
    agent.resources = mockResources;
  });

  test('should handle research task', async () => {
    const task = {
      type: 'research',
      parameters: {
        query: 'test query',
        sources: ['web']
      }
    };

    const result = await agent.execute(task);

    expect(result).toHaveProperty('results');
    expect(result).toHaveProperty('confidence');
    expect(result.confidence).toBeGreaterThan(0);
    expect(result.confidence).toBeLessThanOrEqual(1);
  });

  test('should throw error for unsupported task', async () => {
    const task = {
      type: 'unsupported',
      parameters: {}
    };

    await expect(agent.execute(task)).rejects.toThrow('Unsupported task type');
  });
});
```

#### Integration Testing
```javascript
// Integration Tests
describe('Agent Integration', () => {
  let queenNode;
  let workerAgent;

  beforeEach(async () => {
    queenNode = new QueenNode();
    workerAgent = new CustomAgent('integration-test');
    await queenNode.addWorker(workerAgent);
  });

  test('should distribute and execute task', async () => {
    const task = {
      type: 'research',
      description: 'Test research task',
      priority: 'medium'
    };

    const result = await queenNode.distributeTask(task);

    expect(result).toBeDefined();
    expect(result).toHaveProperty('consensus');
    expect(result.consensus).toBeGreaterThan(0.5);
  });
});
```

#### Performance Testing
```javascript
// Performance Testing
describe('Agent Performance', () => {
  test('should handle concurrent tasks efficiently', async () => {
    const agent = new CustomAgent('performance-test');
    const tasks = Array.from({ length: 10 }, (_, i) => ({
      type: 'research',
      parameters: { query: `test query ${i}` }
    }));

    const startTime = Date.now();
    const results = await Promise.all(
      tasks.map(task => agent.execute(task))
    );
    const endTime = Date.now();

    const duration = endTime - startTime;
    const avgTime = duration / tasks.length;

    expect(results).toHaveLength(tasks.length);
    expect(avgTime).toBeLessThan(5000); // 5 seconds average
  });
});
```

---

## Operations Training

### System Installation

#### Production Deployment
```bash
#!/bin/bash
# install-hive-mind.sh

# Install dependencies
apt-get update
apt-get install -y nodejs npm docker.io docker-compose

# Create service user
adduser --system --group hive-mind
mkdir -p /opt/hive-mind
chown hive-mind:hive-mind /opt/hive-mind

# Deploy application
cd /opt/hive-mind
git clone https://github.com/ruvnet/agl-hostman.git .
npm install --production

# Configure service
cat > /etc/systemd/system/hive-mind.service << EOF
[Unit]
Description=Hive Mind Queen Node
After=network.target

[Service]
Type=simple
User=hive-mind
WorkingDirectory=/opt/hive-mind
ExecStart=/usr/bin/node queen.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable service
systemctl daemon-reload
systemctl enable hive-mind
systemctl start hive-mind
```

#### Configuration Management
```yaml
# production.yaml
hive_mind:
  queen:
    host: "0.0.0.0"
    port: 8080
    workers: 8
    memory: "4GB"

  database:
    url: "sqlite:///data/hive-mind.db"
    backup: true

  security:
    encryption_key: "${ENCRYPTION_KEY}"
    ssl_cert: "/etc/hive-mind/cert.pem"
    ssl_key: "/etc/hive-mind/key.pem"

  monitoring:
    metrics_enabled: true
    grafana_url: "http://monitoring:3000"

  logging:
    level: "info"
    file: "/var/log/hive-mind/queen.log"
    rotate: true
```

### Day-to-Day Operations

#### Monitoring System Health
```bash
#!/bin/bash
# monitor-hive-mind.sh

echo "=== Hive Mind Health Check ==="
date

# Check Queen node
echo "Queen Node:"
curl -s http://localhost:8080/api/health | jq '.status'

# Check worker count
echo "Active Workers:"
curl -s http://localhost:8080/api/agents | jq '.[] | select(.status == "active") | .id' | wc -l

# Check task queue
echo "Task Queue Length:"
curl -s http://localhost:8080/api/metrics | jq '.task_queue_length'

# Check memory usage
echo "Memory Usage:"
free -h | grep hive-mind

# Check disk space
echo "Disk Space:"
df -h /data/hive-mind

# Check recent errors
echo "Recent Errors:"
tail -n 20 /var/log/hive-mind/queen.log | grep -E "(ERROR|CRITICAL)"
```

#### Task Management Operations
```bash
#!/bin/bash
# task-operations.sh

# Create priority task
create_task() {
  local priority=$1
  local description=$2

  curl -X POST http://localhost:8080/api/tasks \
    -H "Content-Type: application/json" \
    -d "{
      \"description\": \"$description\",
      \"priority\": \"$priority\",
      \"type\": \"analysis\"
    }"
}

# Monitor task progress
monitor_task() {
  local task_id=$1

  while true; do
    status=$(curl -s http://localhost:8080/api/tasks/$task_id/status | jq -r '.status')
    echo "Task $task_id: $status"

    if [ "$status" = "completed" ] || [ "$status" = "failed" ]; then
      break
    fi

    sleep 10
  done
}

# Cancel task
cancel_task() {
  local task_id=$1
  curl -X DELETE http://localhost:8080/api/tasks/$task_id
}
```

### Backup and Recovery

#### Backup Strategy
```bash
#!/bin/bash
# backup-hive-mind.sh

BACKUP_DIR="/backups/hive-mind/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

echo "Starting backup: $BACKUP_DIR"

# Backup configuration
cp /etc/hive-mind/* $BACKUP_DIR/config/

# Backup database
sqlite3 /data/hive-mind/memory.db ".backup $BACKUP_DIR/memory.db"

# Backup memory store
rsync -av /data/hive-mind/memory/ $BACKUP_DIR/memory/

# Backup logs (last 7 days)
find /var/log/hive-mind -name "*.log" -mtime -7 -exec cp {} $BACKUP_DIR/ \;

# Verify backup
if [ $? -eq 0 ]; then
  echo "Backup successful: $BACKUP_DIR"

  # Create backup manifest
  cat > $BACKUP_DIR/manifest.txt << EOF
Backup Date: $(date)
Version: 1.0
Files:
- configuration: $(find $BACKUP_DIR/config -type f | wc -l) files
- database: $(ls -la $BACKUP_DIR/memory.db)
- memory store: $(du -sh $BACKUP_DIR/memory | cut -f1)
- logs: $(find $BACKUP_DIR -name "*.log" | wc -l) files
EOF
else
  echo "Backup failed!"
  exit 1
fi
```

#### Recovery Procedure
```bash
#!/bin/bash
# restore-hive-mind.sh

BACKUP_DATE=$1
BACKUP_DIR="/backups/hive-mind/$BACKUP_DATE"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup directory not found: $BACKUP_DIR"
  exit 1
fi

echo "Restoring from: $BACKUP_DIR"

# Stop services
systemctl stop hive-mind

# Restore configuration
cp -r $BACKUP_DIR/config/* /etc/hive-mind/

# Restore database
cp $BACKUP_DIR/memory.db /data/hive-mind/

# Restore memory store
rsync -av $BACKUP_DIR/memory/ /data/hive-mind/memory/

# Restore permissions
chown -R hive-mind:hive-mind /data/hive-mind
chown -R hive-mind:hive-mind /etc/hive-mind

# Start services
systemctl start hive-mind

# Verify recovery
sleep 30
if curl -s http://localhost:8080/api/health | jq -r '.status' == 'healthy'; then
  echo "✓ Recovery successful"
else
  echo "✗ Recovery failed - check logs"
  tail -n 50 /var/log/hive-mind/queen.log
fi
```

---

## Troubleshooting Training

### Common Issues and Solutions

#### 1. Worker Node Issues

**Symptom**: Workers not connecting to Queen
```bash
#!/bin/bash
# troubleshoot-workers.sh

echo "=== Worker Connection Issues ==="

# Check Queen connectivity
echo "1. Testing Queen connectivity:"
curl -s http://localhost:8080/api/health | jq .

# Check worker processes
echo -e "\n2. Worker processes:"
ps aux | grep hive-mind | grep -v grep

# Check worker logs
echo -e "\n3. Worker logs:"
for log in /var/log/hive-mind/worker*.log; do
  echo "--- $log ---"
  tail -n 5 $log
done

# Check network connections
echo -e "\n4. Network connections:"
netstat -tuln | grep :8080
ss -tuln | grep :5555  # ZeroMQ port
```

**Solution**:
```bash
# Restart workers
systemctl restart hive-mind-workers

# Check firewall
ufw status
ufw allow 8080
ufw allow 5555

# Verify configuration
cat /etc/hive-mind/queen.conf | grep workers
```

#### 2. Memory Issues

**Symptom**: Memory usage too high
```bash
#!/bin/bash
# troubleshoot-memory.sh

echo "=== Memory Issues ==="

# Check memory usage
echo "1. Memory usage:"
free -h
ps aux | grep hive-mind | awk '{print $4 " " $11}'

# Check memory store size
echo -e "\n2. Memory store size:"
du -sh /data/hive-mind/memory*

# Check cache usage
echo -e "\n3. Cache usage:"
curl -s http://localhost:8080/api/memory/stats | jq .

# Check database size
echo -e "\n4. Database size:"
sqlite3 /data/hive-mind/memory.db "SELECT name, COUNT(*) as count FROM sqlite_master WHERE type='table';"
```

**Solution**:
```bash
# Clear cache
curl -X POST http://localhost:8080/api/memory/cache/clear

# Compress database
sqlite3 /data/hive-mind/memory.db "VACUUM;"

# Reduce cache size
export HIVE_MIND_CACHE_SIZE=1GB
systemctl restart hive-mind
```

#### 3. Task Queue Issues

**Symptom**: Tasks not processing or queue growing
```bash
#!/bin/bash
# troubleshoot-queue.sh

echo "=== Task Queue Issues ==="

# Check queue status
echo "1. Queue status:"
curl -s http://localhost:8080/api/metrics | jq '.task_queue_length, .task_completion_rate'

# Check stuck tasks
echo -e "\n2. Stuck tasks:"
curl -s http://localhost:8080/api/tasks?status=running | jq '.[] | {id, started_at}'

# Check error rates
echo -e "\n3. Error rates:"
curl -s http://localhost:8080/api/metrics | jq '.task_error_rate'

# Check worker capacity
echo -e "\n4. Worker capacity:"
curl -s http://localhost:8080/api/agents | jq '.[] | {id, status, tasks}'
```

**Solution**:
```bash
# Clear stuck tasks
curl -X POST http://localhost:8080/api/tasks/clear-stuck

# Scale up workers
./scripts/hive-mind/scale-workers.sh --add=2

# Check for task deadlock
curl -X POST http://localhost:8080/api/tasks/restart-deadlock
```

### Performance Troubleshooting

#### Performance Analysis
```bash
#!/bin/bash
# performance-analysis.sh

echo "=== Performance Analysis ==="

# System performance
echo "1. System metrics:"
top -bn1 | grep "Cpu(s)"
iostat -x 1 3

# Application metrics
echo -e "\n2. Application metrics:"
curl -s http://localhost:8080/api/metrics | jq '.task_duration_p95, .response_time'

# Worker performance
echo -e "\n3. Worker performance:"
for worker in {1..8}; do
  echo "Worker $worker:"
  curl -s http://localhost:8080/api/agents/$worker/metrics | jq '.cpu_usage, .memory_usage, .tasks_completed'
done

# Database performance
echo -e "\n4. Database performance:"
sqlite3 /data/hive-mind/memory.db "PRAGMA cache_size; PRAGMA journal_mode;"
```

#### Bottleneck Identification
```javascript
// Bottleneck Analysis Tool
class BottleneckAnalyzer {
  async identifyBottlenecks() {
    const metrics = await this.collectMetrics();
    const bottlenecks = [];

    // CPU bottlenecks
    if (metrics.cpu.usage > 80) {
      bottlenecks.push({
        type: 'cpu',
        severity: 'high',
        impact: 'reduces throughput',
        recommendation: 'scale horizontally or optimize CPU-intensive tasks'
      });
    }

    // Memory bottlenecks
    if (metrics.memory.usage > 85) {
      bottlenecks.push({
        type: 'memory',
        severity: 'critical',
        impact: 'risk of out-of-memory errors',
        recommendation: 'increase memory, optimize memory usage, enable compression'
      });
    }

    // Network bottlenecks
    if (metrics.network.latency > 100) {
      bottlenecks.push({
        type: 'network',
        severity: 'medium',
        impact: 'increases response time',
        recommendation: 'optimize network topology, use compression'
      });
    }

    // Database bottlenecks
    if (metrics.database.queries > 1000) {
      bottlenecks.push({
        type: 'database',
        severity: 'medium',
        impact: 'slows query performance',
        recommendation: 'add indexes, optimize queries, consider caching'
      });
    }

    return bottlenecks;
  }
}
```

### Emergency Response

#### Emergency Shutdown
```bash
#!/bin/bash
# emergency-shutdown.sh

echo "=== Emergency Shutdown ==="

# 1. Pause new tasks
curl -X POST http://localhost:8080/api/system/pause

# 2. Wait for current tasks to finish or kill
echo "Waiting 60 seconds for tasks to complete..."
sleep 60

# 3. Force stop if needed
pkill -f hive-mind

# 4. Backup current state
./backup-hive-mind.sh emergency

# 5. Check status
echo "Checking system status:"
systemctl status hive-mind

# 6. Report
echo "Shutdown completed. Check logs for details."
```

#### System Recovery
```bash
#!/bin/bash
# emergency-recovery.sh

BACKUP_TYPE=$1
BACKUP_DATE=${2:-latest}

echo "=== Emergency Recovery ==="

# 1. Assess damage
echo "Assessing system damage..."
ls -la /data/hive-mind/
cat /var/log/syslog | grep -E "(ERROR|CRITICAL|FATAL)"

# 2. Select backup
if [ "$BACKUP_TYPE" = "latest" ]; then
  BACKUP_DIR=$(ls -t /backups/hive-mind | head -1)
else
  BACKUP_DIR="/backups/hive-mind/$BACKUP_DATE"
fi

# 3. Restore from backup
echo "Restoring from: $BACKUP_DIR"
./restore-hive-mind.sh $BACKUP_DATE

# 4. Verify recovery
echo "Verifying recovery..."
curl -s http://localhost:8080/api/health | jq -r '.status' == 'healthy'

# 5. Resume operations
curl -X POST http://localhost:8080/api/system/resume

echo "Recovery completed."
```

---

## Advanced Topics

### 1. Custom Agent Development

#### Creating Domain-Specific Agents
```javascript
// Domain-Specific Agent Example: Security Analyst
class SecurityAgent extends Agent {
  constructor() {
    super('security-analyst', {
      vulnerability_scan: 1,
      compliance_check: 1,
      threat_analysis: 1
    });

    this.scanners = new Map();
    this.rulesEngine = new RulesEngine();
  }

  async initialize() {
    // Load security scanners
    await this.loadScanners();

    // Load compliance rules
    await this.loadComplianceRules();
  }

  async processTask(task) {
    switch (task.type) {
      case 'vulnerability_scan':
        return this.performVulnerabilityScan(task);
      case 'compliance_check':
        return this.performComplianceCheck(task);
      case 'threat_analysis':
        return this.analyzeThreats(task);
      default:
        throw new Error('Unsupported security task');
    }
  }

  async performVulnerabilityScan(task) {
    const { target, scanTypes } = task.parameters;
    const results = [];

    // Run multiple scanners
    for (const scannerType of scanTypes) {
      const scanner = this.scanners.get(scannerType);
      const scanResult = await scanner.scan(target);
      results.push(scanResult);
    }

    // Consolidate results
    return {
      severity: this.calculateSeverity(results),
      vulnerabilities: this.formatVulnerabilities(results),
      remediation: this.generateRemediation(results)
    };
  }
}
```

#### Agent Patterns and Best Practices
```javascript
// Agent Template Factory
class AgentFactory {
  static create(agentType, config) {
    const AgentClass = this.getAgentClass(agentType);
    return new AgentClass(config);
  }

  static getAgentClass(agentType) {
    const classes = {
      'research': ResearchAgent,
      'code': CodeAgent,
      'security': SecurityAgent,
      'analytics': AnalyticsAgent
    };

    if (!classes[agentType]) {
      throw new Error(`Unknown agent type: ${agentType}`);
    }

    return classes[agentType];
  }
}

// Agent Lifecycle Management
class AgentLifecycle {
  constructor(agent) {
    this.agent = agent;
    this.state = 'created';
  }

  async start() {
    this.state = 'starting';
    try {
      await this.agent.initialize();
      this.state = 'running';
    } catch (error) {
      this.state = 'failed';
      throw error;
    }
  }

  async stop() {
    this.state = 'stopping';
    try {
      await this.agent.cleanup();
      this.state = 'stopped';
    } catch (error) {
      this.state = 'error';
      throw error;
    }
  }

  async restart() {
    await this.stop();
    await this.start();
  }
}
```

### 2. System Integration

#### Integrating with External APIs
```javascript
// External API Integration Example
class ExternalAPIIntegration {
  constructor(config) {
    this.endpoints = config.endpoints;
    this.authManager = new AuthManager(config.auth);
    this.rateLimiter = new RateLimiter(config.rateLimit);
  }

  async fetchData(service, params) {
    // Check rate limits
    await this.rateLimiter.check(service);

    // Get authentication
    const auth = await this.authManager.getAuth(service);

    // Make API call
    const endpoint = this.endpoints[service];
    const response = await fetch(endpoint.url, {
      method: endpoint.method,
      headers: {
        ...endpoint.headers,
        Authorization: auth
      },
      body: JSON.stringify(params)
    });

    if (!response.ok) {
      throw new Error(`API error: ${response.status}`);
    }

    return response.json();
  }
}

// Real-time Data Integration
class RealTimeIntegration {
  constructor() {
    this.subscribers = new Map();
    this.eventBus = new EventBus();
  }

  subscribe(service, event, handler) {
    if (!this.subscribers.has(service)) {
      this.subscribers.set(service, new Map());
    }

    const serviceSubscribers = this.subscribers.get(service);
    serviceSubscribers.set(event, handler);

    // Start listening to real-time updates
    this.startListening(service, event);
  }

  startListening(service, event) {
    const ws = new WebSocket(this.getWebSocketUrl(service, event));

    ws.onmessage = (data) => {
      const payload = JSON.parse(data);
      this.eventBus.emit(event, payload);
    };

    ws.onclose = () => {
      // Reconnect with backoff
      setTimeout(() => this.startListening(service, event), 5000);
    };
  }
}
```

#### Message Queue Integration
```javascript
// RabbitMQ Integration
class RabbitMQIntegration {
  constructor(config) {
    this.connection = null;
    this.channels = new Map();
    this.config = config;
  }

  async connect() {
    this.connection = await amqp.connect(this.config.url);
  }

  async createQueue(queueName, options = {}) {
    const channel = await this.connection.createChannel();
    await channel.assertQueue(queueName, options);

    this.channels.set(queueName, channel);
    return channel;
  }

  async publish(queueName, message, options = {}) {
    const channel = this.channels.get(queueName);
    if (!channel) {
      throw new Error(`Queue ${queueName} not found`);
    }

    channel.sendToQueue(queueName, Buffer.from(JSON.stringify(message)), options);
  }

  async consume(queueName, handler, options = {}) {
    const channel = this.channels.get(queueName);
    if (!channel) {
      throw new Error(`Queue ${queueName} not found`);
    }

    channel.consume(queueName, async (msg) => {
      const message = JSON.parse(msg.content.toString());
      await handler(message);
      channel.ack(msg);
    }, options);
  }
}
```

### 3. Performance Optimization

#### Caching Strategies
```javascript
// Multi-level Caching
class CacheManager {
  constructor() {
    this.l1Cache = new LRUCache(1000);  // In-memory
    this.l2Cache = new RedisCache();     // Redis
    this.l3Cache = new DiskCache();      // Disk
  }

  async get(key) {
    // L1 cache (fastest)
    const l1Result = this.l1Cache.get(key);
    if (l1Result) {
      return l1Result;
    }

    // L2 cache
    const l2Result = await this.l2Cache.get(key);
    if (l2Result) {
      this.l1Cache.set(key, l2Result);
      return l2Result;
    }

    // L3 cache
    const l3Result = await this.l3Cache.get(key);
    if (l3Result) {
      this.l2Cache.set(key, l3Result, { ttl: 3600 });
      this.l1Cache.set(key, l3Result);
      return l3Result;
    }

    return null;
  }

  async set(key, value, options = {}) {
    this.l1Cache.set(key, value);

    if (options.ttl) {
      await this.l2Cache.set(key, value, { ttl: options.ttl });
      await this.l3Cache.set(key, value, { ttl: options.ttl * 10 });
    } else {
      await this.l2Cache.set(key, value);
      await this.l3Cache.set(key, value);
    }
  }
}
```

#### Load Balancing
```javascript
// Smart Load Balancer
class LoadBalancer {
  constructor() {
    this.workers = new Map();
    this.healthChecker = new HealthChecker();
    this.strategy = 'least-connections';
  }

  async addWorker(worker) {
    this.workers.set(worker.id, {
      instance: worker,
      connections: 0,
      load: 0,
      lastHealthCheck: Date.now()
    });

    // Start health checking
    this.healthChecker.start(worker.id);
  }

  async assignTask(task) {
    const availableWorkers = this.getAvailableWorkers();

    if (availableWorkers.length === 0) {
      throw new Error('No available workers');
    }

    // Select worker based on strategy
    const selected = this.selectWorker(availableWorkers, task);
    selected.connections++;
    selected.load++;

    return selected.instance;
  }

  selectWorker(workers, task) {
    switch (this.strategy) {
      case 'round-robin':
        return workers[0];

      case 'least-connections':
        return workers.reduce((min, current) =>
          current.connections < min.connections ? current : min
        );

      case 'weighted':
        return this.selectByWeight(workers);

      default:
        return workers[0];
    }
  }
}
```

#### Database Optimization
```javascript
// Database Connection Pool
class ConnectionPool {
  constructor(config) {
    this.pool = [];
    this.maxSize = config.maxSize;
    this.minSize = config.minSize;
    this.idleTimeout = config.idleTimeout;
    this.lastCleanup = Date.now();
  }

  async getConnection() {
    // Clean up idle connections
    await this.cleanupIdleConnections();

    // Try to get connection from pool
    if (this.pool.length > 0) {
      return this.pool.pop();
    }

    // Create new connection if under max size
    if (this.pool.length < this.maxSize) {
      return this.createConnection();
    }

    // Wait for available connection
    return this.waitForConnection();
  }

  async releaseConnection(connection) {
    connection.lastUsed = Date.now();
    this.pool.push(connection);
  }

  async cleanupIdleConnections() {
    const now = Date.now();
    if (now - this.lastCleanup < this.idleTimeout) {
      return;
    }

    this.pool = this.pool.filter(conn => {
      if (now - conn.lastUsed > this.idleTimeout && this.pool.length > this.minSize) {
        conn.close();
        return false;
      }
      return true;
    });

    this.lastCleanup = now;
  }
}
```

### 4. Security Hardening

#### Advanced Authentication
```javascript
// Multi-Factor Authentication
class MFAProvider {
  constructor() {
    this.totp = new TOTP();
    this.webauthn = new WebAuthn();
    this.sms = new SMSProvider();
  }

  async verify(user, token, factors) {
    const verifiedFactors = new Set();
    const requiredFactors = await this.getRequiredFactors(user);

    for (const factor of factors) {
      switch (factor.type) {
        case 'password':
          if (await this.verifyPassword(user, factor.value)) {
            verifiedFactors.add('password');
          }
          break;

        case 'totp':
          if (await this.totp.verify(user.totpSecret, factor.value)) {
            verifiedFactors.add('totp');
          }
          break;

        case 'webauthn':
          if (await this.webauthn.verify(user.webauthnCredential, factor.value)) {
            verifiedFactors.add('webauthn');
          }
          break;

        case 'sms':
          if (await this.sms.verify(user.phone, factor.value)) {
            verifiedFactors.add('sms');
          }
          break;
      }
    }

    return {
      verified: verifiedFactors.size >= requiredFactors,
      factors: Array.from(verifiedFactors)
    };
  }
}
```

#### Security Monitoring
```javascript
// Security Event Monitor
class SecurityMonitor {
  constructor() {
    this.eventLog = [];
    this.alertRules = [];
    this.notificationService = new NotificationService();
  }

  addRule(rule) {
    this.alertRules.push(rule);
  }

  async logEvent(event) {
    this.eventLog.push({
      timestamp: Date.now(),
      ...event
    });

    // Check against alert rules
    for (const rule of this.alertRules) {
      if (rule.matches(event)) {
        await this.handleAlert(rule, event);
      }
    }
  }

  async handleAlert(rule, event) {
    const alert = {
      rule: rule.name,
      severity: rule.severity,
      event,
      timestamp: Date.now()
    };

    // Send notification
    await this.notificationService.sendAlert(alert);

    // Take action if critical
    if (rule.severity === 'critical') {
      await this.takeEmergencyAction(event);
    }
  }

  async takeEmergencyAction(event) {
    switch (event.type) {
      case 'brute_force':
        await this.blockIP(event.sourceIP);
        break;

      case 'data_breach':
        await this.revokeAllTokens();
        break;

      case 'malicious_behavior':
        await this.quarantineUser(event.userId);
        break;
    }
  }
}
```

---

## Certification

### Certification Levels

#### Level 1: Hive Mind Operator
**Prerequisites**: Basic Linux and networking knowledge
**Duration**: 2 weeks of training
**Topics**:
- System installation and configuration
- Basic monitoring and operations
- Common troubleshooting
- Backup and recovery

**Exam Requirements**:
- Install and configure Hive Mind system
- Perform routine maintenance tasks
- Troubleshoot common issues
- Restore from backup

**Certification Badge**: 🏅 Hive Mind Operator

#### Level 2: Hive Mind Developer
**Prerequisites**: Level 1 certification or equivalent experience
**Duration**: 4 weeks of training
**Topics**:
- Agent development and customization
- API integration
- Performance optimization
- Security implementation

**Exam Requirements**:
- Develop a custom agent
- Implement integration with external system
- Optimize performance of existing system
- Implement security features

**Certification Badge**: 🏅 Hive Mind Developer

#### Level 3: Hive Mind Architect
**Prerequisites**: Level 2 certification or equivalent experience
**Duration**: 6 weeks of training
**Topics**:
- System architecture design
- Scaling and optimization
- Security architecture
- Disaster recovery planning

**Exam Requirements**:
- Design scalable architecture for enterprise deployment
- Create security architecture document
- Implement disaster recovery solution
- Performance tuning for high-load scenarios

**Certification Badge**: 🏅 Hive Mind Architect

### Certification Process

#### Step 1: Training Completion
- Complete all required training modules
- Pass knowledge assessments
- Complete hands-on exercises

#### Step 2: Practical Assessment
- Scenario-based tasks
- Troubleshooting challenges
- Implementation exercises

#### Step 3: Written Exam
- Multiple choice questions
- Architecture design problems
- Security scenario analysis

#### Step 4: Practical Exam
- Live system configuration
- Agent development
- Troubleshooting under time pressure

### Certification Maintenance

#### Renewal Requirements
- Annual renewal required for all certifications
- Complete continuing education units (CEUs)
- Maintain active status on Hive Mind projects
- Stay current with latest updates

#### CEU Categories
- **Technical Training**: 1 CEU per hour
- **Community Contribution**: 2 CEUs per significant contribution
- **Conference Attendance**: 1 CEU per conference day
- **Publication**: 5 CEUs per published article

### Certification Benefits
- Recognition of expertise
- Access to advanced training
- Priority support
- Certification badge for professional profiles
- Access to exclusive community channels

---

## Resources

### Documentation
- [Official Documentation](https://docs.aglz.io/hive-mind)
- [API Reference](https://api-docs.aglz.io/hive-mind)
- [Architecture Guide](./architecture-decisions.md)
- [Operations Manual](./operations-manual.md)

### Code Examples
- [Agent Development Patterns](./examples/agent-patterns/)
- [Integration Examples](./examples/integrations/)
- [Performance Optimizations](./examples/optimizations/)
- [Security Implementations](./examples/security/)

### Community Resources
- [Community Forum](https://community.aglz.io)
- [GitHub Discussions](https://github.com/ruvnet/agl-hostman/discussions)
- [Slack Channel](https://slack.aglz.io)
- [Monthly Webinars](https://webinars.aglz.io)

### Tools and Utilities
- [Performance Profiler](./tools/performance-profiler.js)
- [Troubleshooting Toolkit](./tools/troubleshooting-kit.js)
- [Migration Helper](./tools/migration-helper.js)
- [Configuration Validator](./tools/config-validator.js)

### Templates and Examples
- [Agent Template](./templates/agent-template.js)
- [Configuration Template](./templates/config.yaml)
- [Deployment Template](./templates/deployment.yaml)
- [Monitoring Template](./templates/monitoring.yaml)

---

**Document Information**:
- **Created**: 2025-02-10
- **Version**: 1.0.0
- **Status**: Active Training Program
- **Next Update**: 2025-05-10
- **Maintainer**: AGL Training Team

*End of Training Materials*
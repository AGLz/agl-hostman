# Memory Injection Test Suite

Comprehensive test suite for Hive Mind memory coordination protocol injection testing.

## 📁 File Structure

```
tests/memory-injection/
├── validation-utils.js       # Validation utilities and checksum functions
├── test-single-agent.mjs     # Single agent memory operation tests
├── test-multiple-agents.mjs  # Multi-agent concurrent access tests
├── test-race-conditions.mjs  # Race condition detection tests
├── test-namespace-isolation.mjs  # Namespace isolation tests
├── test-corruption-detection.mjs # Data integrity tests
├── test-runner.mjs          # Main test runner
└── README.md                # This file
```

## 🚀 Usage

### Run All Tests
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
node tests/memory-injection/test-runner.mjs
```

### Run Specific Test Suite
```bash
node tests/memory-injection/test-runner.mjs single-agent
node tests/memory-injection/test-runner.mjs multiple-agents
node tests/memory-injection/test-runner.mjs race-conditions
node tests/memory-injection/test-runner.mjs namespace-isolation
node tests/memory-injection/test-runner.mjs corruption-detection
```

## 📊 Test Scenarios

### 1. Single Agent Tests (`test-single-agent.mjs`)
- ✅ Basic write operation
- ✅ Basic read operation
- ✅ Data persistence
- ✅ Update operation
- ✅ Delete operation

### 2. Multiple Agent Tests (`test-multiple-agents.mjs`)
- ✅ Concurrent writes to different keys
- ✅ Concurrent writes to same key (race condition)
- ✅ Concurrent reads from shared memory
- ✅ Agent coordination through memory
- ✅ Progress tracking across agents

### 3. Race Condition Tests (`test-race-conditions.mjs`)
- ⚠️ Rapid concurrent writes (100 operations)
- ⚠️ Write-read race conditions
- ⚠️ Counter increment race condition
- ✅ Consistency under load
- ✅ Memory ordering guarantees

### 4. Namespace Isolation Tests (`test-namespace-isolation.mjs`)
- ✅ Multiple namespace writes
- ✅ Data isolation between namespaces
- ✅ Cross-namespace access blocking
- ✅ Independent deletion
- ✅ Namespace performance comparison
- ✅ Namespace listing

### 5. Corruption Detection Tests (`test-corruption-detection.mjs`)
- ✅ Data integrity validation
- ✅ Corruption detection
- ✅ Memory structure validation
- ✅ Agent status validation
- ✅ Concurrent write corruption
- ✅ Corruption recovery

## 🧪 Memory Coordination Protocol

### Key Patterns
```javascript
// Agent status
swarm/[agent-id]/status
swarm/[agent-id]/progress
swarm/[agent-id]/waiting
swarm/[agent-id]/complete

// Shared components
swarm/shared/[component-name]
```

### Required Namespace
All memory operations MUST use `namespace: "coordination"`

### Standard Memory Write
```javascript
memory_usage({
  action: "store",
  key: "swarm/coder/status",
  namespace: "coordination",
  value: JSON.stringify({
    agent: "coder",
    status: "working",
    timestamp: Date.now(),
    tasks: ["task1", "task2"],
    progress: 50
  })
})
```

### Standard Memory Read
```javascript
memory_usage({
  action: "retrieve",
  key: "swarm/coder/status",
  namespace: "coordination"
})
```

## 📈 Test Output

Test runner generates comprehensive reports including:
- Overall statistics (pass/fail rate)
- Per-suite results
- Race conditions detected
- Validation summary
- Performance metrics (ops/sec)

Results are automatically saved to Hive Mind memory:
- `swarm/test-runner/results` - Complete test results
- `swarm/shared/test-results` - Shared results for other agents

## 🔧 Validation Utilities

The `MemoryValidator` class provides:
- Memory structure validation
- Agent status validation
- Checksum calculation for integrity
- Corruption detection
- Namespace isolation verification

## ⚠️ Known Limitations

1. **Counter Race Condition**: Due to lack of atomic operations, concurrent counter increments will lose updates. This is an expected behavior that demonstrates the need for atomic operations or locks.

2. **Memory Ordering**: Last-write-wins semantics mean order is not guaranteed without explicit sequencing.

3. **Cross-Namespace Access**: Currently, the implementation may allow cross-namespace reads in some scenarios. This test suite validates that isolation is properly enforced.

## 🎯 Success Criteria

- ✅ All single agent operations work correctly
- ✅ Multiple agents can coordinate without data loss
- ✅ Race conditions are properly detected
- ✅ Namespace isolation is enforced
- ✅ Data corruption is detected and recoverable

## 📝 Notes

- Tests use ESM modules (`.mjs` extension)
- Requires `mcp__claude-flow-alpha` MCP server to be running
- All timestamps are in milliseconds since epoch
- Checksums use simple hash algorithm (sufficient for testing)

## 🔗 Related Documentation

- `docs/CLAUDE-FLOW.md` - Claude Flow CLI and Hive Mind architecture
- `docs/ARCHON.md` - Archon MCP integration and memory coordination
- `CLAUDE.md` - Memory coordination protocol requirements

---

**Created by**: CODER agent (Hive Mind)
**Created**: 2025-12-30
**Version**: 1.0.0

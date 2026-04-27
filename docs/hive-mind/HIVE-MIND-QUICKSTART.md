# Hive Mind Quick Start Guide

> **TL;DR**: Run Hive Mind Worker Pool in 3 commands

## 🚀 Fastest Start (Local)

```bash
# 1. Install dependencies (first time only)
pnpm install

# 2. Run demo
./scripts/run-hive-mind.sh demo

# 3. Start interactive mode
./scripts/run-hive-mind.sh interactive
```

**Expected Output**:
```
✅ Spawned 4 agents in 75ms (parallel)
   Average: 18.75ms per agent
   Speedup: ~4x
📊 Dashboard Status: Active agents: 4
```

## 🐳 Docker Alternative

```bash
# Build and start
docker-compose -f docker/hive-mind/docker-compose.yml up -d

# Access interactive shell
docker exec -it agl-hive-mind node

# Run demo
docker exec -it agl-hive-mind node examples/hive-mind-parallel-agents.js
```

## 🎯 What You Get

- ✅ **15 Specialized Agent Types**: researcher, coder, analyst, tester, optimizer, security, devops, ml, etc.
- ✅ **4x-12x Performance**: Parallel agent spawning vs sequential
- ✅ **Real-time Monitoring**: CPU, memory, performance metrics
- ✅ **Production Ready**: Docker support, health checks, persistent volumes

## 📖 Key Commands

| Command | Description |
|---------|-------------|
| `./scripts/run-hive-mind.sh demo` | Quick demonstration |
| `./scripts/run-hive-mind.sh interactive` | Node.js REPL with Hive Mind loaded |
| `./scripts/run-hive-mind.sh test` | Run test suite |
| `./scripts/run-hive-mind.sh list` | List available examples |
| `./scripts/run-hive-mind.sh example <name>` | Run specific example |

## 💻 Quick Code Example

```javascript
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');

const pool = new HiveMindWorkerPool();

// Spawn 4 agents in parallel (4x faster)
const agents = await pool.spawnAgentsParallel([
  { type: 'researcher', name: 'R1' },
  { type: 'coder', name: 'C1' },
  { type: 'analyst', name: 'A1' },
  { type: 'tester', name: 'T1' }
], 'my-swarm');

console.log('Agents:', agents);

await pool.terminate();
```

## 🔧 Troubleshooting

### SQLite Warning (Safe to Ignore)

```
⚠️  Failed to connect to Hive Mind database
   Continuing with in-memory mode only
```

**Impact**: None - System works perfectly in memory mode.

**Fix** (Optional, for persistence):
```bash
# macOS
xcode-select --install && pnpm rebuild better-sqlite3

# Ubuntu
sudo apt-get install build-essential python3
pnpm rebuild better-sqlite3
```

### Permission Denied

```bash
chmod +x scripts/run-hive-mind.sh
chmod +x scripts/run-hive-mind-docker.sh
```

## 📚 Full Documentation

See [HIVE-MIND-DEPLOYMENT.md](docs/HIVE-MIND-DEPLOYMENT.md) for complete guide.

---

**Questions?** Check [docs/hive-mind/](docs/hive-mind/) for detailed documentation.

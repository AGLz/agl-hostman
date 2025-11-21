# Hive Mind Docker Setup

Complete Docker configuration for running the Hive Mind Worker Pool in a containerized environment.

## 🚀 Quick Start

### 1. Build the Container

```bash
cd /path/to/agl-hostman

# Build using docker-compose
docker-compose -f docker/hive-mind/docker-compose.yml build

# Or build directly with Docker
docker build -t agl-hive-mind:latest -f docker/hive-mind/Dockerfile .
```

### 2. Run the Container

```bash
# Start with docker-compose (recommended)
docker-compose -f docker/hive-mind/docker-compose.yml up -d

# Or run directly with Docker
docker run -it --rm \
  --name agl-hive-mind \
  -v $(pwd)/src/hive-mind-integration:/app/src/hive-mind-integration:ro \
  -v hive-mind-logs:/app/logs \
  -v hive-mind-data:/app/data \
  -e WORKER_POOL_SIZE=4 \
  agl-hive-mind:latest
```

### 3. Access Interactive Shell

```bash
# Attach to running container
docker exec -it agl-hive-mind node

# Or use docker-compose
docker-compose -f docker/hive-mind/docker-compose.yml exec hive-mind node
```

## 📦 Container Features

### Built-in Components
- ✅ Node.js 18 Alpine (minimal size)
- ✅ Hive Mind Worker Pool v2.0.0
- ✅ Performance Monitor
- ✅ 15 Agent Templates
- ✅ Health checks
- ✅ Persistent volumes for logs/data/metrics

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Node.js environment |
| `LOG_LEVEL` | `info` | Logging level |
| `WORKER_POOL_SIZE` | `4` | Initial worker pool size |
| `MAX_WORKERS` | `16` | Maximum concurrent workers |
| `ENABLE_MONITORING` | `true` | Enable performance monitoring |
| `METRICS_RETENTION_HOURS` | `24` | Metrics retention period |
| `ALERT_THRESHOLD_CPU` | `90` | CPU alert threshold (%) |
| `ALERT_THRESHOLD_MEMORY` | `85` | Memory alert threshold (%) |

### Volumes

| Volume | Mount Point | Purpose |
|--------|-------------|---------|
| `hive-mind-logs` | `/app/logs` | Application logs |
| `hive-mind-data` | `/app/data` | Persistent data |
| `hive-mind-metrics` | `/app/metrics` | Performance metrics |

## 🎯 Usage Examples

### Example 1: Basic Agent Spawning

```bash
docker exec -it agl-hive-mind node << 'EOF'
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');

(async () => {
  const pool = new HiveMindWorkerPool();

  // Spawn 4 agents in parallel
  const agents = await pool.spawnAgentsParallel([
    { type: 'researcher', name: 'R1' },
    { type: 'coder', name: 'C1' },
    { type: 'analyst', name: 'A1' },
    { type: 'tester', name: 'T1' }
  ], 'test-swarm');

  console.log('Spawned agents:', agents);

  await pool.terminate();
})();
EOF
```

### Example 2: Run Test Suite

```bash
# Run basic integration tests
docker exec -it agl-hive-mind node tests/hive-mind/test-hive-mind-integration.js

# Run extended features tests
docker exec -it agl-hive-mind node tests/hive-mind/test-extended-features.js
```

### Example 3: Performance Monitoring

```bash
docker exec -it agl-hive-mind node << 'EOF'
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');

const pool = new HiveMindWorkerPool();

// Get real-time dashboard
const dashboard = pool.getDashboard();
console.log('Dashboard:', JSON.stringify(dashboard, null, 2));

// Get monitoring summary
const summary = pool.getMonitoringSummary();
console.log('Status:', summary.status);
console.log('Active agents:', summary.agents.active);
EOF
```

### Example 4: Interactive REPL Session

```bash
# Start interactive session
docker exec -it agl-hive-mind node

# Then in Node.js REPL:
> const { HiveMindWorkerPool, AgentTemplates } = require('./src/hive-mind-integration');
> const pool = new HiveMindWorkerPool();
> pool.getAvailableAgentTypes()
> // ... continue interactive work
```

## 🔧 Advanced Configuration

### Custom Worker Pool Size

```bash
# Increase worker pool for heavy workloads
docker run -it --rm \
  -e WORKER_POOL_SIZE=8 \
  -e MAX_WORKERS=32 \
  agl-hive-mind:latest
```

### Mount Custom Scripts

```bash
# Mount and run custom script
docker run -it --rm \
  -v $(pwd)/my-script.js:/app/my-script.js:ro \
  agl-hive-mind:latest \
  node /app/my-script.js
```

### Access Logs

```bash
# View logs in real-time
docker-compose -f docker/hive-mind/docker-compose.yml logs -f hive-mind

# Copy logs from container
docker cp agl-hive-mind:/app/logs ./hive-mind-logs
```

## 📊 Monitoring & Health

### Health Check

```bash
# Check container health
docker inspect agl-hive-mind --format='{{.State.Health.Status}}'

# Manual health check
docker exec agl-hive-mind node -e "require('./src/hive-mind-integration').HiveMindWorkerPool"
```

### Resource Usage

```bash
# Monitor resource usage
docker stats agl-hive-mind

# View detailed container info
docker inspect agl-hive-mind
```

### Metrics Export

```bash
# Export metrics to JSON
docker exec agl-hive-mind node << 'EOF'
const { HiveMindWorkerPool } = require('./src/hive-mind-integration');
const pool = new HiveMindWorkerPool();
const metrics = pool.exportMetrics('json');
console.log(metrics);
EOF
```

## 🛠️ Troubleshooting

### Container Won't Start

```bash
# Check logs
docker-compose -f docker/hive-mind/docker-compose.yml logs hive-mind

# Rebuild from scratch
docker-compose -f docker/hive-mind/docker-compose.yml build --no-cache
```

### Permission Issues

```bash
# Fix volume permissions
docker-compose -f docker/hive-mind/docker-compose.yml down -v
docker volume prune -f
docker-compose -f docker/hive-mind/docker-compose.yml up -d
```

### Memory Issues

```bash
# Increase memory limit
docker run -it --rm \
  --memory="16g" \
  --memory-swap="16g" \
  agl-hive-mind:latest
```

## 🚀 Production Deployment

### Docker Swarm

```bash
# Initialize swarm
docker swarm init

# Deploy stack
docker stack deploy -c docker/hive-mind/docker-compose.yml hive-mind

# Check services
docker stack services hive-mind
```

### Kubernetes

```bash
# Convert to Kubernetes manifests (using kompose)
kompose convert -f docker/hive-mind/docker-compose.yml

# Apply to cluster
kubectl apply -f *.yaml
```

## 📚 Related Documentation

- [Hive Mind Integration Guide](../../docs/hive-mind/HIVE_MIND_WORKER_POOL_INTEGRATION.md)
- [Extended Capabilities](../../docs/hive-mind/EXTENDED_CAPABILITIES.md)
- [Performance Benchmarks](../../docs/performance/IMPLEMENTATION_SUMMARY.md)

## 🔗 Integration with AGL Infrastructure

### WireGuard Network Access

```bash
# Run with WireGuard network access (if container supports it)
docker run -it --rm \
  --cap-add=NET_ADMIN \
  --device=/dev/net/tun \
  -v /path/to/wg0.conf:/etc/wireguard/wg0.conf:ro \
  agl-hive-mind:latest
```

### Tailscale Integration

```bash
# Run with Tailscale sidecar
docker-compose -f docker/hive-mind/docker-compose.yml \
  -f docker/hive-mind/docker-compose.tailscale.yml \
  up -d
```

---

**Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintainer**: AGL Infrastructure Team

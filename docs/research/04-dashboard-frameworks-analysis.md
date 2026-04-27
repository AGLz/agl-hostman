# Dashboard Framework Analysis for Infrastructure Monitoring

> **Research Date**: 2025-10-28
> **Status**: Framework Evaluation & Recommendations
> **Focus**: Lightweight, informational dashboards for host administration

---

## Executive Summary

Modern infrastructure monitoring requires dashboards that are **lightweight, fast, and informative** without being resource-intensive. For the `agl-hostman` project, the ideal dashboard solution should provide real-time visibility into:

- Container health and resource usage (CT179, CT183, etc.)
- WireGuard mesh connectivity status
- NFS storage utilization
- Proxmox host metrics (AGLSRV1, AGLSRV6)
- Application deployment status (Dokploy environments)

This research evaluates lightweight dashboard frameworks suitable for infrastructure management, focusing on minimal resource overhead and rapid deployment.

---

## Requirements Analysis

### Functional Requirements

**Core Features**:
- Real-time metrics visualization (CPU, memory, disk, network)
- Container status monitoring (Docker, LXC)
- Network connectivity health (WireGuard, Tailscale)
- Storage mount points and capacity
- Service uptime tracking
- Alert notifications (optional)

**Nice-to-Have**:
- Historical data trends
- Custom widget creation
- API integration for automation
- Multi-user access control
- Mobile-responsive design

### Non-Functional Requirements

**Performance**:
- **Low Resource Footprint**: <512MB RAM, <1 CPU core
- **Fast Load Times**: <2 seconds initial page load
- **Minimal Storage**: <500MB disk space
- **Lightweight Backend**: Preferably single binary or minimal dependencies

**Operational**:
- **Easy Deployment**: Docker containerization
- **Simple Configuration**: YAML or JSON-based
- **Self-Hosted**: No external dependencies
- **Maintenance**: Minimal ongoing updates required

---

## Framework Evaluation

### 1. Grafana 🏆

**Overview**: The industry standard for metrics visualization with extensive data source support.

**Strengths**:
- ✅ **Powerful Visualization**: 150+ panel types
- ✅ **Data Source Support**: Prometheus, InfluxDB, Loki, Elasticsearch, MySQL, PostgreSQL
- ✅ **Extensive Plugin Ecosystem**: 1000+ community plugins
- ✅ **Alerting**: Built-in alert manager
- ✅ **Dashboard Templating**: Reusable dashboards
- ✅ **Multi-User Support**: RBAC, LDAP, OAuth integration
- ✅ **Active Development**: Monthly releases, strong community

**Resource Footprint**:
- **Memory**: 256-512MB RAM (typical)
- **CPU**: 0.5-1 core (idle)
- **Storage**: ~200MB for binary + plugins
- **Startup Time**: 5-10 seconds

**Deployment**:
```yaml
# docker-compose.yaml
version: '3.8'

services:
  grafana:
    image: grafana/grafana-oss:latest
    container_name: grafana
    restart: unless-stopped

    ports:
      - "3000:3000"

    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=grafana-clock-panel,grafana-simple-json-datasource

    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning

volumes:
  grafana-data:
```

**Data Collection Stack**:
```yaml
# Complete monitoring stack
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=30d'

  node-exporter:
    image: prom/node-exporter:latest
    network_mode: host
    pid: host
    command:
      - '--path.rootfs=/host'
    volumes:
      - '/:/host:ro,rslave'

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro

  grafana:
    image: grafana/grafana-oss:latest
    depends_on:
      - prometheus
```

**Use Case Fit**: ⭐⭐⭐⭐⭐ (5/5)
- Perfect for comprehensive infrastructure monitoring
- Scales from single host to large deployments
- Best choice if already using Prometheus

**Recommendation**: **Primary choice** for production-grade monitoring.

---

### 2. Pulse (Proxmox-Specific) 🎯

**Overview**: A super lightweight, modern monitoring platform built specifically for Proxmox VE.

**Strengths**:
- ✅ **Ultra-Lightweight**: Single binary, no external database
- ✅ **Proxmox Native**: Direct API integration
- ✅ **Modern UI**: Clean, responsive design
- ✅ **Zero Configuration**: Auto-discovers Proxmox nodes
- ✅ **No Dependencies**: Standalone deployment
- ✅ **Resource Efficient**: <100MB RAM, <0.1 CPU core

**Resource Footprint**:
- **Memory**: 50-100MB RAM
- **CPU**: <0.1 core (idle)
- **Storage**: ~50MB single binary
- **Startup Time**: <2 seconds

**Deployment**:
```yaml
services:
  pulse:
    image: pulse-monitor/pulse:latest
    container_name: pulse
    restart: unless-stopped

    ports:
      - "8080:8080"

    environment:
      - PROXMOX_HOST=192.168.0.245
      - PROXMOX_USER=monitor@pve
      - PROXMOX_PASSWORD=secret
      - PROXMOX_VERIFY_SSL=false

    volumes:
      - pulse-data:/data
```

**Features**:
- Real-time node status (CPU, memory, storage)
- VM/Container health monitoring
- Network interfaces and traffic
- Storage utilization across nodes
- Cluster overview (if multi-node)

**Use Case Fit**: ⭐⭐⭐⭐ (4/5)
- Excellent for Proxmox-focused monitoring
- Limited to Proxmox environments
- No support for non-Proxmox metrics

**Recommendation**: **Best choice** for dedicated Proxmox dashboard (AGLSRV1, AGLSRV6 overview).

---

### 3. Tipboard / Dashing (Lightweight Alternative)

**Overview**: Simple, config-based dashboard frameworks for custom metrics.

**Tipboard Strengths**:
- ✅ **Simple Configuration**: YAML-based layout
- ✅ **HTTP API**: Push metrics via REST
- ✅ **Widget-Based**: Modular dashboard design
- ✅ **No Data Source Lock-in**: Accept any data via API
- ✅ **Lightweight**: Python Flask backend

**Resource Footprint**:
- **Memory**: 100-200MB RAM
- **CPU**: 0.2-0.5 core
- **Storage**: ~100MB
- **Startup Time**: 2-3 seconds

**Configuration Example**:
```yaml
# layout.yaml
layout:
  - row_1:
      - col_1_of_2:
          - tile: big_value
            id: cpu_usage
            title: "CPU Usage"
            classes: "green"
      - col_2_of_2:
          - tile: big_value
            id: memory_usage
            title: "Memory Usage"

  - row_2:
      - col_1_of_1:
          - tile: listing
            id: container_status
            title: "Running Containers"
```

**Push Metrics**:
```bash
# Simple HTTP API for updating metrics
curl -X POST http://tipboard:7272/api/v0.1/tile/cpu_usage \
  -d '{"value": 45, "subtitle": "AGLSRV1"}'

curl -X POST http://tipboard:7272/api/v0.1/tile/container_status \
  -d '{"items": ["CT179: Running", "CT183: Running", "CT108: Running"]}'
```

**Use Case Fit**: ⭐⭐⭐ (3/5)
- Good for simple, custom dashboards
- Requires custom data collection scripts
- Limited built-in integrations

**Recommendation**: **Alternative** if Grafana is too complex.

---

### 4. Netdata (Real-Time Monitoring)

**Overview**: Real-time performance monitoring with zero-configuration agent deployment.

**Strengths**:
- ✅ **Zero Configuration**: Auto-discovers metrics
- ✅ **Real-Time**: 1-second granularity
- ✅ **Comprehensive**: 5000+ metrics per host
- ✅ **Beautiful UI**: Modern, interactive charts
- ✅ **Distributed**: Multi-node support
- ✅ **Alerting**: Built-in health checks

**Resource Footprint**:
- **Memory**: 100-200MB RAM (with compression)
- **CPU**: 1-2% (typical)
- **Storage**: Configurable (RAM or disk-based)
- **Startup Time**: 3-5 seconds

**Deployment** (Per-Host Agent):
```bash
# Install Netdata on each monitored host
curl https://get.netdata.cloud/kickstart.sh | bash

# Or via Docker
docker run -d --name=netdata \
  -p 19999:19999 \
  -v /proc:/host/proc:ro \
  -v /sys:/host/sys:ro \
  -v /var/run/docker.sock:/var/run/docker.sock:ro \
  --cap-add SYS_PTRACE \
  --security-opt apparmor=unconfined \
  netdata/netdata
```

**Netdata Cloud** (Optional Centralization):
```yaml
# Connect multiple hosts to central dashboard
# Free tier: Unlimited nodes, 7-day retention
services:
  netdata-parent:
    image: netdata/netdata:latest
    ports:
      - "19999:19999"
    environment:
      - NETDATA_CLAIM_TOKEN=your-token
      - NETDATA_CLAIM_ROOMS=your-room
```

**Features**:
- CPU, memory, disk, network metrics
- Docker container monitoring
- Application performance (MySQL, Nginx, etc.)
- Anomaly detection
- Health alarms

**Use Case Fit**: ⭐⭐⭐⭐ (4/5)
- Excellent for real-time troubleshooting
- Per-host deployment overhead
- Can complement Grafana for deep-dive analysis

**Recommendation**: **Complementary tool** to Grafana for real-time debugging.

---

### 5. Portainer (Container Management Dashboard)

**Overview**: Web UI for managing Docker, Swarm, and Kubernetes environments.

**Strengths**:
- ✅ **Container-Focused**: Perfect for Docker-heavy infrastructure
- ✅ **Management UI**: Not just monitoring, but also deployment
- ✅ **Multi-Environment**: Manage multiple Docker hosts
- ✅ **User-Friendly**: Intuitive for non-CLI users
- ✅ **Templates**: App deployment templates

**Resource Footprint**:
- **Memory**: 200-300MB RAM
- **CPU**: 0.5 core
- **Storage**: ~150MB
- **Startup Time**: 3-5 seconds

**Deployment**:
```bash
# Portainer Server
docker volume create portainer_data

docker run -d \
  -p 9000:9000 \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

**Features**:
- Container status and logs
- Resource usage per container
- Image management
- Network and volume management
- Stack deployment (docker-compose)

**Use Case Fit**: ⭐⭐⭐⭐ (4/5)
- Excellent for container-centric environments
- Not a comprehensive monitoring solution
- Best paired with Grafana for metrics

**Recommendation**: **Supplementary tool** for CT179 Docker management.

---

### 6. Custom Dashboard (React + TailwindCSS)

**Overview**: Build a lightweight, custom dashboard tailored to agl-hostman needs.

**Tech Stack**:
- **Frontend**: React 18 + Vite
- **Styling**: TailwindCSS (minimal CSS overhead)
- **Data Fetching**: React Query (efficient caching)
- **Charts**: Recharts or Chart.js (lightweight)
- **Backend**: Express.js API (optional, or direct API calls)

**Example Architecture**:
```
┌─────────────────────────────────────────────┐
│       React Dashboard (Static Build)        │
│  - CT179 status card                        │
│  - CT183 Archon health                      │
│  - WireGuard connectivity matrix            │
│  - NFS mount status                         │
│  - Dokploy deployment overview              │
└─────────────────────────────────────────────┘
                 │
         ┌───────┼───────┐
         │       │       │
         ▼       ▼       ▼
   ┌─────────┐ ┌──────────┐ ┌───────────┐
   │ Proxmox │ │  Docker  │ │  Dokploy  │
   │   API   │ │   API    │ │    API    │
   └─────────┘ └──────────┘ └───────────┘
```

**Component Example**:
```jsx
// ContainerStatusCard.jsx
import { useQuery } from '@tanstack/react-query';

export function ContainerStatusCard({ containerId }) {
  const { data, isLoading } = useQuery({
    queryKey: ['container', containerId],
    queryFn: () => fetch(`/api/docker/containers/${containerId}`).then(r => r.json()),
    refetchInterval: 5000 // Refresh every 5 seconds
  });

  if (isLoading) return <div className="animate-pulse">Loading...</div>;

  return (
    <div className="bg-white shadow rounded-lg p-6">
      <h3 className="text-lg font-semibold">{data.name}</h3>

      <div className="mt-4 space-y-2">
        <StatusBadge status={data.status} />

        <MetricBar
          label="CPU"
          value={data.cpu_percent}
          max={100}
          color="blue"
        />

        <MetricBar
          label="Memory"
          value={data.memory_mb}
          max={data.memory_limit_mb}
          color="green"
        />
      </div>
    </div>
  );
}
```

**Deployment**:
```yaml
# Vite build produces static files
# Deploy to any web server (Nginx, Caddy, or even Dokploy)

services:
  hostman-dashboard:
    image: nginx:alpine
    volumes:
      - ./dist:/usr/share/nginx/html:ro
    ports:
      - "8080:80"
    restart: unless-stopped
```

**Resource Footprint**:
- **Memory**: 50-100MB (Nginx + static files)
- **CPU**: <0.1 core
- **Storage**: 10-50MB (optimized React build)
- **Build Time**: 30-60 seconds

**Strengths**:
- ✅ **Fully Customized**: Tailored exactly to agl-hostman needs
- ✅ **Minimal Dependencies**: Static files + API calls
- ✅ **Fast Performance**: No backend processing
- ✅ **Easy Deployment**: Static hosting

**Challenges**:
- ⚠️ **Development Time**: 2-4 weeks for initial build
- ⚠️ **Maintenance**: Custom code to maintain
- ⚠️ **No Historical Data**: Would need separate time-series DB

**Use Case Fit**: ⭐⭐⭐⭐ (4/5)
- Perfect for project-specific requirements
- Higher upfront investment
- Full control over features and UI/UX

**Recommendation**: **Future enhancement** after MVP with existing tools.

---

## Recommended Dashboard Stack for agl-hostman

### Phase 1: Quick Win (Week 1-2)

**Primary Dashboard: Grafana**
```yaml
# Full monitoring stack deployment on CT179
services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    networks:
      - monitoring

  node-exporter:
    image: prom/node-exporter:latest
    network_mode: host
    pid: host
    volumes:
      - '/:/host:ro,rslave'

  grafana:
    image: grafana/grafana-oss:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_PASSWORD}
      - GF_INSTALL_PLUGINS=grafana-clock-panel
    volumes:
      - grafana-data:/var/lib/grafana
      - ./grafana/dashboards:/etc/grafana/provisioning/dashboards
      - ./grafana/datasources:/etc/grafana/provisioning/datasources
    networks:
      - monitoring

volumes:
  prometheus-data:
  grafana-data:

networks:
  monitoring:
    driver: bridge
```

**Pre-configured Dashboards**:
1. **Node Overview**: CPU, memory, disk, network per host
2. **Docker Containers**: All CT179/CT183/CT108 containers
3. **Storage**: NFS mount status and capacity
4. **Network**: WireGuard interface metrics
5. **Dokploy**: Application deployment status

**Benefits**:
- ✅ Industry-standard tool
- ✅ Rich ecosystem of pre-built dashboards
- ✅ Scales with infrastructure growth
- ✅ Team familiarity (common skillset)

---

### Phase 2: Proxmox-Specific (Week 2-3)

**Secondary Dashboard: Pulse**
```yaml
services:
  pulse:
    image: pulse-monitor/pulse:latest
    ports:
      - "8080:8080"
    environment:
      - PROXMOX_HOST=192.168.0.245
      - PROXMOX_USER=monitor@pve
      - PROXMOX_PASSWORD=${PROXMOX_PASSWORD}
    networks:
      - monitoring
```

**Dedicated for**:
- AGLSRV1 and AGLSRV6 host health
- LXC container overview
- Storage pool utilization
- Cluster replication status

**Benefits**:
- ✅ Lightweight and fast
- ✅ Proxmox-native features
- ✅ Complements Grafana (different perspective)

---

### Phase 3: Container Management (Week 3-4)

**Operational Dashboard: Portainer**
```bash
docker run -d \
  -p 9443:9443 \
  --name portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:latest
```

**Use Cases**:
- Quick container restarts without CLI
- Log viewing for troubleshooting
- Deploying new stacks via UI
- Team members less comfortable with Docker CLI

**Benefits**:
- ✅ User-friendly for non-technical stakeholders
- ✅ Reduces SSH access requirements
- ✅ Audit trail of container operations

---

## Dashboard Layout Recommendations

### Grafana Main Dashboard (Home Screen)

**Layout Structure**:
```
┌─────────────────────────────────────────────────────────────┐
│                  AGL Infrastructure Overview                 │
├─────────────────────────────────────────────────────────────┤
│ AGLSRV1 Status      │  AGLSRV6 Status      │  Alerts (0)    │
│ ┌─────────────────┐ │ ┌─────────────────┐  │ ┌────────────┐ │
│ │ CPU: 45%        │ │ │ CPU: 32%        │  │ │ All Clear  │ │
│ │ RAM: 60GB/128GB │ │ │ RAM: 40GB/96GB  │  │ │            │ │
│ │ Disk: 2.5TB/8TB │ │ │ Disk: 1.2TB/4TB │  │ │            │ │
│ └─────────────────┘ │ └─────────────────┘  │ └────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Container Health (CT179, CT183, CT108)                      │
│ ┌──────┬──────┬──────┬──────┬──────┬──────┬──────┬──────┐  │
│ │CT179 │CT183 │CT108 │CT184 │CT185 │CT186 │CT187 │CT188 │  │
│ │  🟢  │  🟢  │  🟢  │  🟢  │  🟡  │  🟢  │  🟢  │  🔴  │  │
│ └──────┴──────┴──────┴──────┴──────┴──────┴──────┴──────┘  │
├─────────────────────────────────────────────────────────────┤
│ WireGuard Mesh Health                                       │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ 14/14 Peers Connected │ Last Handshake: 45s ago         │ │
│ │ Network: 10.6.0.0/24  │ Traffic: 125MB/s                │ │
│ └─────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│ Dokploy Deployments                                         │
│ ┌─────────┬─────────┬─────────┬─────────┐                  │
│ │  Dev    │   QA    │   UAT   │  Prod   │                  │
│ │ Running │ Running │ Running │ Running │                  │
│ │ v1.3.0  │ v1.2.5  │ v1.2.4  │ v1.2.3  │                  │
│ └─────────┴─────────┴─────────┴─────────┘                  │
└─────────────────────────────────────────────────────────────┘
```

### Pulse Dashboard (Proxmox Focus)

**Dedicated View**:
```
┌─────────────────────────────────────────────────────────────┐
│              Proxmox Cluster: AGLSRV1 + AGLSRV6             │
├─────────────────────────────────────────────────────────────┤
│ Node: AGLSRV1                    │ Node: AGLSRV6            │
│ ┌──────────────────────────────┐ │ ┌───────────────────────┐│
│ │ Status: Online ✅             │ │ │ Status: Online ✅      ││
│ │ CPU: 16 cores (45% used)     │ │ │ CPU: 12 cores (32%)   ││
│ │ RAM: 128GB (60GB used)       │ │ │ RAM: 96GB (40GB used) ││
│ │ Uptime: 45 days              │ │ │ Uptime: 30 days       ││
│ │                              │ │ │                       ││
│ │ Containers: 32/68 running    │ │ │ Containers: 15/28     ││
│ │ VMs: 5/10 running            │ │ │ VMs: 2/5 running      ││
│ └──────────────────────────────┘ │ └───────────────────────┘│
├─────────────────────────────────────────────────────────────┤
│ Storage Pools                                               │
│ ┌───────────────┬────────────┬────────────┬──────────────┐  │
│ │ Pool          │ Size       │ Used       │ Free         │  │
│ ├───────────────┼────────────┼────────────┼──────────────┤  │
│ │ local-lvm     │ 500GB      │ 350GB      │ 150GB (30%)  │  │
│ │ fgsrv6-wg     │ 8TB        │ 2.5TB      │ 5.5TB (69%)  │  │
│ │ backup        │ 2TB        │ 800GB      │ 1.2TB (60%)  │  │
│ └───────────────┴────────────┴────────────┴──────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementation Timeline

### Week 1: Grafana + Prometheus
- **Day 1-2**: Deploy monitoring stack on CT179
- **Day 3-4**: Configure node-exporter on all hosts
- **Day 5**: Import and customize dashboards

### Week 2: Data Collection
- **Day 1-2**: Docker container metrics (cAdvisor)
- **Day 3**: WireGuard metrics collection script
- **Day 4-5**: Dokploy API integration

### Week 3: Pulse Deployment
- **Day 1-2**: Deploy Pulse for Proxmox monitoring
- **Day 3-4**: Configure Proxmox API access
- **Day 5**: Dashboard customization

### Week 4: Portainer & Polish
- **Day 1**: Deploy Portainer on CT179
- **Day 2-3**: Configure endpoints (CT179, CT108)
- **Day 4-5**: User training and documentation

---

## Monitoring Metrics Checklist

### Host-Level Metrics
- [ ] CPU usage (per core and aggregate)
- [ ] Memory utilization (used, cached, available)
- [ ] Disk I/O (read/write rates, latency)
- [ ] Network traffic (bytes in/out per interface)
- [ ] Load average (1m, 5m, 15m)
- [ ] System uptime

### Container Metrics
- [ ] Container status (running, stopped, restarting)
- [ ] CPU usage per container
- [ ] Memory usage per container
- [ ] Network traffic per container
- [ ] Restart count and last restart time
- [ ] Log error rate

### Network Metrics
- [ ] WireGuard peer connectivity
- [ ] Last handshake timestamps
- [ ] Interface traffic rates
- [ ] Packet loss (if available)
- [ ] Latency between nodes

### Storage Metrics
- [ ] NFS mount status (mounted/unmounted)
- [ ] Storage capacity (used/available)
- [ ] I/O wait times
- [ ] Disk health (SMART status)

### Application Metrics
- [ ] Dokploy deployment status
- [ ] Application version per environment
- [ ] HTTP response codes (if exposed)
- [ ] Request rates (if available)

---

## Security Considerations

### Access Control
```yaml
# Grafana authentication
grafana:
  environment:
    - GF_AUTH_ANONYMOUS_ENABLED=false
    - GF_AUTH_BASIC_ENABLED=true
    - GF_AUTH_LDAP_ENABLED=true
    - GF_AUTH_LDAP_CONFIG_FILE=/etc/grafana/ldap.toml

    # Restrict admin access
    - GF_SECURITY_ADMIN_USER=admin
    - GF_SECURITY_ADMIN_PASSWORD=${GRAFANA_ADMIN_PASSWORD}

    # Viewer-only by default
    - GF_USERS_VIEWERS_CAN_EDIT=false
```

### Network Isolation
```yaml
# Only expose dashboards via WireGuard or Tailscale
grafana:
  networks:
    - wireguard_network
  # No public port exposure
  # Access via reverse proxy with authentication
```

### API Security
```bash
# Use read-only API tokens for data collection
PROMETHEUS_TOKEN=$(grafana-cli admin reset-admin-password --homepath="/usr/share/grafana" --config="/etc/grafana/grafana.ini")

# Proxmox API: Create dedicated monitoring user
pveum user add monitor@pve
pveum aclmod / -user monitor@pve -role PVEAuditor  # Read-only
```

---

## Cost Analysis

### Infrastructure Costs

**Self-Hosted (Recommended)**:
```
Hardware: Existing CT179 (48GB RAM, spare capacity)
Storage: Prometheus data (30-day retention) = ~10GB
Monthly Cost: $0 (uses existing infrastructure)
```

**Cloud Alternative** (for comparison):
```
Grafana Cloud:
- Free Tier: 10k series, 50GB logs, 50GB traces
- Pro Tier: $49/month (for 20k series)

Datadog:
- Pro: $15/host/month × 5 hosts = $75/month

New Relic:
- Standard: $49/month (100GB ingestion)

Self-Hosted Savings: $600-900/year
```

---

## Conclusion & Final Recommendations

### 🏆 Recommended Solution for agl-hostman

**Hybrid Approach**:

1. **Grafana** (Primary)
   - Comprehensive infrastructure metrics
   - Historical data and trends
   - Custom dashboards per team role
   - Industry-standard tool

2. **Pulse** (Secondary)
   - Dedicated Proxmox monitoring
   - Lightweight supplementary view
   - Quick glance at host health

3. **Portainer** (Operational)
   - Container management UI
   - Reduce CLI dependency
   - User-friendly for non-DevOps team members

**Resource Footprint** (Total):
- Memory: ~750MB RAM
- CPU: ~1.5 cores (peak)
- Storage: ~500MB + time-series data
- Deployment: Single docker-compose stack on CT179

**Benefits**:
- ✅ Complete visibility into infrastructure
- ✅ Minimal resource overhead
- ✅ Proven, production-ready tools
- ✅ Active community support
- ✅ Scalable for future growth

**Timeline**: 4 weeks for full implementation

---

**Research Completed**: 2025-10-28
**Researcher**: Hive Mind Research Agent
**Next Document**: Security Best Practices Compilation

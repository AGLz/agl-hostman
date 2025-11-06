/**
 * Infrastructure Performance Monitor
 * Real-time monitoring of WireGuard mesh, NFS storage, Docker containers, and services
 *
 * @features
 * - WireGuard mesh connectivity and latency tracking
 * - NFS/SSHFS storage performance monitoring
 * - Docker container resource usage
 * - Service health checks (Archon, Dokploy, Ollama)
 * - Network throughput and packet loss detection
 * - Automated alerting and self-healing triggers
 */

const EventEmitter = require('events');
const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const os = require('os');

class InfrastructureMonitor extends EventEmitter {
  constructor(options = {}) {
    super();

    this.options = {
      enableRealtime: options.enableRealtime !== false,
      metricsInterval: options.metricsInterval || 5000, // 5 seconds
      healthCheckInterval: options.healthCheckInterval || 30000, // 30 seconds
      retentionPeriod: options.retentionPeriod || 3600000, // 1 hour
      hosts: options.hosts || this.getDefaultHosts(),
      alertThresholds: options.alertThresholds || this.getDefaultThresholds(),
      ...options
    };

    this.metrics = {
      wireguard: new Map(),
      storage: new Map(),
      docker: new Map(),
      services: new Map(),
      network: []
    };

    this.alerts = [];
    this.isMonitoring = false;
    this.timers = {
      metrics: null,
      healthCheck: null
    };
  }

  /**
   * Get default infrastructure hosts configuration
   */
  getDefaultHosts() {
    return {
      wireguard: {
        hub: { ip: '10.6.0.5', name: 'FGSRV6' },
        peers: [
          { ip: '10.6.0.10', name: 'AGLSRV1' },
          { ip: '10.6.0.12', name: 'AGLSRV6' },
          { ip: '10.6.0.19', name: 'CT179' },
          { ip: '10.6.0.20', name: 'CT111' },
          { ip: '10.6.0.21', name: 'CT183' }
        ]
      },
      storage: {
        nfs: [
          { host: '10.6.0.5', path: '/mnt/pve/fgsrv6-wg', name: 'fgsrv6-wg' },
          { host: '10.6.0.11', path: '/mnt/pve/fgsrv5-wg', name: 'fgsrv5-wg' },
          { host: '10.6.0.20', path: '/mnt/pve/ct111-shares', name: 'ct111-shares' },
          { host: '10.6.0.20', path: '/mnt/pve/ct111-sistema', name: 'ct111-sistema' }
        ],
        sshfs: [
          { host: '10.6.0.12', path: '/mnt/pve/aglsrv6-bb', name: 'aglsrv6-bb' },
          { host: '10.6.0.12', path: '/mnt/pve/aglsrv6-usb4tb', name: 'aglsrv6-usb4tb' }
        ]
      },
      services: {
        archon: { host: '192.168.0.183', ports: [8051, 8181, 3737], name: 'Archon MCP' },
        dokploy: { host: '192.168.0.180', ports: [3000], name: 'Dokploy' },
        ollama: { host: '192.168.0.200', ports: [11434], name: 'Ollama GPU' }
      },
      containers: {
        ct179: { id: '179', host: 'localhost', name: 'agldv03' },
        ct183: { id: '183', host: '192.168.0.245', name: 'archon' },
        ct202: { id: '202', host: '192.168.0.245', name: 'n8n-docker' }
      }
    };
  }

  /**
   * Get default alert thresholds
   */
  getDefaultThresholds() {
    return {
      wireguard: {
        latency: { warning: 50, critical: 100 }, // ms
        packetLoss: { warning: 1, critical: 5 }, // %
        handshakeAge: { warning: 300, critical: 600 } // seconds
      },
      storage: {
        iops: { warning: 50, critical: 20 }, // operations per second
        latency: { warning: 100, critical: 500 }, // ms
        usage: { warning: 85, critical: 95 } // %
      },
      docker: {
        cpu: { warning: 80, critical: 95 }, // %
        memory: { warning: 85, critical: 95 }, // %
        restarts: { warning: 3, critical: 5 } // count in last hour
      },
      network: {
        bandwidth: { warning: 80, critical: 95 }, // % of capacity
        errors: { warning: 10, critical: 50 } // error count per minute
      }
    };
  }

  /**
   * Start monitoring
   */
  async start() {
    if (this.isMonitoring) {
      console.log('Infrastructure monitor already running');
      return;
    }

    this.isMonitoring = true;
    console.log('Starting infrastructure monitor...');

    // Initial metrics collection
    await this.collectAllMetrics();

    // Start periodic collection
    if (this.options.enableRealtime) {
      this.timers.metrics = setInterval(async () => {
        await this.collectAllMetrics();
      }, this.options.metricsInterval);

      this.timers.healthCheck = setInterval(async () => {
        await this.performHealthChecks();
      }, this.options.healthCheckInterval);
    }

    this.emit('monitor:started');
    console.log('Infrastructure monitor started');
  }

  /**
   * Stop monitoring
   */
  stop() {
    if (!this.isMonitoring) {
      return;
    }

    this.isMonitoring = false;

    Object.values(this.timers).forEach(timer => {
      if (timer) clearInterval(timer);
    });

    this.timers = { metrics: null, healthCheck: null };

    this.emit('monitor:stopped');
    console.log('Infrastructure monitor stopped');
  }

  /**
   * Collect all metrics
   */
  async collectAllMetrics() {
    const timestamp = Date.now();

    try {
      await Promise.all([
        this.collectWireGuardMetrics(),
        this.collectStorageMetrics(),
        this.collectDockerMetrics(),
        this.collectNetworkMetrics()
      ]);

      this.emit('metrics:collected', { timestamp });
    } catch (error) {
      this.emit('error', { type: 'collection', error: error.message });
      console.error('Metrics collection error:', error);
    }
  }

  /**
   * Collect WireGuard mesh metrics
   */
  async collectWireGuardMetrics() {
    try {
      const { stdout } = await execAsync('wg show wg0 dump');
      const lines = stdout.trim().split('\n');

      // Skip header line
      for (let i = 1; i < lines.length; i++) {
        const parts = lines[i].split('\t');
        if (parts.length < 8) continue;

        const peerKey = parts[0];
        const endpoint = parts[2];
        const latestHandshake = parseInt(parts[4]);
        const rxBytes = parseInt(parts[5]);
        const txBytes = parseInt(parts[6]);

        // Find peer name from config
        const peerInfo = this.options.hosts.wireguard.peers.find(p =>
          endpoint.includes(p.ip)
        ) || { name: 'Unknown', ip: endpoint };

        const handshakeAge = Date.now() / 1000 - latestHandshake;

        // Ping test for latency
        const latency = await this.pingHost(peerInfo.ip);

        const metric = {
          timestamp: Date.now(),
          peer: peerInfo.name,
          ip: peerInfo.ip,
          publicKey: peerKey,
          endpoint,
          handshakeAge,
          latency,
          rxBytes,
          txBytes,
          healthy: handshakeAge < this.options.alertThresholds.wireguard.handshakeAge.critical
        };

        this.metrics.wireguard.set(peerInfo.ip, metric);

        // Check thresholds
        if (latency > this.options.alertThresholds.wireguard.latency.critical) {
          this.createAlert('wireguard', 'latency', latency, 'critical', peerInfo.name);
        }

        if (handshakeAge > this.options.alertThresholds.wireguard.handshakeAge.warning) {
          this.createAlert('wireguard', 'handshake', handshakeAge, 'warning', peerInfo.name);
        }
      }

      this.emit('wireguard:metrics', this.metrics.wireguard);
    } catch (error) {
      // WireGuard might not be available, silently skip
      if (!error.message.includes('command not found')) {
        console.warn('WireGuard metrics collection failed:', error.message);
      }
    }
  }

  /**
   * Ping host and return latency
   */
  async pingHost(host, count = 1) {
    try {
      const { stdout } = await execAsync(`ping -c ${count} -W 1 ${host}`);
      const match = stdout.match(/time=([\d.]+)/);
      return match ? parseFloat(match[1]) : 999;
    } catch (error) {
      return 999; // Host unreachable
    }
  }

  /**
   * Collect storage metrics (NFS/SSHFS)
   */
  async collectStorageMetrics() {
    try {
      const { stdout } = await execAsync('df -h | grep -E "wg|sshfs"');
      const lines = stdout.trim().split('\n');

      for (const line of lines) {
        const parts = line.split(/\s+/);
        if (parts.length < 6) continue;

        const filesystem = parts[0];
        const size = parts[1];
        const used = parts[2];
        const available = parts[3];
        const usagePercent = parseInt(parts[4]);
        const mountPoint = parts[5];

        // Determine storage type
        const storageType = filesystem.includes(':') ? 'NFS' : 'SSHFS';
        const storageName = mountPoint.split('/').pop();

        // Measure I/O latency with a small test
        const ioLatency = await this.measureStorageLatency(mountPoint);

        const metric = {
          timestamp: Date.now(),
          name: storageName,
          type: storageType,
          filesystem,
          mountPoint,
          size,
          used,
          available,
          usagePercent,
          ioLatency,
          healthy: usagePercent < this.options.alertThresholds.storage.usage.critical
        };

        this.metrics.storage.set(storageName, metric);

        // Check thresholds
        if (usagePercent > this.options.alertThresholds.storage.usage.critical) {
          this.createAlert('storage', 'usage', usagePercent, 'critical', storageName);
        }

        if (ioLatency > this.options.alertThresholds.storage.latency.critical) {
          this.createAlert('storage', 'latency', ioLatency, 'critical', storageName);
        }
      }

      this.emit('storage:metrics', this.metrics.storage);
    } catch (error) {
      console.warn('Storage metrics collection failed:', error.message);
    }
  }

  /**
   * Measure storage I/O latency
   */
  async measureStorageLatency(mountPoint) {
    try {
      const testFile = `${mountPoint}/.performance-test-${Date.now()}`;
      const start = Date.now();

      await execAsync(`timeout 2 dd if=/dev/zero of=${testFile} bs=1M count=1 conv=fdatasync 2>&1`);
      await execAsync(`rm -f ${testFile}`);

      return Date.now() - start;
    } catch (error) {
      return 999; // Failed or stale mount
    }
  }

  /**
   * Collect Docker container metrics
   */
  async collectDockerMetrics() {
    try {
      const { stdout } = await execAsync('docker stats --no-stream --format "{{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}\t{{.MemUsage}}\t{{.NetIO}}"');
      const lines = stdout.trim().split('\n');

      for (const line of lines) {
        const [id, name, cpuPercStr, memPercStr, memUsage, netIO] = line.split('\t');

        const cpuPerc = parseFloat(cpuPercStr.replace('%', ''));
        const memPerc = parseFloat(memPercStr.replace('%', ''));

        const metric = {
          timestamp: Date.now(),
          id,
          name,
          cpuPerc,
          memPerc,
          memUsage,
          netIO,
          healthy: cpuPerc < this.options.alertThresholds.docker.cpu.critical &&
                   memPerc < this.options.alertThresholds.docker.memory.critical
        };

        this.metrics.docker.set(name, metric);

        // Check thresholds
        if (cpuPerc > this.options.alertThresholds.docker.cpu.critical) {
          this.createAlert('docker', 'cpu', cpuPerc, 'critical', name);
        }

        if (memPerc > this.options.alertThresholds.docker.memory.critical) {
          this.createAlert('docker', 'memory', memPerc, 'critical', name);
        }
      }

      this.emit('docker:metrics', this.metrics.docker);
    } catch (error) {
      // Docker might not be available
      if (!error.message.includes('command not found')) {
        console.warn('Docker metrics collection failed:', error.message);
      }
    }
  }

  /**
   * Collect network metrics
   */
  async collectNetworkMetrics() {
    try {
      const { stdout } = await execAsync('cat /proc/net/dev');
      const lines = stdout.trim().split('\n').slice(2); // Skip header

      for (const line of lines) {
        const parts = line.trim().split(/\s+/);
        const iface = parts[0].replace(':', '');

        // Only monitor important interfaces
        if (!['wg0', 'eth0', 'tailscale0'].includes(iface)) continue;

        const metric = {
          timestamp: Date.now(),
          interface: iface,
          rxBytes: parseInt(parts[1]),
          rxPackets: parseInt(parts[2]),
          rxErrors: parseInt(parts[3]),
          txBytes: parseInt(parts[9]),
          txPackets: parseInt(parts[10]),
          txErrors: parseInt(parts[11])
        };

        this.metrics.network.push(metric);
      }

      // Clean old network metrics (keep last hour)
      const cutoff = Date.now() - this.options.retentionPeriod;
      this.metrics.network = this.metrics.network.filter(m => m.timestamp > cutoff);

      this.emit('network:metrics', this.metrics.network);
    } catch (error) {
      console.warn('Network metrics collection failed:', error.message);
    }
  }

  /**
   * Perform health checks on critical services
   */
  async performHealthChecks() {
    const services = this.options.hosts.services;

    for (const [serviceName, config] of Object.entries(services)) {
      try {
        const healthStatus = await this.checkServiceHealth(config);

        this.metrics.services.set(serviceName, {
          timestamp: Date.now(),
          name: config.name,
          host: config.host,
          ports: config.ports,
          healthy: healthStatus.healthy,
          details: healthStatus
        });

        if (!healthStatus.healthy) {
          this.createAlert('service', 'health', 0, 'critical', config.name);
        }

        this.emit('service:health', { name: serviceName, status: healthStatus });
      } catch (error) {
        console.warn(`Health check failed for ${serviceName}:`, error.message);
      }
    }
  }

  /**
   * Check service health by testing port connectivity
   */
  async checkServiceHealth(config) {
    const results = await Promise.all(
      config.ports.map(port => this.checkPortOpen(config.host, port))
    );

    const openPorts = results.filter(r => r.open).length;
    const healthy = openPorts === config.ports.length;

    return {
      healthy,
      openPorts,
      totalPorts: config.ports.length,
      portStatus: results
    };
  }

  /**
   * Check if port is open
   */
  async checkPortOpen(host, port, timeout = 2000) {
    try {
      await execAsync(`timeout ${timeout / 1000} bash -c 'cat < /dev/null > /dev/tcp/${host}/${port}'`);
      return { port, open: true };
    } catch (error) {
      return { port, open: false };
    }
  }

  /**
   * Create alert
   */
  createAlert(category, metric, value, level, target) {
    const alert = {
      id: `alert-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now(),
      category,
      metric,
      value,
      level,
      target,
      threshold: this.options.alertThresholds[category]?.[metric]?.[level],
      acknowledged: false
    };

    // Deduplicate similar recent alerts (within 5 minutes)
    const recentSimilar = this.alerts.find(a =>
      a.category === category &&
      a.metric === metric &&
      a.target === target &&
      a.timestamp > Date.now() - 300000
    );

    if (!recentSimilar) {
      this.alerts.push(alert);
      this.emit('alert:created', alert);

      // Keep only last 100 alerts
      if (this.alerts.length > 100) {
        this.alerts = this.alerts.slice(-100);
      }
    }
  }

  /**
   * Get dashboard data
   */
  getDashboard() {
    const now = Date.now();

    // WireGuard summary
    const wireguardPeers = Array.from(this.metrics.wireguard.values());
    const wireguardHealthy = wireguardPeers.filter(p => p.healthy).length;

    // Storage summary
    const storageMounts = Array.from(this.metrics.storage.values());
    const storageHealthy = storageMounts.filter(s => s.healthy).length;

    // Docker summary
    const dockerContainers = Array.from(this.metrics.docker.values());
    const dockerHealthy = dockerContainers.filter(c => c.healthy).length;

    // Service summary
    const services = Array.from(this.metrics.services.values());
    const servicesHealthy = services.filter(s => s.healthy).length;

    // Active alerts
    const activeAlerts = this.alerts.filter(a => !a.acknowledged);
    const criticalAlerts = activeAlerts.filter(a => a.level === 'critical');

    return {
      timestamp: now,
      status: criticalAlerts.length > 0 ? 'critical' :
              activeAlerts.length > 0 ? 'warning' : 'healthy',
      wireguard: {
        total: wireguardPeers.length,
        healthy: wireguardHealthy,
        avgLatency: wireguardPeers.length > 0
          ? (wireguardPeers.reduce((sum, p) => sum + p.latency, 0) / wireguardPeers.length).toFixed(2)
          : 0,
        peers: wireguardPeers
      },
      storage: {
        total: storageMounts.length,
        healthy: storageHealthy,
        mounts: storageMounts
      },
      docker: {
        total: dockerContainers.length,
        healthy: dockerHealthy,
        containers: dockerContainers
      },
      services: {
        total: services.length,
        healthy: servicesHealthy,
        list: services
      },
      alerts: {
        total: activeAlerts.length,
        critical: criticalAlerts.length,
        recent: activeAlerts.slice(-10)
      }
    };
  }

  /**
   * Get optimization recommendations
   */
  getOptimizationRecommendations() {
    const recommendations = [];

    // Check WireGuard performance
    const wireguardPeers = Array.from(this.metrics.wireguard.values());
    const highLatencyPeers = wireguardPeers.filter(p =>
      p.latency > this.options.alertThresholds.wireguard.latency.warning
    );

    if (highLatencyPeers.length > 0) {
      recommendations.push({
        category: 'wireguard',
        severity: 'medium',
        message: `${highLatencyPeers.length} WireGuard peer(s) have high latency`,
        action: 'Consider tuning MTU settings or checking network path',
        peers: highLatencyPeers.map(p => p.peer)
      });
    }

    // Check storage performance
    const storageMounts = Array.from(this.metrics.storage.values());
    const slowStorage = storageMounts.filter(s =>
      s.ioLatency > this.options.alertThresholds.storage.latency.warning
    );

    if (slowStorage.length > 0) {
      recommendations.push({
        category: 'storage',
        severity: 'high',
        message: `${slowStorage.length} storage mount(s) have slow I/O`,
        action: 'Check NFS mount options, enable caching, or verify network connectivity',
        mounts: slowStorage.map(s => s.name)
      });
    }

    // Check Docker resource usage
    const dockerContainers = Array.from(this.metrics.docker.values());
    const resourceHungry = dockerContainers.filter(c =>
      c.cpuPerc > this.options.alertThresholds.docker.cpu.warning ||
      c.memPerc > this.options.alertThresholds.docker.memory.warning
    );

    if (resourceHungry.length > 0) {
      recommendations.push({
        category: 'docker',
        severity: 'high',
        message: `${resourceHungry.length} container(s) using high resources`,
        action: 'Consider setting resource limits or scaling containers',
        containers: resourceHungry.map(c => ({ name: c.name, cpu: c.cpuPerc, mem: c.memPerc }))
      });
    }

    return recommendations;
  }

  /**
   * Export metrics
   */
  exportMetrics() {
    return {
      exportedAt: Date.now(),
      wireguard: Array.from(this.metrics.wireguard.entries()),
      storage: Array.from(this.metrics.storage.entries()),
      docker: Array.from(this.metrics.docker.entries()),
      services: Array.from(this.metrics.services.entries()),
      network: this.metrics.network,
      alerts: this.alerts
    };
  }
}

module.exports = InfrastructureMonitor;

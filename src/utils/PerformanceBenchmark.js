/**
 * Performance Benchmarking Utility
 * Comprehensive benchmarking for infrastructure components
 *
 * @features
 * - Network throughput testing
 * - Storage I/O benchmarking
 * - Docker container performance
 * - WireGuard latency and bandwidth
 * - Service response time testing
 * - Automated baseline comparison
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const execAsync = promisify(exec);
const fs = require('fs').promises;
const path = require('path');
const os = require('os');

class PerformanceBenchmark {
  constructor(options = {}) {
    this.options = {
      outputDir: options.outputDir || '/tmp/performance-benchmarks',
      iterations: options.iterations || 3,
      timeout: options.timeout || 60000,
      baseline: options.baseline || null,
      ...options
    };

    this.results = {
      timestamp: Date.now(),
      hostname: os.hostname(),
      platform: os.platform(),
      benchmarks: {}
    };
  }

  /**
   * Run all benchmarks
   */
  async runAll() {
    console.log('Starting comprehensive performance benchmarks...\n');

    await this.ensureOutputDir();

    await this.benchmarkNetwork();
    await this.benchmarkStorage();
    await this.benchmarkDocker();
    await this.benchmarkWireGuard();
    await this.benchmarkServices();

    await this.saveResults();
    await this.compareWithBaseline();

    return this.results;
  }

  /**
   * Ensure output directory exists
   */
  async ensureOutputDir() {
    try {
      await fs.mkdir(this.options.outputDir, { recursive: true });
    } catch (error) {
      console.error('Failed to create output directory:', error.message);
    }
  }

  /**
   * Benchmark network performance
   */
  async benchmarkNetwork() {
    console.log('📡 Benchmarking network performance...');

    const networkTests = [];

    // Test WireGuard mesh peers
    const wireguardPeers = [
      { ip: '10.6.0.5', name: 'FGSRV6 Hub' },
      { ip: '10.6.0.12', name: 'AGLSRV6' },
      { ip: '10.6.0.20', name: 'CT111 NFS' }
    ];

    for (const peer of wireguardPeers) {
      const latency = await this.measureLatency(peer.ip);
      const bandwidth = await this.measureBandwidth(peer.ip);

      networkTests.push({
        peer: peer.name,
        ip: peer.ip,
        latency,
        bandwidth
      });

      console.log(`  ✓ ${peer.name} (${peer.ip}): ${latency.avg}ms latency, ${bandwidth.mbps}Mbps`);
    }

    this.results.benchmarks.network = networkTests;
  }

  /**
   * Measure network latency
   */
  async measureLatency(host, count = 10) {
    try {
      const { stdout } = await execAsync(`ping -c ${count} -W 2 ${host}`);

      const match = stdout.match(/rtt min\/avg\/max\/mdev = ([\d.]+)\/([\d.]+)\/([\d.]+)\/([\d.]+)/);

      if (match) {
        return {
          min: parseFloat(match[1]),
          avg: parseFloat(match[2]),
          max: parseFloat(match[3]),
          mdev: parseFloat(match[4])
        };
      }
    } catch (error) {
      return { min: 999, avg: 999, max: 999, mdev: 999 };
    }

    return null;
  }

  /**
   * Measure network bandwidth (simplified iperf3 simulation)
   */
  async measureBandwidth(host) {
    try {
      // Use dd with network copy as bandwidth proxy
      const testFile = `/tmp/bandwidth-test-${Date.now()}`;
      const { stdout } = await execAsync(
        `dd if=/dev/zero bs=1M count=50 2>&1 | ssh root@${host} "cat > /dev/null" 2>&1 || echo "0 MB/s"`,
        { timeout: 30000 }
      );

      const match = stdout.match(/([\d.]+)\s+MB\/s/);
      const mbps = match ? parseFloat(match[1]) * 8 : 0;

      return { mbps: mbps.toFixed(2) };
    } catch (error) {
      return { mbps: 0 };
    }
  }

  /**
   * Benchmark storage performance
   */
  async benchmarkStorage() {
    console.log('\n💾 Benchmarking storage performance...');

    const storagePaths = [
      { path: '/mnt/pve/fgsrv6-wg', name: 'FGSRV6 NFS' },
      { path: '/mnt/pve/ct111-shares', name: 'CT111 Shares NFS' },
      { path: '/mnt/pve/aglsrv6-bb', name: 'AGLSRV6 BB SSHFS' }
    ];

    const storageTests = [];

    for (const storage of storagePaths) {
      try {
        await fs.access(storage.path);

        const write = await this.benchmarkStorageWrite(storage.path);
        const read = await this.benchmarkStorageRead(storage.path);

        storageTests.push({
          name: storage.name,
          path: storage.path,
          write,
          read
        });

        console.log(`  ✓ ${storage.name}: Write ${write.mbps}MB/s, Read ${read.mbps}MB/s`);
      } catch (error) {
        console.log(`  ⚠ ${storage.name}: Not accessible`);
      }
    }

    this.results.benchmarks.storage = storageTests;
  }

  /**
   * Benchmark storage write performance
   */
  async benchmarkStorageWrite(storagePath) {
    const testFile = path.join(storagePath, `.benchmark-write-${Date.now()}`);

    try {
      const { stdout } = await execAsync(
        `dd if=/dev/zero of=${testFile} bs=1M count=100 conv=fdatasync 2>&1`,
        { timeout: this.options.timeout }
      );

      // Cleanup
      await execAsync(`rm -f ${testFile}`);

      const match = stdout.match(/([\d.]+)\s+MB\/s/);
      const mbps = match ? parseFloat(match[1]) : 0;

      return { mbps: mbps.toFixed(2) };
    } catch (error) {
      return { mbps: 0, error: error.message };
    }
  }

  /**
   * Benchmark storage read performance
   */
  async benchmarkStorageRead(storagePath) {
    const testFile = path.join(storagePath, `.benchmark-read-${Date.now()}`);

    try {
      // Create test file
      await execAsync(`dd if=/dev/zero of=${testFile} bs=1M count=100 2>&1`, { timeout: 30000 });

      // Clear cache
      await execAsync('sync; echo 3 > /proc/sys/vm/drop_caches 2>/dev/null || true');

      // Read test
      const { stdout } = await execAsync(
        `dd if=${testFile} of=/dev/null bs=1M 2>&1`,
        { timeout: this.options.timeout }
      );

      // Cleanup
      await execAsync(`rm -f ${testFile}`);

      const match = stdout.match(/([\d.]+)\s+MB\/s/);
      const mbps = match ? parseFloat(match[1]) : 0;

      return { mbps: mbps.toFixed(2) };
    } catch (error) {
      return { mbps: 0, error: error.message };
    }
  }

  /**
   * Benchmark Docker container performance
   */
  async benchmarkDocker() {
    console.log('\n🐳 Benchmarking Docker performance...');

    try {
      const { stdout } = await execAsync('docker ps --format "{{.Names}}"');
      const containers = stdout.trim().split('\n').filter(Boolean);

      const dockerTests = [];

      for (const container of containers.slice(0, 5)) {
        const stats = await this.getDockerStats(container);

        dockerTests.push({
          container,
          stats
        });

        console.log(`  ✓ ${container}: ${stats.cpuPerc}% CPU, ${stats.memPerc}% Memory`);
      }

      this.results.benchmarks.docker = dockerTests;
    } catch (error) {
      console.log('  ⚠ Docker not available');
      this.results.benchmarks.docker = [];
    }
  }

  /**
   * Get Docker container stats
   */
  async getDockerStats(container) {
    try {
      const { stdout } = await execAsync(
        `docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemPerc}}" ${container}`
      );

      const [cpuPerc, memPerc] = stdout.trim().split('\t');

      return {
        cpuPerc: parseFloat(cpuPerc),
        memPerc: parseFloat(memPerc)
      };
    } catch (error) {
      return { cpuPerc: 0, memPerc: 0 };
    }
  }

  /**
   * Benchmark WireGuard performance
   */
  async benchmarkWireGuard() {
    console.log('\n🔐 Benchmarking WireGuard performance...');

    try {
      const { stdout } = await execAsync('wg show wg0 dump');
      const lines = stdout.trim().split('\n');

      const wireguardTests = [];

      for (let i = 1; i < Math.min(lines.length, 6); i++) {
        const parts = lines[i].split('\t');

        if (parts.length >= 8) {
          const endpoint = parts[2];
          const latestHandshake = parseInt(parts[4]);
          const rxBytes = parseInt(parts[5]);
          const txBytes = parseInt(parts[6]);

          const handshakeAge = Date.now() / 1000 - latestHandshake;

          wireguardTests.push({
            endpoint,
            handshakeAge: handshakeAge.toFixed(0),
            rxMB: (rxBytes / 1024 / 1024).toFixed(2),
            txMB: (txBytes / 1024 / 1024).toFixed(2)
          });

          console.log(`  ✓ ${endpoint}: Handshake ${handshakeAge.toFixed(0)}s ago`);
        }
      }

      this.results.benchmarks.wireguard = wireguardTests;
    } catch (error) {
      console.log('  ⚠ WireGuard not available');
      this.results.benchmarks.wireguard = [];
    }
  }

  /**
   * Benchmark critical services
   */
  async benchmarkServices() {
    console.log('\n🔧 Benchmarking service performance...');

    const services = [
      { host: '192.168.0.183', port: 8051, name: 'Archon MCP' },
      { host: '192.168.0.183', port: 8181, name: 'Archon API' },
      { host: '192.168.0.180', port: 3000, name: 'Dokploy' }
    ];

    const serviceTests = [];

    for (const service of services) {
      const responseTime = await this.measureServiceResponse(service.host, service.port);

      serviceTests.push({
        name: service.name,
        host: service.host,
        port: service.port,
        responseTime
      });

      console.log(`  ✓ ${service.name}: ${responseTime}ms response time`);
    }

    this.results.benchmarks.services = serviceTests;
  }

  /**
   * Measure service response time
   */
  async measureServiceResponse(host, port) {
    const start = Date.now();

    try {
      await execAsync(
        `timeout 5 bash -c 'cat < /dev/null > /dev/tcp/${host}/${port}'`
      );

      return Date.now() - start;
    } catch (error) {
      return 9999;
    }
  }

  /**
   * Save results to file
   */
  async saveResults() {
    const filename = `benchmark-${Date.now()}.json`;
    const filepath = path.join(this.options.outputDir, filename);

    try {
      await fs.writeFile(filepath, JSON.stringify(this.results, null, 2));
      console.log(`\n✅ Results saved to: ${filepath}`);
    } catch (error) {
      console.error('Failed to save results:', error.message);
    }
  }

  /**
   * Compare with baseline
   */
  async compareWithBaseline() {
    if (!this.options.baseline) {
      console.log('\n📊 No baseline provided for comparison');
      return;
    }

    try {
      const baselineData = await fs.readFile(this.options.baseline, 'utf8');
      const baseline = JSON.parse(baselineData);

      console.log('\n📊 Comparison with baseline:');

      // Compare network latency
      if (baseline.benchmarks.network && this.results.benchmarks.network) {
        console.log('\n  Network:');
        baseline.benchmarks.network.forEach((baselinePeer, index) => {
          const currentPeer = this.results.benchmarks.network[index];

          if (currentPeer) {
            const diff = ((currentPeer.latency.avg - baselinePeer.latency.avg) / baselinePeer.latency.avg * 100).toFixed(1);
            const indicator = diff > 0 ? '📈' : '📉';

            console.log(`    ${indicator} ${currentPeer.peer}: ${diff}% latency change`);
          }
        });
      }

      // Compare storage performance
      if (baseline.benchmarks.storage && this.results.benchmarks.storage) {
        console.log('\n  Storage:');
        baseline.benchmarks.storage.forEach((baselineStorage, index) => {
          const currentStorage = this.results.benchmarks.storage[index];

          if (currentStorage) {
            const writeDiff = ((currentStorage.write.mbps - baselineStorage.write.mbps) / baselineStorage.write.mbps * 100).toFixed(1);
            const indicator = writeDiff > 0 ? '📈' : '📉';

            console.log(`    ${indicator} ${currentStorage.name}: ${writeDiff}% write speed change`);
          }
        });
      }
    } catch (error) {
      console.log('⚠ Could not load baseline for comparison:', error.message);
    }
  }

  /**
   * Get summary report
   */
  getSummary() {
    return {
      timestamp: this.results.timestamp,
      hostname: this.results.hostname,
      summary: {
        network: this.results.benchmarks.network?.length || 0,
        storage: this.results.benchmarks.storage?.length || 0,
        docker: this.results.benchmarks.docker?.length || 0,
        wireguard: this.results.benchmarks.wireguard?.length || 0,
        services: this.results.benchmarks.services?.length || 0
      }
    };
  }
}

module.exports = PerformanceBenchmark;

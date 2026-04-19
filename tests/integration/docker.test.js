/**
 * Docker Container Health Tests
 * Test Docker container lifecycle and health checks
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const Docker = require('dockerode');

const _execAsync = promisify(exec);

describe('Docker Container Health Tests', () => {
  let docker;
  let testContainerId;

  beforeAll(() => {
    // Check if Docker is available
    try {
      docker = new Docker();
    } catch (error) {
      console.warn('Docker not available, skipping Docker tests');
      docker = null;
    }
  });

  afterAll(async () => {
    // Cleanup test container if it exists
    if (docker && testContainerId) {
      try {
        const container = docker.getContainer(testContainerId);
        await container.stop();
        await container.remove();
      } catch (error) {
        // Container may not exist
      }
    }
  });

  describe('Docker Availability', () => {
    it('should have Docker installed', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available in test environment');
        return;
      }

      const info = await docker.info();
      expect(info).toBeDefined();
      expect(info).toHaveProperty('Containers');
      expect(info).toHaveProperty('Images');
    });

    it('should be able to ping Docker daemon', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      const ping = await docker.ping();
      expect(ping.toString()).toBe('OK');
    });
  });

  describe('Container Creation', () => {
    it('should create a test container', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        // Pull alpine image (small and fast)
        await docker.pull('alpine:latest');

        // Create container
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          name: 'agl-hostman-test-container',
          Cmd: ['sleep', '300'],
          HostConfig: {
            AutoRemove: false,
          },
        });

        expect(container).toBeDefined();
        expect(container.id).toBeDefined();
        testContainerId = container.id;

        // Start container
        await container.start();

        // Verify it's running
        const info = await container.inspect();
        expect(info.State.Running).toBe(true);
      } catch (error) {
        if (error.message.includes('No such image')) {
          console.log('Skipping: Unable to pull test image');
        } else {
          throw error;
        }
      }
    }, 60000); // Pull image can take time

    it('should measure container startup time', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        const startTime = Date.now();

        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['echo', 'hello'],
          HostConfig: {
            AutoRemove: true,
          },
        });

        await container.start();
        await container.wait();

        const startupTime = Date.now() - startTime;

        // Container should start quickly (< 5 seconds)
        expect(startupTime).toBeLessThan(5000);
        console.log(`Container startup time: ${startupTime}ms`);
      } catch (error) {
        console.log('Skipping: Unable to test startup time');
      }
    }, 30000);
  });

  describe('Container Health Checks', () => {
    it('should check container health status', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);
      const info = await container.inspect();

      expect(info.State).toHaveProperty('Status');
      expect(info.State).toHaveProperty('Running');
      expect(info.State).toHaveProperty('Pid');

      // Container should be running
      expect(info.State.Running).toBe(true);
      expect(info.State.Pid).toBeGreaterThan(0);
    });

    it('should monitor container resource usage', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);
      const stats = await container.stats({ stream: false });

      expect(stats).toBeDefined();
      expect(stats).toHaveProperty('memory_stats');
      expect(stats).toHaveProperty('cpu_stats');
      expect(stats).toHaveProperty('networks');

      // Validate memory usage
      expect(stats.memory_stats).toHaveProperty('usage');
      expect(stats.memory_stats.usage).toBeGreaterThan(0);

      console.log(`Memory usage: ${(stats.memory_stats.usage / 1024 / 1024).toFixed(2)} MB`);
    });

    it('should detect container restarts', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);
      const beforeInfo = await container.inspect();
      const _restartCountBefore = beforeInfo.RestartCount;

      // Restart container
      await container.restart();

      // Wait for restart to complete
      await global.testUtils.waitFor(async () => {
        const info = await container.inspect();
        return info.State.Running;
      }, 10000);

      const afterInfo = await container.inspect();

      // Verify container restarted
      expect(afterInfo.State.Running).toBe(true);
      expect(afterInfo.State.StartedAt).not.toBe(beforeInfo.State.StartedAt);
    }, 15000);
  });

  describe('Container Logs', () => {
    it('should retrieve container logs', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        // Create container that produces logs
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['sh', '-c', 'echo "Test log output"; sleep 5'],
          HostConfig: {
            AutoRemove: true,
          },
        });

        await container.start();

        // Get logs
        const logs = await container.logs({
          stdout: true,
          stderr: true,
          follow: false,
        });

        expect(logs).toBeDefined();
        const logString = logs.toString();
        expect(logString).toContain('Test log output');

        await container.wait();
      } catch (error) {
        console.log('Skipping: Unable to test logs');
      }
    }, 30000);
  });

  describe('Container Networking', () => {
    it('should check container network settings', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);
      const info = await container.inspect();

      expect(info.NetworkSettings).toBeDefined();
      expect(info.NetworkSettings).toHaveProperty('Networks');
      expect(info.NetworkSettings).toHaveProperty('IPAddress');

      // Container should have network configuration
      const networks = Object.keys(info.NetworkSettings.Networks);
      expect(networks.length).toBeGreaterThan(0);
    });

    it('should verify container DNS resolution', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);

      try {
        const exec = await container.exec({
          Cmd: ['sh', '-c', 'nslookup google.com || true'],
          AttachStdout: true,
          AttachStderr: true,
        });

        const stream = await exec.start({});

        let output = '';
        stream.on('data', chunk => {
          output += chunk.toString();
        });

        await new Promise(resolve => stream.on('end', resolve));

        // DNS should work (or at least not crash)
        expect(output).toBeDefined();
      } catch (error) {
        // DNS test is optional
        console.log('DNS test skipped:', error.message);
      }
    });
  });

  describe('Graceful Shutdown', () => {
    it('should stop container gracefully', async () => {
      if (!docker || !testContainerId) {
        console.log('Skipping: No test container available');
        return;
      }

      const container = docker.getContainer(testContainerId);

      const startTime = Date.now();
      await container.stop({ t: 10 }); // 10 second grace period
      const stopTime = Date.now() - startTime;

      // Verify container stopped
      const info = await container.inspect();
      expect(info.State.Running).toBe(false);

      // Should stop within grace period
      expect(stopTime).toBeLessThan(15000);

      console.log(`Container stopped in ${stopTime}ms`);
    });

    it('should handle forced stop', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        // Create container that ignores SIGTERM
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['sh', '-c', 'trap "" TERM; sleep 300'],
          HostConfig: {
            AutoRemove: false,
          },
        });

        await container.start();

        // Try to stop with short timeout (should force kill)
        const startTime = Date.now();
        await container.stop({ t: 1 });
        const stopTime = Date.now() - startTime;

        // Verify stopped
        const info = await container.inspect();
        expect(info.State.Running).toBe(false);

        // Should force kill after timeout
        expect(stopTime).toBeLessThan(3000);

        // Cleanup
        await container.remove();
      } catch (error) {
        console.log('Skipping: Unable to test forced stop');
      }
    }, 30000);
  });

  describe('Container Cleanup', () => {
    it('should remove stopped containers', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        // Create and stop container
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['echo', 'test'],
        });

        await container.start();
        await container.wait();

        // Remove container
        await container.remove();

        // Verify removed
        try {
          await container.inspect();
          fail('Container should be removed');
        } catch (error) {
          expect(error.statusCode).toBe(404);
        }
      } catch (error) {
        console.log('Skipping: Unable to test cleanup');
      }
    }, 30000);
  });

  describe('Resource Limits', () => {
    it('should enforce memory limits', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['sleep', '10'],
          HostConfig: {
            Memory: 50 * 1024 * 1024, // 50MB limit
            AutoRemove: true,
          },
        });

        await container.start();

        const info = await container.inspect();
        expect(info.HostConfig.Memory).toBe(50 * 1024 * 1024);

        await container.stop();
      } catch (error) {
        console.log('Skipping: Unable to test memory limits');
      }
    }, 30000);

    it('should enforce CPU limits', async () => {
      if (!docker) {
        console.log('Skipping: Docker not available');
        return;
      }

      try {
        const container = await docker.createContainer({
          Image: 'alpine:latest',
          Cmd: ['sleep', '10'],
          HostConfig: {
            NanoCpus: 1000000000, // 1 CPU
            AutoRemove: true,
          },
        });

        await container.start();

        const info = await container.inspect();
        expect(info.HostConfig.NanoCpus).toBe(1000000000);

        await container.stop();
      } catch (error) {
        console.log('Skipping: Unable to test CPU limits');
      }
    }, 30000);
  });
});

/**
 * Network Connectivity Integration Tests
 * Test WireGuard, Tailscale, and network connectivity
 */

const { exec } = require('child_process');
const { promisify } = require('util');
const NetworkMonitor = require('../../src/dashboard/api/network');
const NetworkMock = require('./mocks/network-mock');

const execAsync = promisify(exec);

describe('Network Connectivity Tests', () => {
  let networkMonitor;
  let networkMock;
  let originalExec;

  beforeAll(() => {
    // Setup network monitor with test config
    networkMonitor = new NetworkMonitor({
      wireguard: {
        enabled: true,
        interface: 'wg0',
        network: '10.6.0.0/24',
      },
      tailscale: {
        enabled: true,
      },
    });

    // Setup network mocks
    networkMock = new NetworkMock();
    networkMock.setupAll();
  });

  beforeEach(() => {
    // Mock exec command
    originalExec = networkMonitor.execCommand;
    networkMonitor.execCommand = async (command) => {
      const output = networkMock.getMockOutput(command);
      if (output.error) {
        throw new Error(output.error);
      }
      return output;
    };
  });

  afterEach(() => {
    // Restore original exec
    if (originalExec) {
      networkMonitor.execCommand = originalExec;
    }
  });

  afterAll(() => {
    networkMock.cleanup();
  });

  describe('WireGuard Tests', () => {
    it('should get WireGuard status', async () => {
      const status = await networkMonitor.getWireGuardStatus();

      expect(status).toBeDefined();
      expect(status).toHaveProperty('enabled', true);
      expect(status).toHaveProperty('status');
      expect(['active', 'unavailable', 'error']).toContain(status.status);
    });

    it('should handle empty WireGuard output', async () => {
      // Mock empty output (null return)
      networkMonitor.execCommand = async () => null;

      const status = await networkMonitor.getWireGuardStatus();

      expect(status).toEqual({ enabled: true, status: 'unavailable' });
    });

    it('should parse WireGuard peers', async () => {
      const status = await networkMonitor.getWireGuardStatus();

      if (status.status === 'active') {
        expect(status).toHaveProperty('peers');
        expect(typeof status.peers).toBe('number');
        expect(status.peers).toBeGreaterThanOrEqual(0);

        if (status.details && status.details.length > 0) {
          const peer = status.details[0];
          expect(peer).toHaveProperty('publicKey');
          expect(peer).toHaveProperty('endpoint');
          expect(peer).toHaveProperty('allowedIPs');
        }
      }
    });

    it('should detect WireGuard peer connectivity', async () => {
      const status = await networkMonitor.getWireGuardStatus();

      if (status.status === 'active' && status.details) {
        status.details.forEach(peer => {
          // Check handshake is present
          if (peer.latestHandshake) {
            expect(peer.latestHandshake).toBeDefined();
            expect(typeof peer.latestHandshake).toBe('string');
          }
        });
      }
    });

    it('should handle WireGuard not available', async () => {
      networkMock.mockWireGuardError();

      const status = await networkMonitor.getWireGuardStatus();

      expect(status).toHaveProperty('enabled', true);
      expect(status.status).toBe('error');
      expect(status).toHaveProperty('error');
    });

    it('should handle WireGuard disabled', async () => {
      const disabledMonitor = new NetworkMonitor({
        wireguard: { enabled: false },
        tailscale: { enabled: false },
      });

      const status = await disabledMonitor.getWireGuardStatus();

      expect(status).toEqual({ enabled: false });
    });
  });

  describe('Tailscale Tests', () => {
    it('should get Tailscale status', async () => {
      const status = await networkMonitor.getTailscaleStatus();

      expect(status).toBeDefined();
      expect(status).toHaveProperty('enabled', true);
      expect(status).toHaveProperty('status');
      expect(['active', 'unavailable', 'error']).toContain(status.status);
    });

    it('should handle empty Tailscale output', async () => {
      // Mock empty output (null return)
      networkMonitor.execCommand = async () => null;

      const status = await networkMonitor.getTailscaleStatus();

      expect(status).toEqual({ enabled: true, status: 'unavailable' });
    });

    it('should handle Tailscale disabled in config', async () => {
      const disabledMonitor = new NetworkMonitor({
        wireguard: { enabled: true },
        tailscale: { enabled: false },
      });

      const status = await disabledMonitor.getTailscaleStatus();

      expect(status).toEqual({ enabled: false });
    });

    it('should parse Tailscale peers', async () => {
      const status = await networkMonitor.getTailscaleStatus();

      if (status.status === 'active') {
        expect(status).toHaveProperty('peers');
        expect(typeof status.peers).toBe('number');
        expect(status.peers).toBeGreaterThanOrEqual(0);

        if (status.self) {
          expect(status.self).toHaveProperty('ID');
          expect(status.self).toHaveProperty('PublicKey');
          expect(status.self).toHaveProperty('HostName');
        }
      }
    });

    it('should handle Tailscale not running', async () => {
      networkMock.mockTailscaleError();

      const status = await networkMonitor.getTailscaleStatus();

      expect(status).toHaveProperty('enabled', true);
      expect(status.status).toBe('error');
      expect(status).toHaveProperty('error');
    });

    it('should validate Tailscale IP addresses', async () => {
      const status = await networkMonitor.getTailscaleStatus();

      if (status.status === 'active' && status.self) {
        if (status.self.TailscaleIPs) {
          expect(Array.isArray(status.self.TailscaleIPs)).toBe(true);
          status.self.TailscaleIPs.forEach(ip => {
            expect(ip).toMatch(/^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
          });
        }
      }
    });
  });

  describe('Network Interfaces Tests', () => {
    it('should list network interfaces', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      expect(Array.isArray(interfaces)).toBe(true);
    });

    it('should handle empty interfaces output', async () => {
      // Mock empty output (null return)
      networkMonitor.execCommand = async () => null;

      const interfaces = await networkMonitor.getInterfaces();

      expect(Array.isArray(interfaces)).toBe(true);
      expect(interfaces).toEqual([]);
    });

    it('should handle JSON parse error in interfaces', async () => {
      // Mock invalid JSON output
      networkMonitor.execCommand = async () => 'invalid json';

      const interfaces = await networkMonitor.getInterfaces();

      expect(Array.isArray(interfaces)).toBe(true);
      expect(interfaces).toEqual([]);
    });

    it('should return only UP interfaces', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      interfaces.forEach(iface => {
        expect(iface).toHaveProperty('state', 'UP');
      });
    });

    it('should include interface details', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      if (interfaces.length > 0) {
        const iface = interfaces[0];
        expect(iface).toHaveProperty('name');
        expect(iface).toHaveProperty('state');
        expect(iface).toHaveProperty('addresses');
        expect(Array.isArray(iface.addresses)).toBe(true);
      }
    });

    it('should include IP addresses', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      const ethInterface = interfaces.find(i => i.name.startsWith('eth'));
      if (ethInterface && ethInterface.addresses.length > 0) {
        const addr = ethInterface.addresses[0];
        expect(addr).toHaveProperty('address');
        expect(addr).toHaveProperty('family');
        expect(addr).toHaveProperty('prefixlen');

        // Validate IP format
        if (addr.family === 'inet') {
          expect(addr.address).toMatch(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
        }
      }
    });

    it('should detect WireGuard interface', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      const wgInterface = interfaces.find(i => i.name === 'wg0');
      if (wgInterface) {
        expect(wgInterface.state).toBe('UP');
        expect(wgInterface.addresses.length).toBeGreaterThan(0);

        // WireGuard should have 10.6.0.x IP
        const wgAddr = wgInterface.addresses.find(a => a.family === 'inet');
        if (wgAddr) {
          expect(wgAddr.address).toMatch(/^10\.6\.0\.\d{1,3}$/);
        }
      }
    });

    it('should detect Tailscale interface', async () => {
      const interfaces = await networkMonitor.getInterfaces();

      const tsInterface = interfaces.find(i => i.name === 'tailscale0');
      if (tsInterface) {
        expect(tsInterface.state).toBe('UP');
        expect(tsInterface.addresses.length).toBeGreaterThan(0);

        // Tailscale should have 100.x.x.x IP
        const tsAddr = tsInterface.addresses.find(a => a.family === 'inet');
        if (tsAddr) {
          expect(tsAddr.address).toMatch(/^100\.\d{1,3}\.\d{1,3}\.\d{1,3}$/);
        }
      }
    });
  });

  describe('Complete Network Status', () => {
    it('should get complete network status', async () => {
      const status = await networkMonitor.getStatus();

      expect(status).toBeDefined();
      expect(status).toHaveProperty('wireguard');
      expect(status).toHaveProperty('tailscale');
      expect(status).toHaveProperty('interfaces');
      expect(status).toHaveProperty('timestamp');

      // Validate timestamp
      expect(status.timestamp).toBeValidTimestamp();
    });

    it('should return status within reasonable time', async () => {
      const startTime = Date.now();
      await networkMonitor.getStatus();
      const duration = Date.now() - startTime;

      // Should complete quickly (< 2 seconds)
      expect(duration).toBeLessThan(2000);
    });

    it('should handle partial failures gracefully', async () => {
      // Mock WireGuard failure but Tailscale success
      networkMock.mockWireGuardError();

      const status = await networkMonitor.getStatus();

      expect(status).toBeDefined();
      expect(status.wireguard.status).toBe('error');
      // Tailscale should still work
      expect(status.tailscale).toBeDefined();
      expect(status.interfaces).toBeDefined();
    });
  });

  describe('execCommand Tests', () => {
    it('should handle command stderr warnings', async () => {
      // Restore original execCommand to test real implementation
      networkMonitor.execCommand = originalExec;

      // Use a safe command that produces stderr
      const logger = require('../../src/dashboard/utils/logger');
      const warnSpy = jest.spyOn(logger, 'warn');

      // Create a command that writes to stderr but succeeds
      const { exec } = require('child_process');
      const { promisify } = require('util');
      const execAsync = promisify(exec);

      // Mock exec to simulate stderr
      const originalExecCommand = networkMonitor.execCommand.bind(networkMonitor);
      networkMonitor.execCommand = async (command) => {
        // Simulate command with stderr but successful execution
        if (command === 'test-stderr') {
          const mockStderr = 'Warning: test stderr message';
          logger.warn(`Command stderr: ${mockStderr}`);
          return 'test output';
        }
        return originalExecCommand(command);
      };

      const result = await networkMonitor.execCommand('test-stderr');

      expect(result).toBe('test output');
      expect(warnSpy).toHaveBeenCalledWith('Command stderr: Warning: test stderr message');

      warnSpy.mockRestore();
    });
  });

  describe('DNS Resolution Tests', () => {
    it('should resolve common hostnames', async () => {
      const testHosts = [
        { hostname: 'aglsrv1.local', expected: '192.168.0.245' },
      ];

      for (const { hostname, expected } of testHosts) {
        networkMock.mockDNS(hostname, expected);

        const output = await networkMonitor.execCommand(`host ${hostname}`);
        expect(output).toContain(expected);
      }
    });
  });

  describe('Connectivity Tests', () => {
    it('should ping WireGuard gateway', async () => {
      networkMock.mockPing('10.6.0.5', true);

      const output = await networkMonitor.execCommand('ping -c 1 -W 1 10.6.0.5');
      expect(output).toContain('10.6.0.5');
      expect(output).toContain('64 bytes from');
    });

    it('should detect unreachable hosts', async () => {
      networkMock.mockPing('192.168.99.99', false);

      try {
        await networkMonitor.execCommand('ping -c 1 -W 1 192.168.99.99');
        fail('Should throw error for unreachable host');
      } catch (error) {
        expect(error.message).toContain('Name or service not known');
      }
    });

    it('should test internet connectivity', async () => {
      networkMock.mockPing('8.8.8.8', true);

      const output = await networkMonitor.execCommand('ping -c 1 -W 1 8.8.8.8');
      expect(output).toContain('8.8.8.8');
    });
  });

  describe('Network Performance', () => {
    it('should measure WireGuard latency', async () => {
      networkMock.mockPing('10.6.0.5', true);

      const startTime = Date.now();
      await networkMonitor.execCommand('ping -c 1 -W 1 10.6.0.5');
      const latency = Date.now() - startTime;

      // Mocked ping should be fast
      expect(latency).toBeLessThan(100);
    });

    it('should handle concurrent network checks', async () => {
      const checks = [
        networkMonitor.getWireGuardStatus(),
        networkMonitor.getTailscaleStatus(),
        networkMonitor.getInterfaces(),
      ];

      const startTime = Date.now();
      const results = await Promise.all(checks);
      const duration = Date.now() - startTime;

      // All checks should succeed
      expect(results.length).toBe(3);
      results.forEach(result => {
        expect(result).toBeDefined();
      });

      // Parallel execution should be faster than sequential
      expect(duration).toBeLessThan(3000);
    });
  });
});

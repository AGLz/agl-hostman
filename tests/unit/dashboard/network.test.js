/**
 * Network Monitor Unit Tests
 *
 * Comprehensive unit tests for NetworkMonitor class
 * @version 1.0.0
 */

// Mock child_process BEFORE importing NetworkMonitor
const mockExecAsync = jest.fn();

jest.mock('util', () => ({
  promisify: jest.fn(() => mockExecAsync),
  __esModule: true,
}));

jest.mock('../../../src/dashboard/utils/logger', () => ({
  error: jest.fn(),
  warn: jest.fn(),
  info: jest.fn(),
  debug: jest.fn(),
}));

const NetworkMonitor = require('../../../src/dashboard/api/network');

describe('NetworkMonitor - Unit Tests', () => {
  let networkMonitor;

  beforeEach(() => {
    // Reset all mocks
    jest.clearAllMocks();

    // Create network monitor instance
    networkMonitor = new NetworkMonitor({
      wireguard: { enabled: true, interface: 'wg0' },
      tailscale: { enabled: true },
    });
  });

  describe('TC-NET-001: Initialization', () => {
    test('should initialize with default config', () => {
      const defaultMonitor = new NetworkMonitor();
      expect(defaultMonitor.config).toBeDefined();
      expect(defaultMonitor.config.wireguard.enabled).toBe(true);
      expect(defaultMonitor.config.tailscale.enabled).toBe(true);
    });

    test('should accept custom configuration', () => {
      const customMonitor = new NetworkMonitor({
        wireguard: { enabled: false },
        tailscale: { enabled: false },
      });
      expect(customMonitor.config.wireguard.enabled).toBe(false);
      expect(customMonitor.config.tailscale.enabled).toBe(false);
    });

    test('should merge custom config with defaults', () => {
      const customMonitor = new NetworkMonitor({
        wireguard: { interface: 'wg1' },
      });
      expect(customMonitor.config.wireguard.interface).toBe('wg1');
      expect(customMonitor.config.wireguard.enabled).toBe(true);
    });
  });

  describe('TC-NET-002: WireGuard Status', () => {
    test('should return disabled status when WireGuard disabled', async () => {
      const monitor = new NetworkMonitor({
        wireguard: { enabled: false },
      });

      const status = await monitor.getWireGuardStatus();
      expect(status).toEqual({ enabled: false });
    });

    test('should return active status with valid WireGuard output', async () => {
      mockExecAsync.mockResolvedValue('wg0: ... peer data ...');

      const status = await networkMonitor.getWireGuardStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('active');
      expect(status.peers).toBeDefined();
      expect(status.details).toBeDefined();
    });

    test('should return unavailable when WireGuard not responding', async () => {
      mockExecAsync.mockResolvedValue('');

      const status = await networkMonitor.getWireGuardStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('unavailable');
    });

    test('should return error status on command failure', async () => {
      const error = new Error('Command failed');
      mockExecAsync.mockRejectedValue(error);

      const status = await networkMonitor.getWireGuardStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('error');
      expect(status.error).toBeDefined();
    });

    test('should log error when command fails', async () => {
      const error = new Error('Test error');
      mockExecAsync.mockRejectedValue(error);

      await networkMonitor.getWireGuardStatus();

      const logger = require('../../../src/dashboard/utils/logger');
      expect(logger.error).toHaveBeenCalledWith(
        expect.stringContaining('Command failed'),
        error
      );
    });
  });

  describe('TC-NET-003: Tailscale Status', () => {
    test('should return disabled status when Tailscale disabled', async () => {
      const monitor = new NetworkMonitor({
        tailscale: { enabled: false },
      });

      const status = await monitor.getTailscaleStatus();
      expect(status).toEqual({ enabled: false });
    });

    test('should return active status with valid Tailscale output', async () => {
      const mockOutput = JSON.stringify({
        Peer: { peer1: {}, peer2: {} },
        Self: { TailscaleIPs: ['100.x.x.x'] },
      });
      mockExecAsync.mockResolvedValue(mockOutput);

      const status = await networkMonitor.getTailscaleStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('active');
      expect(status.peers).toBe(2);
      expect(status.self).toBeDefined();
    });

    test('should return unavailable when Tailscale not responding', async () => {
      mockExecAsync.mockResolvedValue('');

      const status = await networkMonitor.getTailscaleStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('unavailable');
    });

    test('should return error status on command failure', async () => {
      const error = new Error('Tailscale command failed');
      mockExecAsync.mockRejectedValue(error);

      const status = await networkMonitor.getTailscaleStatus();

      expect(status.enabled).toBe(true);
      expect(status.status).toBe('error');
      expect(status.error).toBeDefined();
    });

    test('should handle empty peer list', async () => {
      const mockOutput = JSON.stringify({
        Peer: {},
        Self: { TailscaleIPs: ['100.x.x.x'] },
      });
      mockExecAsync.mockResolvedValue(mockOutput);

      const status = await networkMonitor.getTailscaleStatus();

      expect(status.peers).toBe(0);
    });
  });

  describe('TC-NET-004: Network Interfaces', () => {
    test('should return empty array when command fails', async () => {
      const error = new Error('Command failed');
      mockExecAsync.mockRejectedValue(error);

      const logger = require('../../../src/dashboard/utils/logger');
      const interfaces = await networkMonitor.getInterfaces();

      expect(interfaces).toEqual([]);
      expect(logger.error).toHaveBeenCalled();
    });

    test('should parse valid JSON interface output', async () => {
      const mockInterfaces = [
        {
          ifname: 'eth0',
          operstate: 'UP',
          addr_info: [
            { local: '192.168.1.1', family: 'inet', prefixlen: 24 },
          ],
        },
        {
          ifname: 'eth1',
          operstate: 'DOWN',
          addr_info: [],
        },
      ];
      mockExecAsync.mockResolvedValue(JSON.stringify(mockInterfaces));

      const interfaces = await networkMonitor.getInterfaces();

      expect(interfaces).toHaveLength(1);
      expect(interfaces[0].name).toBe('eth0');
      expect(interfaces[0].state).toBe('UP');
      expect(interfaces[0].addresses).toHaveLength(1);
    });

    test('should filter interfaces by UP state', async () => {
      const mockInterfaces = [
        { ifname: 'eth0', operstate: 'UP', addr_info: [] },
        { ifname: 'eth1', operstate: 'DOWN', addr_info: [] },
        { ifname: 'eth2', operstate: 'UNKNOWN', addr_info: [] },
      ];
      mockExecAsync.mockResolvedValue(JSON.stringify(mockInterfaces));

      const interfaces = await networkMonitor.getInterfaces();

      expect(interfaces).toHaveLength(1);
      expect(interfaces[0].name).toBe('eth0');
    });

    test('should handle interfaces with multiple addresses', async () => {
      const mockInterfaces = [
        {
          ifname: 'eth0',
          operstate: 'UP',
          addr_info: [
            { local: '192.168.1.1', family: 'inet', prefixlen: 24 },
            { local: 'fe80::1', family: 'inet6', prefixlen: 64 },
          ],
        },
      ];
      mockExecAsync.mockResolvedValue(JSON.stringify(mockInterfaces));

      const interfaces = await networkMonitor.getInterfaces();

      expect(interfaces[0].addresses).toHaveLength(2);
    });

    test('should handle empty interface list', async () => {
      mockExecAsync.mockResolvedValue('[]');

      const interfaces = await networkMonitor.getInterfaces();

      expect(interfaces).toEqual([]);
    });

    test('should handle invalid JSON gracefully', async () => {
      mockExecAsync.mockResolvedValue('invalid json');

      await expect(networkMonitor.getInterfaces()).rejects.toThrow();
    });
  });

  describe('TC-NET-005: Combined Status', () => {
    test('should return combined status from all sources', async () => {
      mockExecAsync
        .mockResolvedValueOnce('wg output') // WireGuard
        .mockResolvedValueOnce(JSON.stringify({ Peer: {}, Self: {} })) // Tailscale
        .mockResolvedValueOnce('[]'); // Interfaces

      const status = await networkMonitor.getStatus();

      expect(status.wireguard).toBeDefined();
      expect(status.tailscale).toBeDefined();
      expect(status.interfaces).toBeDefined();
      expect(status.timestamp).toBeDefined();
    });

    test('should fetch all statuses in parallel', async () => {
      mockExecAsync.mockImplementation(() => {
        return new Promise(resolve => {
          setTimeout(() => resolve(''), Math.random() * 10);
        });
      });

      const start = Date.now();
      await networkMonitor.getStatus();
      const duration = Date.now() - start;

      // Should complete in parallel (< 20ms total, not 30ms)
      expect(duration).toBeLessThan(20);
    });

    test('should include ISO timestamp', async () => {
      mockExecAsync.mockResolvedValue('');

      const status = await networkMonitor.getStatus();

      expect(status.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/);
    });
  });

  describe('TC-NET-006: Command Execution', () => {
    test('should execute command and return stdout', async () => {
      mockExecAsync.mockResolvedValue('command output');

      const result = await networkMonitor.execCommand('echo test');

      expect(result).toBe('command output');
      expect(mockExecAsync).toHaveBeenCalledWith('echo test');
    });

    test('should log warnings for stderr output', async () => {
      mockExecAsync.mockResolvedValue({ stdout: 'output', stderr: 'warning message' });

      await networkMonitor.execCommand('test command');

      const logger = require('../../../src/dashboard/utils/logger');
      expect(logger.warn).toHaveBeenCalledWith(
        expect.stringContaining('warning message')
      );
    });

    test('should trim whitespace from output', async () => {
      mockExecAsync.mockResolvedValue('  output with spaces  ');

      const result = await networkMonitor.execCommand('test');

      expect(result).toBe('output with spaces');
    });

    test('should propagate command errors', async () => {
      const error = new Error('Command failed');
      mockExecAsync.mockRejectedValue(error);

      await expect(networkMonitor.execCommand('fail')).rejects.toThrow('Command failed');

      const logger = require('../../../src/dashboard/utils/logger');
      expect(logger.error).toHaveBeenCalled();
    });
  });

  describe('TC-NET-007: Edge Cases', () => {
    test('should handle undefined config gracefully', () => {
      const monitor = new NetworkMonitor(null);

      expect(monitor.config).toBeDefined();
    });

    test('should handle empty config object', () => {
      const monitor = new NetworkMonitor({});

      expect(monitor.config.wireguard).toBeDefined();
      expect(monitor.config.tailscale).toBeDefined();
    });

    test('should handle malformed JSON in Tailscale output', async () => {
      mockExecAsync.mockResolvedValue('not valid json');

      const status = await networkMonitor.getTailscaleStatus();

      expect(status.status).toBe('error');
    });

    test('should handle null output from commands', async () => {
      mockExecAsync.mockResolvedValue(null);

      const status = await networkMonitor.getWireGuardStatus();

      expect(status.status).toBe('unavailable');
    });
  });
});

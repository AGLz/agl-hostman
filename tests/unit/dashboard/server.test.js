/**
 * Dashboard Server Unit Tests
 *
 * Comprehensive unit tests for the Express server
 * @version 1.0.0
 */

const request = require('supertest');
const logger = require('../../../src/dashboard/utils/logger');

// Mock logger before importing server
jest.mock('../../../src/dashboard/utils/logger', () => ({
  info: jest.fn(),
  warn: jest.fn(),
  error: jest.fn(),
  debug: jest.fn(),
}));

describe('Dashboard Server - Unit Tests', () => {
  let app;

  beforeEach(() => {
    // Clear module cache to get fresh instance
    jest.clearAllMocks();
    jest.resetModules();

    // Set test environment
    process.env.NODE_ENV = 'test';

    // Import app
    app = require('../../../src/dashboard/server');
  });

  afterEach(() => {
    // Clean up
    jest.restoreAllMocks();
  });

  describe('TC-SRV-001: Server Initialization', () => {
    test('should export Express app', () => {
      expect(app).toBeDefined();
      expect(typeof app).toBe('function');
    });

    test('should have middleware configured', () => {
      expect(app._router).toBeDefined();
      expect(app._router.stack).toBeDefined();
    });
  });

  describe('TC-SRV-002: Health Check Endpoint', () => {
    test('GET /health should return 200', async () => {
      const response = await request(app).get('/health');

      expect(response.status).toBe(200);
      expect(response.headers['content-type']).toMatch(/json/);
    });

    test('should return health status properties', async () => {
      const response = await request(app).get('/health');

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('environment');
      expect(response.body).toHaveProperty('version');
    });

    test('should return valid ISO 8601 timestamp', async () => {
      const response = await request(app).get('/health');

      expect(response.body.timestamp).toMatch(
        /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/
      );
    });

    test('should return uptime as number', async () => {
      const response = await request(app).get('/health');

      expect(typeof response.body.uptime).toBe('number');
      expect(response.body.uptime).toBeGreaterThanOrEqual(0);
    });

    test('should return test environment', async () => {
      const response = await request(app).get('/health');

      expect(response.body.environment).toBe('test');
    });

    test('should return version from package.json', async () => {
      const response = await request(app).get('/health');

      expect(response.body.version).toBeDefined();
      expect(typeof response.body.version).toBe('string');
    });
  });

  describe('TC-SRV-003: Overview API Endpoint', () => {
    test('GET /api/overview should return 200', async () => {
      const response = await request(app).get('/api/overview');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('should return overview data structure', async () => {
      const response = await request(app).get('/api/overview');

      expect(response.body.data).toHaveProperty('nodes');
      expect(response.body.data).toHaveProperty('containers');
      expect(response.body.data).toHaveProperty('vms');
    });

    test('should return nodes array', async () => {
      const response = await request(app).get('/api/overview');

      expect(Array.isArray(response.body.data.nodes)).toBe(true);
      expect(response.body.data.nodes.length).toBeGreaterThan(0);
    });

    test('should return node with required properties', async () => {
      const response = await request(app).get('/api/overview');
      const node = response.body.data.nodes[0];

      expect(node).toHaveProperty('name');
      expect(node).toHaveProperty('status');
      expect(node).toHaveProperty('cpu');
      expect(node).toHaveProperty('memory');
      expect(node).toHaveProperty('uptime');
    });

    test('should return valid memory structure', async () => {
      const response = await request(app).get('/api/overview');
      const memory = response.body.data.nodes[0].memory;

      expect(memory).toHaveProperty('used');
      expect(memory).toHaveProperty('total');
      expect(memory).toHaveProperty('percent');

      expect(typeof memory.used).toBe('number');
      expect(typeof memory.total).toBe('number');
      expect(typeof memory.percent).toBe('number');
    });

    test('should return container and VM counts', async () => {
      const response = await request(app).get('/api/overview');

      expect(typeof response.body.data.containers).toBe('number');
      expect(typeof response.body.data.vms).toBe('number');
    });
  });

  describe('TC-SRV-004: Containers API Endpoint', () => {
    test('GET /api/containers should return 200', async () => {
      const response = await request(app).get('/api/containers');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('should return containers array', async () => {
      const response = await request(app).get('/api/containers');

      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);
    });

    test('should return container with required properties', async () => {
      const response = await request(app).get('/api/containers');
      const container = response.body.data[0];

      expect(container).toHaveProperty('vmid');
      expect(container).toHaveProperty('name');
      expect(container).toHaveProperty('status');
      expect(container).toHaveProperty('node');
      expect(container).toHaveProperty('type');
    });

    test('should return container resources', async () => {
      const response = await request(app).get('/api/containers');
      const container = response.body.data[0];

      expect(container).toHaveProperty('cpus');
      expect(container).toHaveProperty('maxmem');
      expect(container).toHaveProperty('maxdisk');

      expect(typeof container.cpus).toBe('number');
      expect(typeof container.maxmem).toBe('number');
      expect(typeof container.maxdisk).toBe('number');
    });

    test('should return correct container type', async () => {
      const response = await request(app).get('/api/containers');
      const container = response.body.data[0];

      expect(container.type).toBe('lxc');
    });
  });

  describe('TC-SRV-005: Network API Endpoint', () => {
    test('GET /api/network should return 200', async () => {
      // Mock the NetworkMonitor class
      const NetworkMonitor = require('../../../src/dashboard/api/network');

      // Create a mock instance
      const mockStatus = {
        wireguard: { enabled: true, status: 'active' },
        tailscale: { enabled: true, status: 'active' },
        interfaces: [],
        timestamp: new Date().toISOString(),
      };

      // Mock the NetworkMonitor constructor and getStatus method
      jest.spyOn(NetworkMonitor.prototype, 'getStatus').mockResolvedValue(mockStatus);

      const response = await request(app).get('/api/network');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('should return network data structure', async () => {
      const NetworkMonitor = require('../../../src/dashboard/api/network');

      const mockStatus = {
        wireguard: { enabled: true, status: 'active' },
        tailscale: { enabled: true, status: 'active' },
        interfaces: [{ name: 'eth0', state: 'UP' }],
        timestamp: new Date().toISOString(),
      };

      jest.spyOn(NetworkMonitor.prototype, 'getStatus').mockResolvedValue(mockStatus);

      const response = await request(app).get('/api/network');

      expect(response.body.data).toHaveProperty('wireguard');
      expect(response.body.data).toHaveProperty('tailscale');
      expect(response.body.data).toHaveProperty('interfaces');
      expect(response.body.data).toHaveProperty('timestamp');
    });
  });

  describe('TC-SRV-006: Storage API Endpoint', () => {
    test('GET /api/storage should return 200', async () => {
      const response = await request(app).get('/api/storage');

      expect(response.status).toBe(200);
      expect(response.body.success).toBe(true);
    });

    test('should return storage array', async () => {
      const response = await request(app).get('/api/storage');

      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);
    });

    test('should return storage with required properties', async () => {
      const response = await request(app).get('/api/storage');
      const storage = response.body.data[0];

      expect(storage).toHaveProperty('storage');
      expect(storage).toHaveProperty('type');
      expect(storage).toHaveProperty('node');
      expect(storage).toHaveProperty('used');
      expect(storage).toHaveProperty('avail');
      expect(storage).toHaveProperty('total');
      expect(storage).toHaveProperty('usedPercent');
    });

    test('should return valid storage types', async () => {
      const response = await request(app).get('/api/storage');
      const validTypes = ['dir', 'lvm', 'nfs', 'cifs', 'zfs', 'btrfs'];

      response.body.data.forEach(storage => {
        expect(validTypes).toContain(storage.type);
      });
    });

    test('should have correct usage percentage calculation', async () => {
      const response = await request(app).get('/api/storage');
      const storage = response.body.data[0];

      const expectedPercent = (storage.used / storage.total) * 100;
      expect(storage.usedPercent).toBeCloseTo(expectedPercent, 1);
    });
  });

  describe('TC-SRV-007: Error Handling', () => {
    test('should return 404 for unknown routes', async () => {
      const response = await request(app).get('/api/unknown');

      expect(response.status).toBe(404);
      expect(response.body.success).toBe(false);
      expect(response.body).toHaveProperty('error', 'Not found');
      expect(response.body).toHaveProperty('path', '/api/unknown');
    });

    test('should handle POST on GET endpoints', async () => {
      const response = await request(app).post('/api/overview');

      expect(response.status).toBe(404);
    });

    test('should handle unsupported methods', async () => {
      const response = await request(app).delete('/health');

      expect(response.status).toBe(404);
    });
  });

  describe('TC-SRV-008: Security Headers', () => {
    test('should include Helmet security headers', async () => {
      const response = await request(app).get('/health');

      expect(response.headers).toBeDefined();
    });

    test('should include X-Content-Type-Options header', async () => {
      const response = await request(app).get('/health');

      expect(response.headers['x-content-type-options']).toBeDefined();
    });

    test('should include X-Frame-Options header', async () => {
      const response = await request(app).get('/health');

      expect(response.headers['x-frame-options']).toBeDefined();
    });
  });

  describe('TC-SRV-009: CORS', () => {
    test('should include CORS headers', async () => {
      const response = await request(app).get('/health');

      expect(response.headers['access-control-allow-origin']).toBeDefined();
    });
  });

  describe('TC-SRV-010: Response Formats', () => {
    test('should return JSON for all endpoints', async () => {
      const endpoints = ['/health', '/api/overview', '/api/containers', '/api/storage'];

      for (const endpoint of endpoints) {
        const response = await request(app).get(endpoint);
        expect(response.headers['content-type']).toMatch(/json/);
      }
    });

    test('should have consistent success response structure', async () => {
      const response = await request(app).get('/api/overview');

      expect(Object.keys(response.body)).toContain('success');
      if (response.body.success) {
        expect(Object.keys(response.body)).toContain('data');
      }
    });

    test('should have consistent error response structure', async () => {
      const response = await request(app).get('/api/unknown');

      expect(Object.keys(response.body)).toContain('success');
      expect(response.body.success).toBe(false);
      expect(Object.keys(response.body)).toContain('error');
    });
  });
});

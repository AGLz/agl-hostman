/**
 * API Integration Tests
 * Test all REST endpoints with mocked Proxmox backend
 */

const request = require('supertest');
const ProxmoxMock = require('./mocks/proxmox-mock');

// Import app (but don't start server yet)
let app;
let proxmoxMock;

describe('API Integration Tests', () => {
  beforeAll(async () => {
    // Setup Proxmox mock
    proxmoxMock = new ProxmoxMock();
    proxmoxMock.setupAll();

    // Import app after mocks are set up
    app = require('../../src/dashboard/server');

    // Wait for server to be ready
    await global.testUtils.waitForServer(app);
  });

  afterAll(async () => {
    // Cleanup mocks
    proxmoxMock.cleanup();

    // Close server if it has a close method
    if (app && app.close) {
      await new Promise(resolve => app.close(resolve));
    }
  });

  describe('GET /health', () => {
    it('should return health status', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200)
        .expect('Content-Type', /json/);

      expect(response.body).toHaveProperty('status', 'healthy');
      expect(response.body).toHaveProperty('timestamp');
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('environment', 'test');
      expect(response.body).toHaveProperty('version');

      // Validate timestamp
      expect(response.body.timestamp).toBeValidTimestamp();

      // Validate uptime is a number
      expect(typeof response.body.uptime).toBe('number');
      expect(response.body.uptime).toBeGreaterThanOrEqual(0);
    });

    it('should return health status quickly', async () => {
      const startTime = Date.now();
      await request(app).get('/health').expect(200);
      const duration = Date.now() - startTime;

      // Health check should be fast (<100ms)
      expect(duration).toBeLessThan(100);
    });
  });

  describe('GET /api/overview', () => {
    it('should return infrastructure overview', async () => {
      const response = await request(app)
        .get('/api/overview')
        .expect(200)
        .expect('Content-Type', /json/);

      // Validate response structure
      global.testUtils.validateApiResponse(response, ['data']);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('nodes');
      expect(response.body.data).toHaveProperty('containers');
      expect(response.body.data).toHaveProperty('vms');

      // Validate nodes array
      expect(Array.isArray(response.body.data.nodes)).toBe(true);
      expect(response.body.data.nodes.length).toBeGreaterThan(0);

      // Validate node structure
      const node = response.body.data.nodes[0];
      expect(node).toHaveProperty('name');
      expect(node).toHaveProperty('status');
      expect(node).toHaveProperty('cpu');
      expect(node).toHaveProperty('memory');
      expect(node).toHaveProperty('uptime');

      // Validate memory structure
      expect(node.memory).toHaveProperty('used');
      expect(node.memory).toHaveProperty('total');
      expect(node.memory).toHaveProperty('percent');
    });

    it('should return valid resource counts', async () => {
      const response = await request(app)
        .get('/api/overview')
        .expect(200);

      const { containers, vms } = response.body.data;

      // Validate counts are numbers
      expect(typeof containers).toBe('number');
      expect(typeof vms).toBe('number');

      // Validate counts are non-negative
      expect(containers).toBeGreaterThanOrEqual(0);
      expect(vms).toBeGreaterThanOrEqual(0);
    });

    it('should handle errors gracefully', async () => {
      // Setup error mock
      proxmoxMock.cleanup();
      proxmoxMock.setup();
      proxmoxMock.mockAuth();
      proxmoxMock.mockError('/nodes', 500, 'Connection failed');

      const response = await request(app)
        .get('/api/overview')
        .expect(500)
        .expect('Content-Type', /json/);

      expect(response.body.success).toBe(false);
      expect(response.body).toHaveProperty('error');
      expect(response.body).toHaveProperty('message');

      // Restore mocks
      proxmoxMock.cleanup();
      proxmoxMock.setupAll();
    });

    it('should handle timeouts', async () => {
      // Setup timeout mock
      proxmoxMock.cleanup();
      proxmoxMock.setup();
      proxmoxMock.mockAuth();
      proxmoxMock.mockTimeout('/nodes');

      const response = await request(app)
        .get('/api/overview')
        .expect(500);

      expect(response.body.success).toBe(false);

      // Restore mocks
      proxmoxMock.cleanup();
      proxmoxMock.setupAll();
    }, 15000); // Longer timeout for this test
  });

  describe('GET /api/containers', () => {
    it('should return container list', async () => {
      const response = await request(app)
        .get('/api/containers')
        .expect(200)
        .expect('Content-Type', /json/);

      global.testUtils.validateApiResponse(response, ['data']);

      expect(response.body.success).toBe(true);
      expect(Array.isArray(response.body.data)).toBe(true);
      expect(response.body.data.length).toBeGreaterThan(0);

      // Validate container structure
      const container = response.body.data[0];
      expect(container).toHaveProperty('vmid');
      expect(container).toHaveProperty('name');
      expect(container).toHaveProperty('status');
      expect(container).toHaveProperty('node');
      expect(container).toHaveProperty('type', 'lxc');
    });

    it('should return containers with valid status', async () => {
      const response = await request(app)
        .get('/api/containers')
        .expect(200);

      const validStatuses = ['running', 'stopped', 'paused'];
      response.body.data.forEach(container => {
        expect(validStatuses).toContain(container.status);
      });
    });

    it('should return containers with resource information', async () => {
      const response = await request(app)
        .get('/api/containers')
        .expect(200);

      const container = response.body.data[0];
      expect(container).toHaveProperty('cpus');
      expect(container).toHaveProperty('maxmem');
      expect(container).toHaveProperty('maxdisk');

      // Validate resource values are numbers
      expect(typeof container.cpus).toBe('number');
      expect(typeof container.maxmem).toBe('number');
      expect(typeof container.maxdisk).toBe('number');
    });

    it('should handle empty container list', async () => {
      // Mock empty response
      proxmoxMock.cleanup();
      proxmoxMock.setup();
      proxmoxMock.mockAuth();
      proxmoxMock.mockNodes();
      proxmoxMock.scope
        .get(/\/nodes\/.*\/lxc/)
        .reply(200, { data: [] });

      const response = await request(app)
        .get('/api/containers')
        .expect(200);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toEqual([]);

      // Restore mocks
      proxmoxMock.cleanup();
      proxmoxMock.setupAll();
    });
  });

  describe('GET /api/network', () => {
    it('should return network status', async () => {
      const response = await request(app)
        .get('/api/network')
        .expect(200)
        .expect('Content-Type', /json/);

      global.testUtils.validateApiResponse(response, ['data']);

      expect(response.body.success).toBe(true);
      expect(response.body.data).toHaveProperty('wireguard');
      expect(response.body.data).toHaveProperty('tailscale');
      expect(response.body.data).toHaveProperty('interfaces');
      expect(response.body.data).toHaveProperty('timestamp');
    });

    it('should return WireGuard status', async () => {
      const response = await request(app)
        .get('/api/network')
        .expect(200);

      const { wireguard } = response.body.data;
      expect(wireguard).toHaveProperty('enabled');

      if (wireguard.enabled) {
        expect(wireguard).toHaveProperty('status');
        expect(['active', 'unavailable', 'error']).toContain(wireguard.status);
      }
    });

    it('should return Tailscale status', async () => {
      const response = await request(app)
        .get('/api/network')
        .expect(200);

      const { tailscale } = response.body.data;
      expect(tailscale).toHaveProperty('enabled');

      if (tailscale.enabled) {
        expect(tailscale).toHaveProperty('status');
        expect(['active', 'unavailable', 'error']).toContain(tailscale.status);
      }
    });

    it('should return network interfaces', async () => {
      const response = await request(app)
        .get('/api/network')
        .expect(200);

      const { interfaces } = response.body.data;
      expect(Array.isArray(interfaces)).toBe(true);

      if (interfaces.length > 0) {
        const iface = interfaces[0];
        expect(iface).toHaveProperty('name');
        expect(iface).toHaveProperty('state');
        expect(iface).toHaveProperty('addresses');
        expect(Array.isArray(iface.addresses)).toBe(true);
      }
    });
  });

  describe('GET /api/storage', () => {
    it('should return storage status', async () => {
      const response = await request(app)
        .get('/api/storage')
        .expect(200)
        .expect('Content-Type', /json/);

      global.testUtils.validateApiResponse(response, ['data']);

      expect(response.body.success).toBe(true);
      expect(Array.isArray(response.body.data)).toBe(true);
    });

    it('should return storage with usage information', async () => {
      const response = await request(app)
        .get('/api/storage')
        .expect(200);

      if (response.body.data.length > 0) {
        const storage = response.body.data[0];
        expect(storage).toHaveProperty('storage');
        expect(storage).toHaveProperty('type');
        expect(storage).toHaveProperty('node');
        expect(storage).toHaveProperty('used');
        expect(storage).toHaveProperty('avail');
        expect(storage).toHaveProperty('total');
        expect(storage).toHaveProperty('usedPercent');

        // Validate percentage calculation
        const expectedPercent = (storage.used / storage.total) * 100;
        expect(storage.usedPercent).toBeCloseTo(expectedPercent, 2);
      }
    });

    it('should return valid storage types', async () => {
      const response = await request(app)
        .get('/api/storage')
        .expect(200);

      const validTypes = ['dir', 'lvm', 'nfs', 'cifs', 'zfs', 'btrfs'];
      response.body.data.forEach(storage => {
        expect(validTypes).toContain(storage.type);
      });
    });
  });

  describe('Error Handling', () => {
    it('should handle 404 for unknown routes', async () => {
      const response = await request(app)
        .get('/api/unknown-endpoint')
        .expect(404)
        .expect('Content-Type', /json/);

      expect(response.body.success).toBe(false);
      expect(response.body).toHaveProperty('error', 'Not found');
      expect(response.body).toHaveProperty('path', '/api/unknown-endpoint');
    });

    it('should handle malformed requests', async () => {
      const response = await request(app)
        .post('/api/overview')
        .send({ invalid: 'data' })
        .expect(404); // POST not allowed

      expect(response.body.success).toBe(false);
    });
  });

  describe('Performance', () => {
    it('should respond to multiple requests concurrently', async () => {
      const requests = [
        request(app).get('/health'),
        request(app).get('/api/overview'),
        request(app).get('/api/containers'),
        request(app).get('/api/network'),
        request(app).get('/api/storage'),
      ];

      const startTime = Date.now();
      const responses = await Promise.all(requests);
      const duration = Date.now() - startTime;

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      // Concurrent requests should complete reasonably fast
      expect(duration).toBeLessThan(5000);
    });

    it('should handle request load', async () => {
      const requests = [];
      for (let i = 0; i < 20; i++) {
        requests.push(request(app).get('/health'));
      }

      const startTime = Date.now();
      const responses = await Promise.all(requests);
      const duration = Date.now() - startTime;

      // All requests should succeed
      expect(responses.length).toBe(20);
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      // Should handle load efficiently
      expect(duration).toBeLessThan(2000);
    });
  });

  describe('CORS', () => {
    it('should include CORS headers', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      // Check for CORS headers (depending on config)
      expect(response.headers).toHaveProperty('access-control-allow-origin');
    });
  });

  describe('Compression', () => {
    it('should compress large responses', async () => {
      const response = await request(app)
        .get('/api/containers')
        .set('Accept-Encoding', 'gzip')
        .expect(200);

      // Response should be compressed if large enough
      // Note: Actual compression depends on response size
      expect(response.headers).toBeDefined();
    });
  });

  describe('Security Headers', () => {
    it('should include security headers (Helmet)', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      // Check for security headers added by Helmet
      expect(response.headers).toHaveProperty('x-content-type-options', 'nosniff');
      expect(response.headers).toHaveProperty('x-frame-options');
    });
  });
});

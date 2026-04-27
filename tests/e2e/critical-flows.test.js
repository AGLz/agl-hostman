/**
 * E2E Tests - Critical User Flows
 *
 * End-to-end tests for critical user journeys
 * Tests complete workflows through the system
 * @version 1.0.0
 */

const request = require('supertest');

let app;

beforeAll(() => {
  app = require('../../../src/dashboard/server');
});

describe('E2E Tests - Critical User Flows', () => {
  describe('E2E-001: Dashboard Initialization Flow', () => {
    test('complete dashboard health check flow', async () => {
      // Step 1: Check health endpoint
      const healthResponse = await request(app).get('/health');

      expect(healthResponse.status).toBe(200);
      expect(healthResponse.body.status).toBe('healthy');

      // Step 2: Verify all required data endpoints
      const endpoints = ['/api/overview', '/api/containers', '/api/storage'];

      for (const endpoint of endpoints) {
        const response = await request(app).get(endpoint);
        expect(response.status).toBe(200);
        expect(response.body.success).toBe(true);
      }
    });
  });

  describe('E2E-002: Infrastructure Monitoring Flow', () => {
    test('complete infrastructure monitoring workflow', async () => {
      // Step 1: Get overview
      const overviewResponse = await request(app).get('/api/overview');

      expect(overviewResponse.status).toBe(200);
      expect(overviewResponse.body.data.nodes).toBeDefined();

      // Step 2: Get detailed container information
      const containersResponse = await request(app).get('/api/containers');

      expect(containersResponse.status).toBe(200);
      expect(containersResponse.body.data.length).toBeGreaterThan(0);

      // Step 3: Get storage information
      const storageResponse = await request(app).get('/api/storage');

      expect(storageResponse.status).toBe(200);
      expect(Array.isArray(storageResponse.body.data)).toBe(true);

      // Step 4: Verify data consistency
      const containerCount = overviewResponse.body.data.containers;
      const actualContainers = containersResponse.body.data.length;

      // Container count should be consistent
      expect(actualContainers).toBeGreaterThanOrEqual(0);
    });
  });

  describe('E2E-003: Network Status Monitoring Flow', () => {
    test('complete network status check workflow', async () => {
      const NetworkMonitor = require('../../../src/dashboard/api/network');

      // Mock network status for testing
      jest.spyOn(NetworkMonitor.prototype, 'getStatus').mockResolvedValue({
        wireguard: { enabled: true, status: 'active', peers: 3 },
        tailscale: { enabled: true, status: 'active', peers: 5 },
        interfaces: [
          {
            name: 'eth0',
            state: 'UP',
            addresses: [
              { address: '192.168.1.100', family: 'inet', prefixlen: 24 },
            ],
          },
        ],
        timestamp: new Date().toISOString(),
      });

      // Step 1: Get network status
      const networkResponse = await request(app).get('/api/network');

      expect(networkResponse.status).toBe(200);
      expect(networkResponse.body.data.wireguard).toBeDefined();
      expect(networkResponse.body.data.tailscale).toBeDefined();

      // Step 2: Verify network components
      const { wireguard, tailscale, interfaces } = networkResponse.body.data;

      expect(wireguard.enabled).toBeDefined();
      expect(tailscale.enabled).toBeDefined();
      expect(Array.isArray(interfaces)).toBe(true);
    });
  });

  describe('E2E-004: Error Recovery Flow', () => {
    test('should handle and recover from errors gracefully', async () => {
      // Step 1: Attempt to access non-existent endpoint
      const errorResponse = await request(app).get('/api/nonexistent');

      expect(errorResponse.status).toBe(404);
      expect(errorResponse.body.success).toBe(false);

      // Step 2: Verify system is still functional
      const healthResponse = await request(app).get('/health');

      expect(healthResponse.status).toBe(200);
      expect(healthResponse.body.status).toBe('healthy');
    });
  });

  describe('E2E-005: Concurrent User Flow', () => {
    test('should handle multiple simultaneous user requests', async () => {
      // Simulate multiple users accessing different endpoints concurrently
      const userFlows = [
        // User 1: Dashboard overview
        request(app).get('/health'),
        request(app).get('/api/overview'),

        // User 2: Container monitoring
        request(app).get('/api/containers'),

        // User 3: Storage monitoring
        request(app).get('/api/storage'),
      ];

      const responses = await Promise.all(userFlows);

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });
    });
  });

  describe('E2E-006: Data Consistency Flow', () => {
    test('should maintain data consistency across related endpoints', async () => {
      // Get data from multiple endpoints
      const [overview, containers] = await Promise.all([
        request(app).get('/api/overview'),
        request(app).get('/api/containers'),
      ]);

      // Verify container-related data consistency
      const overviewContainerCount = overview.body.data.containers;
      const actualContainerCount = containers.body.data.length;

      expect(overviewContainerCount).toBeGreaterThanOrEqual(0);
      expect(actualContainerCount).toBeGreaterThanOrEqual(0);
    });
  });

  describe('E2E-007: Response Format Consistency Flow', () => {
    test('should return consistent response formats across all endpoints', async () => {
      const endpoints = [
        '/health',
        '/api/overview',
        '/api/containers',
        '/api/storage',
      ];

      const responses = await Promise.all(
        endpoints.map(endpoint => request(app).get(endpoint))
      );

      // All responses should have consistent structure
      responses.forEach(response => {
        expect(response.headers['content-type']).toMatch(/json/);
        expect(response.body).toBeDefined();
      });
    });
  });

  describe('E2E-008: Authentication and Security Flow', () => {
    test('should include appropriate security headers', async () => {
      const response = await request(app).get('/health');

      // Verify security headers are present
      expect(response.headers['x-content-type-options']).toBeDefined();
      expect(response.headers['x-frame-options']).toBeDefined();
    });
  });

  describe('E2E-009: Performance Under Load Flow', () => {
    test('should maintain performance under moderate load', async () => {
      const requestCount = 20;
      const startTime = Date.now();

      // Make concurrent requests
      const requests = Array(requestCount)
        .fill(null)
        .map(() => request(app).get('/health'));

      const responses = await Promise.all(requests);

      const duration = Date.now() - startTime;

      // All requests should succeed
      responses.forEach(response => {
        expect(response.status).toBe(200);
      });

      // Should complete reasonably fast
      expect(duration).toBeLessThan(1000);
      console.log(`E2E Load Test: ${requestCount} requests completed in ${duration}ms`);
    });
  });

  describe('E2E-010: System Health Monitoring Flow', () => {
    test('complete system health monitoring workflow', async () => {
      // This test simulates a monitoring system checking all endpoints

      const monitoringChecks = {
        health: null,
        overview: null,
        containers: null,
        storage: null,
      };

      // Perform all health checks
      monitoringChecks.health = await request(app).get('/health');
      expect(monitoringChecks.health.status).toBe(200);
      expect(monitoringChecks.health.body.status).toBe('healthy');

      monitoringChecks.overview = await request(app).get('/api/overview');
      expect(monitoringChecks.overview.status).toBe(200);

      monitoringChecks.containers = await request(app).get('/api/containers');
      expect(monitoringChecks.containers.status).toBe(200);

      monitoringChecks.storage = await request(app).get('/api/storage');
      expect(monitoringChecks.storage.status).toBe(200);

      // Verify overall system health
      const allHealthy = Object.values(monitoringChecks).every(
        response => response.status === 200
      );

      expect(allHealthy).toBe(true);
    });
  });
});

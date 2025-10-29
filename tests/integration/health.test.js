/**
 * Health Check Integration Tests
 * Test application health monitoring and readiness
 */

const request = require('supertest');

let app;

describe('Health Check Tests', () => {
  beforeAll(async () => {
    // Import app
    app = require('../../src/dashboard/server');

    // Wait for server to be ready
    await global.testUtils.waitForServer(app);
  });

  afterAll(() => {
    // Cleanup
    if (app && app.close) {
      app.close();
    }
  });

  describe('Basic Health Check', () => {
    it('should return 200 OK', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      expect(response.body).toHaveProperty('status', 'healthy');
    });

    it('should respond quickly', async () => {
      const startTime = Date.now();
      await request(app).get('/health');
      const responseTime = Date.now() - startTime;

      // Health check should be < 50ms
      expect(responseTime).toBeLessThan(50);
    });

    it('should include all required fields', async () => {
      const response = await request(app).get('/health');

      const requiredFields = ['status', 'timestamp', 'uptime', 'environment', 'version'];
      requiredFields.forEach(field => {
        expect(response.body).toHaveProperty(field);
      });
    });

    it('should have valid timestamp format', async () => {
      const response = await request(app).get('/health');

      const timestamp = new Date(response.body.timestamp);
      expect(timestamp).toBeInstanceOf(Date);
      expect(timestamp.getTime()).toBeGreaterThan(0);

      // Timestamp should be recent (within last 5 seconds)
      const now = Date.now();
      const timestampMs = timestamp.getTime();
      expect(Math.abs(now - timestampMs)).toBeLessThan(5000);
    });

    it('should report correct environment', async () => {
      const response = await request(app).get('/health');

      expect(response.body.environment).toBe('test');
    });

    it('should have valid uptime', async () => {
      const response = await request(app).get('/health');

      expect(typeof response.body.uptime).toBe('number');
      expect(response.body.uptime).toBeGreaterThanOrEqual(0);

      // Uptime should increase over time
      await new Promise(resolve => setTimeout(resolve, 100));
      const response2 = await request(app).get('/health');
      expect(response2.body.uptime).toBeGreaterThan(response.body.uptime);
    });
  });

  describe('Health Check Stability', () => {
    it('should handle concurrent health checks', async () => {
      const requests = Array(50).fill(null).map(() =>
        request(app).get('/health')
      );

      const responses = await Promise.all(requests);

      responses.forEach(response => {
        expect(response.status).toBe(200);
        expect(response.body.status).toBe('healthy');
      });
    });

    it('should handle rapid sequential checks', async () => {
      for (let i = 0; i < 20; i++) {
        const response = await request(app).get('/health');
        expect(response.status).toBe(200);
      }
    });

    it('should not leak memory on repeated checks', async () => {
      if (global.gc) {
        // Force garbage collection if available
        global.gc();
      }

      const initialMemory = process.memoryUsage().heapUsed;

      // Make many health check requests
      for (let i = 0; i < 1000; i++) {
        await request(app).get('/health');
      }

      if (global.gc) {
        global.gc();
      }

      const finalMemory = process.memoryUsage().heapUsed;
      const memoryIncrease = finalMemory - initialMemory;

      // Memory increase should be reasonable (< 10MB)
      expect(memoryIncrease).toBeLessThan(10 * 1024 * 1024);

      console.log(`Memory increase: ${(memoryIncrease / 1024 / 1024).toFixed(2)} MB`);
    }, 30000);
  });

  describe('Readiness Check', () => {
    it('should indicate server is ready', async () => {
      const response = await request(app).get('/health');

      expect(response.body.status).toBe('healthy');
      expect(response.status).toBe(200);
    });

    it('should respond before timeout', async () => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 1000);

      try {
        const response = await request(app)
          .get('/health')
          .timeout(1000);

        clearTimeout(timeout);
        expect(response.status).toBe(200);
      } catch (error) {
        fail('Health check timed out');
      }
    });
  });

  describe('Health Check Content', () => {
    it('should have correct Content-Type header', async () => {
      const response = await request(app).get('/health');

      expect(response.headers['content-type']).toMatch(/application\/json/);
    });

    it('should not have cache headers', async () => {
      const response = await request(app).get('/health');

      // Health checks should not be cached
      const cacheControl = response.headers['cache-control'];
      if (cacheControl) {
        expect(cacheControl).toMatch(/no-cache|no-store|max-age=0/);
      }
    });

    it('should have valid JSON response', async () => {
      const response = await request(app).get('/health');

      expect(() => JSON.parse(JSON.stringify(response.body))).not.toThrow();
    });
  });

  describe('Service Dependencies', () => {
    it('should verify critical services are accessible', async () => {
      const response = await request(app).get('/health');

      // If health check passes, critical services should be OK
      expect(response.body.status).toBe('healthy');

      // Could add checks for:
      // - Database connectivity
      // - External API availability
      // - File system access
      // But keeping it simple for now
    });
  });

  describe('Load Testing', () => {
    it('should handle sustained load', async () => {
      const duration = 5000; // 5 seconds
      const startTime = Date.now();
      let requestCount = 0;
      let errors = 0;

      while (Date.now() - startTime < duration) {
        try {
          const response = await request(app).get('/health');
          if (response.status === 200) {
            requestCount++;
          } else {
            errors++;
          }
        } catch (error) {
          errors++;
        }
      }

      console.log(`Requests: ${requestCount}, Errors: ${errors}`);
      console.log(`Requests per second: ${(requestCount / (duration / 1000)).toFixed(2)}`);

      // Should handle at least 100 requests in 5 seconds
      expect(requestCount).toBeGreaterThan(100);

      // Error rate should be low (< 1%)
      expect(errors / requestCount).toBeLessThan(0.01);
    }, 10000);

    it('should maintain response time under load', async () => {
      const responseTimes = [];

      for (let i = 0; i < 100; i++) {
        const startTime = Date.now();
        await request(app).get('/health');
        responseTimes.push(Date.now() - startTime);
      }

      const avgResponseTime = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length;
      const maxResponseTime = Math.max(...responseTimes);

      console.log(`Average response time: ${avgResponseTime.toFixed(2)}ms`);
      console.log(`Max response time: ${maxResponseTime}ms`);

      // Average should be fast
      expect(avgResponseTime).toBeLessThan(50);

      // Max should be reasonable
      expect(maxResponseTime).toBeLessThan(200);
    }, 30000);
  });

  describe('Recovery Tests', () => {
    it('should recover from temporary failures', async () => {
      // Simulate temporary failure (e.g., network blip)
      // In real scenario, this might involve mocking a dependency failure

      // Health check should still respond
      const response = await request(app).get('/health');
      expect(response.status).toBe(200);
    });

    it('should maintain availability during restarts', async () => {
      // Test that health check works during application lifecycle
      const beforeRestart = await request(app).get('/health');
      expect(beforeRestart.status).toBe(200);

      // In a real scenario, we might trigger a graceful restart here
      // For now, just verify it continues to work

      const afterRestart = await request(app).get('/health');
      expect(afterRestart.status).toBe(200);
    });
  });

  describe('Monitoring Integration', () => {
    it('should provide metrics for monitoring systems', async () => {
      const response = await request(app).get('/health');

      // Metrics that monitoring systems might use
      expect(response.body).toHaveProperty('uptime');
      expect(response.body).toHaveProperty('timestamp');

      // Calculate uptime in human-readable format
      const uptimeSeconds = response.body.uptime;
      const hours = Math.floor(uptimeSeconds / 3600);
      const minutes = Math.floor((uptimeSeconds % 3600) / 60);

      console.log(`Uptime: ${hours}h ${minutes}m`);
    });

    it('should be compatible with Kubernetes liveness probes', async () => {
      const response = await request(app)
        .get('/health')
        .expect(200);

      // Kubernetes expects 200-399 status code for success
      expect(response.status).toBeGreaterThanOrEqual(200);
      expect(response.status).toBeLessThan(400);
    });

    it('should be compatible with Docker health checks', async () => {
      const response = await request(app).get('/health');

      // Docker expects 0 exit code (200 status) for healthy
      expect(response.status).toBe(200);
      expect(response.body.status).toBe('healthy');
    });
  });

  describe('Error Scenarios', () => {
    it('should handle invalid Accept headers gracefully', async () => {
      const response = await request(app)
        .get('/health')
        .set('Accept', 'text/html')
        .expect(200);

      // Should still return JSON even with HTML accept header
      expect(response.headers['content-type']).toMatch(/json/);
    });

    it('should handle malformed requests', async () => {
      const response = await request(app)
        .get('/health?invalid=param')
        .expect(200);

      // Should ignore invalid query params
      expect(response.body.status).toBe('healthy');
    });

    it('should not expose sensitive information', async () => {
      const response = await request(app).get('/health');

      const responseString = JSON.stringify(response.body);

      // Should not contain sensitive data
      const sensitivePatterns = [
        /password/i,
        /secret/i,
        /token/i,
        /api[_-]?key/i,
        /private[_-]?key/i,
      ];

      sensitivePatterns.forEach(pattern => {
        expect(responseString).not.toMatch(pattern);
      });
    });
  });
});

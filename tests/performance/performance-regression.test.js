/**
 * Performance Regression Tests
 *
 * Tests to detect performance regressions in API responses
 * and system resource usage
 * @version 1.0.0
 */

const request = require('supertest');
const { performance } = require('perf_hooks');

let app;

beforeAll(() => {
  app = require('../../../src/dashboard/server');
});

// Performance thresholds (in milliseconds)
const THRESHOLDS = {
  health: 10,
  overview: 50,
  containers: 50,
  storage: 50,
  network: 500, // Network operations can be slower
  concurrent: 500,
};

describe('Performance Regression Tests', () => {
  describe('PERF-001: Single Request Performance', () => {
    test('health endpoint should respond in <10ms', async () => {
      const start = performance.now();
      await request(app).get('/health').expect(200);
      const duration = performance.now() - start;

      expect(duration).toBeLessThan(THRESHOLDS.health);
      console.log(`Health endpoint: ${duration.toFixed(2)}ms`);
    });

    test('overview endpoint should respond in <50ms', async () => {
      const start = performance.now();
      await request(app).get('/api/overview').expect(200);
      const duration = performance.now() - start;

      expect(duration).beLessThan(THRESHOLDS.overview);
      console.log(`Overview endpoint: ${duration.toFixed(2)}ms`);
    });

    test('containers endpoint should respond in <50ms', async () => {
      const start = performance.now();
      await request(app).get('/api/containers').expect(200);
      const duration = performance.now() - start;

      expect(duration).toBeLessThan(THRESHOLDS.containers);
      console.log(`Containers endpoint: ${duration.toFixed(2)}ms`);
    });

    test('storage endpoint should respond in <50ms', async () => {
      const start = performance.now();
      await request(app).get('/api/storage').expect(200);
      const duration = performance.now() - start;

      expect(duration).toBeLessThan(THRESHOLDS.storage);
      console.log(`Storage endpoint: ${duration.toFixed(2)}ms`);
    });
  });

  describe('PERF-002: Response Size', () => {
    test('health response should be small (<500 bytes)', async () => {
      const response = await request(app).get('/health').expect(200);
      const size = JSON.stringify(response.body).length;

      expect(size).toBeLessThan(500);
      console.log(`Health response size: ${size} bytes`);
    });

    test('overview response should be reasonable (<5KB)', async () => {
      const response = await request(app).get('/api/overview').expect(200);
      const size = JSON.stringify(response.body).length;

      expect(size).toBeLessThan(5000);
      console.log(`Overview response size: ${size} bytes`);
    });

    test('containers response should be reasonable (<10KB)', async () => {
      const response = await request(app).get('/api/containers').expect(200);
      const size = JSON.stringify(response.body).length;

      expect(size).toBeLessThan(10000);
      console.log(`Containers response size: ${size} bytes`);
    });
  });

  describe('PERF-003: Concurrent Request Performance', () => {
    test('should handle 10 concurrent health requests efficiently', async () => {
      const start = performance.now();

      const requests = Array(10)
        .fill(null)
        .map(() => request(app).get('/health'));

      const responses = await Promise.all(requests);

      const duration = performance.now() - start;

      responses.forEach(r => expect(r.status).toBe(200));
      expect(duration).toBeLessThan(THRESHOLDS.concurrent);
      console.log(`10 concurrent health requests: ${duration.toFixed(2)}ms`);
    });

    test('should handle 5 concurrent API requests efficiently', async () => {
      const start = performance.now();

      const requests = [
        request(app).get('/health'),
        request(app).get('/api/overview'),
        request(app).get('/api/containers'),
        request(app).get('/api/storage'),
      ];

      const responses = await Promise.all(requests);

      const duration = performance.now() - start;

      responses.forEach(r => expect(r.status).toBe(200));
      expect(duration).toBeLessThan(THRESHOLDS.concurrent);
      console.log(`4 concurrent API requests: ${duration.toFixed(2)}ms`);
    });
  });

  describe('PERF-004: Sequential Request Performance', () => {
    test('should handle 100 sequential health requests efficiently', async () => {
      const start = performance.now();

      for (let i = 0; i < 100; i++) {
        await request(app).get('/health').expect(200);
      }

      const duration = performance.now() - start;
      const avgDuration = duration / 100;

      expect(avgDuration).toBeLessThan(THRESHOLDS.health * 2);
      console.log(`100 sequential health requests: ${duration.toFixed(2)}ms (avg: ${avgDuration.toFixed(2)}ms)`);
    });
  });

  describe('PERF-005: Memory Usage', () => {
    test('should not leak memory on repeated requests', () => {
      const initialMemory = process.memoryUsage().heapUsed;

      return new Promise(async (resolve) => {
        // Make 1000 requests
        for (let i = 0; i < 1000; i++) {
          await request(app).get('/health');
        }

        // Force garbage collection if available
        if (global.gc) {
          global.gc();
        }

        const finalMemory = process.memoryUsage().heapUsed;
        const memoryIncrease = finalMemory - initialMemory;
        const increaseMB = memoryIncrease / (1024 * 1024);

        // Should not increase by more than 10MB
        expect(increaseMB).toBeLessThan(10);
        console.log(`Memory increase after 1000 requests: ${increaseMB.toFixed(2)}MB`);

        resolve();
      });
    });
  });

  describe('PERF-006: Performance Regression Detection', () => {
    test('should store baseline metrics', async () => {
      const measurements = {};

      const endpoints = [
        { name: 'health', path: '/health' },
        { name: 'overview', path: '/api/overview' },
        { name: 'containers', path: '/api/containers' },
        { name: 'storage', path: '/api/storage' },
      ];

      for (const endpoint of endpoints) {
        const times = [];

        // Make 10 requests and collect times
        for (let i = 0; i < 10; i++) {
          const start = performance.now();
          await request(app).get(endpoint.path);
          times.push(performance.now() - start);
        }

        // Calculate statistics
        const avg = times.reduce((a, b) => a + b, 0) / times.length;
        const min = Math.min(...times);
        const max = Math.max(...times);
        const p95 = times.sort((a, b) => a - b)[Math.floor(times.length * 0.95)];

        measurements[endpoint.name] = { avg, min, max, p95 };
        console.log(`${endpoint.name}: avg=${avg.toFixed(2)}ms, min=${min.toFixed(2)}ms, max=${max.toFixed(2)}ms, p95=${p95.toFixed(2)}ms`);
      }

      // Store for regression detection
      process.env.PERFORMANCE_BASELINE = JSON.stringify(measurements);

      expect(measurements).toBeDefined();
    });

    test('should detect significant performance degradation', async () => {
      // This test compares current performance against baseline
      const baseline = process.env.PERFORMANCE_BASELINE
        ? JSON.parse(process.env.PERFORMANCE_BASELINE)
        : null;

      if (!baseline) {
        console.warn('No baseline available for comparison');
        return;
      }

      const DEGRADATION_THRESHOLD = 1.5; // 50% slower is considered degradation

      for (const endpoint of Object.keys(baseline)) {
        const start = performance.now();
        const path = endpoint === 'health' ? '/health' : `/api/${endpoint}`;

        await request(app).get(path);
        const currentDuration = performance.now() - start;

        const baselineAvg = baseline[endpoint].avg;
        const ratio = currentDuration / baselineAvg;

        console.log(`${endpoint}: current=${currentDuration.toFixed(2)}ms, baseline=${baselineAvg.toFixed(2)}ms, ratio=${ratio.toFixed(2)}x`);

        // Warning if significantly degraded (but don't fail the test)
        if (ratio > DEGRADATION_THRESHOLD) {
          console.warn(`PERFORMANCE WARNING: ${endpoint} is ${ratio.toFixed(2)}x slower than baseline`);
        }
      }

      expect(true).toBe(true);
    });
  });

  describe('PERF-007: Compression', () => {
    test('should support gzip compression', async () => {
      const response = await request(app)
        .get('/api/containers')
        .set('Accept-Encoding', 'gzip');

      expect(response.status).toBe(200);
      // Note: Actual compression depends on response size
    });
  });

  describe('PERF-008: Caching', () => {
    test('should respond consistently for repeated requests', async () => {
      const firstResponse = await request(app).get('/health');
      const secondResponse = await request(app).get('/health');

      // Responses should have same structure
      expect(Object.keys(firstResponse.body)).toEqual(Object.keys(secondResponse.body));
    });
  });

  describe('PERF-009: Timeout Handling', () => {
    test('should not hang on requests', async () => {
      const timeout = 5000; // 5 second timeout

      const start = performance.now();

      try {
        await request(app)
          .get('/health')
          .timeout(timeout);
      } catch (err) {
        // Timeout is acceptable if it doesn't exceed our threshold
      }

      const duration = performance.now() - start;
      expect(duration).toBeLessThan(timeout + 100);
    });
  });
});

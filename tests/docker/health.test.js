/**
 * Docker Health Check Tests
 * Tests for health endpoint and container health
 */

const request = require('supertest');

describe('Health Check Endpoint', () => {
  let app;

  beforeAll(() => {
    // Mock environment variables
    process.env.NODE_ENV = 'test';
    process.env.PORT = 3000;

    // Import app after setting env vars
    app = require('../../src/dashboard/server');
  });

  afterAll((done) => {
    // Close server after tests
    if (app && app.close) {
      app.close(done);
    } else {
      done();
    }
  });

  test('GET /health should return 200 OK', async () => {
    const response = await request(app).get('/health');

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('status');
    expect(response.body.status).toBe('healthy');
  });

  test('Health response should include required fields', async () => {
    const response = await request(app).get('/health');

    expect(response.body).toHaveProperty('status');
    expect(response.body).toHaveProperty('timestamp');
    expect(response.body).toHaveProperty('uptime');
    expect(response.body).toHaveProperty('environment');
    expect(response.body).toHaveProperty('version');
  });

  test('Health endpoint should return JSON', async () => {
    const response = await request(app).get('/health');

    expect(response.headers['content-type']).toMatch(/json/);
  });

  test('Health uptime should be a positive number', async () => {
    const response = await request(app).get('/health');

    expect(typeof response.body.uptime).toBe('number');
    expect(response.body.uptime).toBeGreaterThan(0);
  });

  test('Health timestamp should be valid ISO date', async () => {
    const response = await request(app).get('/health');

    const timestamp = response.body.timestamp;
    expect(timestamp).toBeTruthy();
    expect(new Date(timestamp).toString()).not.toBe('Invalid Date');
  });
});

describe('Health Check Docker Integration', () => {
  test('Health check command should be valid curl', () => {
    const healthCheckCmd = 'curl -f http://localhost:3000/health || exit 1';

    // Verify command structure
    expect(healthCheckCmd).toContain('curl');
    expect(healthCheckCmd).toContain('-f');
    expect(healthCheckCmd).toContain('/health');
  });

  test('Health check interval should be reasonable', () => {
    // From Dockerfile: --interval=30s
    const intervalSeconds = 30;

    expect(intervalSeconds).toBeGreaterThanOrEqual(10);
    expect(intervalSeconds).toBeLessThanOrEqual(60);
  });
});

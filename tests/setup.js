/**
 * Jest Test Setup
 * Custom matchers and global configuration
 */

// Custom matcher for ISO 8601 timestamp validation
expect.extend({
  toBeValidTimestamp(received) {
    const iso8601Regex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d{3})?Z$/;
    const pass = typeof received === 'string' && iso8601Regex.test(received);

    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid ISO 8601 timestamp`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid ISO 8601 timestamp`,
        pass: false,
      };
    }
  },
});

// Global test utilities
global.testUtils = {
  validateApiResponse(response, requiredFields = []) {
    expect(response.body).toHaveProperty('success');
    if (response.body.success) {
      expect(response.body).toHaveProperty('data');
    }
    requiredFields.forEach(field => {
      expect(response.body.data).toHaveProperty(field);
    });
  },

  async waitForServer(app, _maxWait = 5000) {
    // Simulate server ready - in real scenario, poll health endpoint
    return Promise.resolve();
  },
};

// Suppress console output during tests (optional)
if (process.env.SUPPRESS_LOGS === 'true') {
  global.console = {
    ...console,
    log: jest.fn(),
    debug: jest.fn(),
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  };
}

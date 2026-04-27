/**
 * Test Setup Helpers
 * Common setup utilities for integration tests
 */

const request = require('supertest');

// Extended matchers
expect.extend({
  toBeWithinRange(received, floor, ceiling) {
    const pass = received >= floor && received <= ceiling;
    if (pass) {
      return {
        message: () =>
          `expected ${received} not to be within range ${floor} - ${ceiling}`,
        pass: true,
      };
    } else {
      return {
        message: () =>
          `expected ${received} to be within range ${floor} - ${ceiling}`,
        pass: false,
      };
    }
  },

  toBeValidTimestamp(received) {
    const date = new Date(received);
    const pass = date instanceof Date && !isNaN(date);
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid timestamp`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid timestamp`,
        pass: false,
      };
    }
  },

  toBeValidIPAddress(received) {
    const ipv4Regex = /^(\d{1,3}\.){3}\d{1,3}$/;
    const ipv6Regex = /^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/;
    const pass = ipv4Regex.test(received) || ipv6Regex.test(received);
    if (pass) {
      return {
        message: () => `expected ${received} not to be a valid IP address`,
        pass: true,
      };
    } else {
      return {
        message: () => `expected ${received} to be a valid IP address`,
        pass: false,
      };
    }
  },
});

// Global test utilities
global.testUtils = {
  /**
   * Wait for a condition to be true
   */
  async waitFor(condition, timeout = 5000, interval = 100) {
    const startTime = Date.now();
    while (Date.now() - startTime < timeout) {
      if (await condition()) {
        return true;
      }
      await new Promise(resolve => setTimeout(resolve, interval));
    }
    throw new Error(`Timeout waiting for condition after ${timeout}ms`);
  },

  /**
   * Wait for server to be ready
   */
  async waitForServer(app, maxAttempts = 30) {
    for (let i = 0; i < maxAttempts; i++) {
      try {
        const response = await request(app).get('/health');
        if (response.status === 200) {
          return true;
        }
      } catch (error) {
        // Server not ready yet
      }
      await new Promise(resolve => setTimeout(resolve, 100));
    }
    throw new Error('Server failed to start in time');
  },

  /**
   * Create a mock response
   */
  mockResponse(data, status = 200) {
    return {
      status,
      data,
      headers: {
        'content-type': 'application/json',
      },
    };
  },

  /**
   * Generate random test data
   */
  randomString(length = 10) {
    return Math.random().toString(36).substring(2, 2 + length);
  },

  randomNumber(min = 0, max = 100) {
    return Math.floor(Math.random() * (max - min + 1)) + min;
  },

  /**
   * Validate response structure
   */
  validateApiResponse(response, expectedFields = []) {
    expect(response.body).toBeDefined();
    expect(response.body).toHaveProperty('success');
    expect(response.body).toHaveProperty('timestamp');

    if (expectedFields.length > 0) {
      expectedFields.forEach(field => {
        expect(response.body).toHaveProperty(field);
      });
    }
  },
};

// Cleanup after each test
afterEach(async () => {
  jest.clearAllMocks();
  jest.restoreAllMocks();
});

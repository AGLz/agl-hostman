/**
 * Jest Configuration for Integration Tests
 */

module.exports = {
  displayName: 'integration',
  testEnvironment: 'node',
  testMatch: ['**/tests/integration/**/*.test.js'],
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/**/*.test.js',
    '!src/**/__tests__/**',
  ],
  coverageDirectory: 'coverage/integration',
  coverageReporters: ['text', 'lcov', 'html', 'json'],
  coverageThresholds: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
  globalSetup: './setup.js',
  globalTeardown: './teardown.js',
  setupFilesAfterEnv: ['./helpers/test-setup.js'],
  testTimeout: 30000,
  verbose: true,
  forceExit: true,
  detectOpenHandles: true,
};

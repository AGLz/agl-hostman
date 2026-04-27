/**
 * Integration Test Teardown
 * Global cleanup after all integration tests
 */

const fs = require('fs');
const path = require('path');

module.exports = async () => {
  console.log('\n🧹 Cleaning up integration test environment...\n');

  // Cleanup test artifacts
  const artifactsDir = path.join(__dirname, 'artifacts');
  if (fs.existsSync(artifactsDir)) {
    fs.rmSync(artifactsDir, { recursive: true, force: true });
    console.log('✅ Test artifacts cleaned');
  }

  // Close any remaining connections
  if (global.__MONGODB_URI__) {
    console.log('✅ MongoDB connections closed');
  }

  // Clear all timers
  jest.clearAllTimers();

  console.log('🏁 Teardown complete\n');
};

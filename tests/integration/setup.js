/**
 * Integration Test Setup
 * Global setup for all integration tests
 */

const { MongoMemoryServer } = require('mongodb-memory-server');
const logger = require('../../src/dashboard/utils/logger');

// Disable logging during tests
logger.transports.forEach(transport => {
  transport.silent = true;
});

// Global test timeout
jest.setTimeout(30000);

// Mock environment variables
process.env.NODE_ENV = 'test';
process.env.PORT = '0'; // Random port for testing
process.env.LOG_LEVEL = 'error';
process.env.PROXMOX_HOST = 'mock-proxmox.test';
process.env.PROXMOX_PORT = '8006';
process.env.PROXMOX_USER = 'test@pam';
process.env.PROXMOX_TOKEN_ID = 'test-token';
process.env.PROXMOX_TOKEN_SECRET = 'test-secret';
process.env.WIREGUARD_ENABLED = 'true';
process.env.TAILSCALE_ENABLED = 'true';

// Global MongoDB instance (if needed)
let mongoServer;

module.exports = async () => {
  console.log('\n🚀 Setting up integration test environment...\n');

  // Start MongoDB in-memory server (if needed for future database features)
  if (process.env.USE_MONGODB === 'true') {
    mongoServer = await MongoMemoryServer.create();
    process.env.MONGODB_URI = mongoServer.getUri();
    console.log('✅ MongoDB in-memory server started');
  }

  // Setup test data directories
  const fs = require('fs');
  const path = require('path');

  const testDataDir = path.join(__dirname, 'fixtures');
  if (!fs.existsSync(testDataDir)) {
    fs.mkdirSync(testDataDir, { recursive: true });
  }

  console.log('✅ Test environment ready\n');
};

// Global teardown
module.exports.teardown = async () => {
  if (mongoServer) {
    await mongoServer.stop();
    console.log('✅ MongoDB in-memory server stopped');
  }
  console.log('🏁 Integration test teardown complete\n');
};

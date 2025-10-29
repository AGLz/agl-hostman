# Integration Tests - agl-hostman Dashboard

Comprehensive integration test suite for the agl-hostman infrastructure monitoring dashboard.

## 📋 Overview

This test suite validates:
- **API Integration**: REST endpoints with mocked Proxmox backend
- **Docker Health**: Container lifecycle and health monitoring
- **Network Connectivity**: WireGuard, Tailscale, and LAN connectivity
- **System Health**: Application health checks and readiness probes

## 🎯 Coverage Targets

| Metric | Target | Current |
|--------|--------|---------|
| Statements | 80% | TBD |
| Branches | 80% | TBD |
| Functions | 80% | TBD |
| Lines | 80% | TBD |

## 🚀 Quick Start

### Prerequisites

```bash
# Install dependencies
npm install

# Ensure Docker is running (for Docker tests)
docker ps

# Set up test environment
export NODE_ENV=test
```

### Running Tests

```bash
# Run all integration tests
npm run test:integration

# Run specific test file
npm run test:integration -- api.test.js

# Run with coverage
npm run test:integration -- --coverage

# Run in watch mode
npm run test:integration -- --watch

# Run with verbose output
npm run test:integration -- --verbose
```

## 📁 Test Structure

```
tests/integration/
├── README.md                    # This file
├── jest.config.js               # Jest configuration
├── setup.js                     # Global setup
├── teardown.js                  # Global teardown
├── api.test.js                  # API endpoint tests
├── docker.test.js               # Docker container tests
├── network.test.js              # Network connectivity tests
├── health.test.js               # Health check tests
├── helpers/
│   └── test-setup.js            # Test utilities and matchers
├── mocks/
│   ├── proxmox-mock.js          # Proxmox API mock server
│   └── network-mock.js          # Network command mocks
└── fixtures/
    └── (test data)
```

## 🧪 Test Suites

### 1. API Integration Tests (`api.test.js`)

Tests all REST endpoints with mocked Proxmox backend.

**Endpoints Tested:**
- `GET /health` - Health check endpoint
- `GET /api/overview` - Infrastructure overview
- `GET /api/containers` - Container list
- `GET /api/network` - Network status
- `GET /api/storage` - Storage status

**Test Scenarios:**
- ✅ Successful responses with valid data
- ⚠️ Error handling (500, 404, timeouts)
- 🚀 Performance under load
- 🔒 Security headers (CORS, Helmet)
- 📦 Response compression

**Example:**
```javascript
describe('GET /api/overview', () => {
  it('should return infrastructure overview', async () => {
    const response = await request(app)
      .get('/api/overview')
      .expect(200);

    expect(response.body).toHaveProperty('data');
    expect(response.body.data).toHaveProperty('nodes');
  });
});
```

### 2. Docker Container Tests (`docker.test.js`)

Validates Docker container lifecycle and health monitoring.

**Test Scenarios:**
- 🐳 Docker daemon connectivity
- 📦 Container creation and startup
- ⏱️ Startup time measurement
- 🏥 Health status checks
- 📊 Resource usage monitoring
- 🔄 Container restarts
- 📝 Log retrieval
- 🌐 Network configuration
- 🛑 Graceful shutdown
- 🗑️ Container cleanup
- 💾 Memory limits
- ⚡ CPU limits

**Example:**
```javascript
it('should measure container startup time', async () => {
  const startTime = Date.now();
  const container = await docker.createContainer({ ... });
  await container.start();
  const startupTime = Date.now() - startTime;

  expect(startupTime).toBeLessThan(5000);
});
```

### 3. Network Connectivity Tests (`network.test.js`)

Tests WireGuard, Tailscale, and network connectivity.

**Test Scenarios:**
- 🔐 WireGuard status and peer parsing
- 🌐 Tailscale status and peer detection
- 🔌 Network interfaces detection
- 📡 DNS resolution
- 🏓 Ping connectivity tests
- ⚡ Latency measurement
- 🔄 Concurrent network checks

**Example:**
```javascript
it('should get WireGuard status', async () => {
  const status = await networkMonitor.getWireGuardStatus();

  expect(status).toHaveProperty('enabled', true);
  expect(status).toHaveProperty('status');
  expect(['active', 'unavailable']).toContain(status.status);
});
```

### 4. Health Check Tests (`health.test.js`)

Validates application health monitoring and readiness.

**Test Scenarios:**
- 💚 Basic health check response
- ⚡ Response time validation
- 🔄 Concurrent health checks
- 💾 Memory leak detection
- 🎯 Readiness probes
- 📊 Load testing
- 🔄 Recovery from failures
- 📈 Monitoring integration (K8s, Docker)

**Example:**
```javascript
it('should respond quickly', async () => {
  const startTime = Date.now();
  await request(app).get('/health');
  const responseTime = Date.now() - startTime;

  expect(responseTime).toBeLessThan(50);
});
```

## 🛠️ Mock Servers

### Proxmox Mock (`mocks/proxmox-mock.js`)

Mocks Proxmox VE API for testing without real infrastructure.

**Features:**
- 🔐 Authentication (API token & password)
- 🖥️ Node status
- 📦 Container lists
- 💾 Storage information
- ⚠️ Error simulation
- ⏱️ Timeout simulation

**Usage:**
```javascript
const ProxmoxMock = require('./mocks/proxmox-mock');

const proxmoxMock = new ProxmoxMock();
proxmoxMock.setupAll(); // Setup all mocks

// Cleanup
proxmoxMock.cleanup();
```

### Network Mock (`mocks/network-mock.js`)

Mocks system network commands for testing.

**Features:**
- 🔐 WireGuard output
- 🌐 Tailscale status
- 🔌 Network interfaces
- 🏓 Ping responses
- 📡 DNS resolution

**Usage:**
```javascript
const NetworkMock = require('./mocks/network-mock');

const networkMock = new NetworkMock();
networkMock.setupAll();

// Mock specific command
networkMock.mockWireGuard(3); // 3 peers
```

## 🎨 Custom Matchers

Extended Jest matchers for common validations:

```javascript
// Validate timestamp format
expect(response.body.timestamp).toBeValidTimestamp();

// Validate IP address
expect(interface.address).toBeValidIPAddress();

// Validate numeric range
expect(value).toBeWithinRange(0, 100);
```

## 🔧 Test Utilities

Global utilities available in all tests:

```javascript
// Wait for condition
await global.testUtils.waitFor(async () => {
  const status = await getStatus();
  return status === 'ready';
}, 5000);

// Wait for server
await global.testUtils.waitForServer(app);

// Validate API response structure
global.testUtils.validateApiResponse(response, ['data', 'timestamp']);
```

## 🚀 CI/CD Integration

### GitHub Actions

```yaml
name: Integration Tests

on: [pull_request]

jobs:
  integration:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - run: npm ci
      - run: npm run test:integration
      - uses: codecov/codecov-action@v3
        with:
          files: ./coverage/integration/lcov.info
```

### Docker Compose

```yaml
version: '3.8'
services:
  integration-tests:
    build:
      context: .
      dockerfile: docker/test/Dockerfile
    environment:
      - NODE_ENV=test
      - DOCKER_HOST=unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: npm run test:integration
```

## 📊 Coverage Reports

### Generate Coverage

```bash
# Run with coverage
npm run test:integration -- --coverage

# View HTML report
open coverage/integration/lcov-report/index.html

# Generate JSON report
npm run test:integration -- --coverage --coverageReporters=json
```

### Coverage Thresholds

Defined in `jest.config.js`:

```javascript
coverageThresholds: {
  global: {
    branches: 80,
    functions: 80,
    lines: 80,
    statements: 80,
  },
}
```

## 🐛 Debugging Tests

### Debug Single Test

```bash
# Run with Node debugger
node --inspect-brk node_modules/.bin/jest --config tests/integration/jest.config.js --runInBand api.test.js

# In Chrome: chrome://inspect
```

### Debug in VSCode

Add to `.vscode/launch.json`:

```json
{
  "type": "node",
  "request": "launch",
  "name": "Jest Integration Tests",
  "program": "${workspaceFolder}/node_modules/.bin/jest",
  "args": [
    "--config",
    "tests/integration/jest.config.js",
    "--runInBand"
  ],
  "console": "integratedTerminal",
  "internalConsoleOptions": "neverOpen"
}
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Docker Tests Failing

**Problem:** Tests skip with "Docker not available"

**Solution:**
```bash
# Ensure Docker is running
docker ps

# Check Docker socket permissions
sudo usermod -aG docker $USER
```

#### 2. Network Tests Failing

**Problem:** Network commands not mocked

**Solution:**
```javascript
// Ensure mocks are setup before tests
beforeEach(() => {
  networkMock.setupAll();
});
```

#### 3. Port Already in Use

**Problem:** "EADDRINUSE: address already in use"

**Solution:**
```bash
# Find and kill process using port
lsof -ti:3000 | xargs kill -9

# Or use port 0 for random port
process.env.PORT = '0';
```

#### 4. Timeout Issues

**Problem:** Tests timing out

**Solution:**
```javascript
// Increase timeout for specific test
it('slow test', async () => {
  // test code
}, 30000); // 30 second timeout
```

## 📝 Writing New Tests

### Test Template

```javascript
/**
 * Feature Integration Tests
 * Test description
 */

const request = require('supertest');

describe('Feature Tests', () => {
  let app;

  beforeAll(async () => {
    // Setup
    app = require('../../src/dashboard/server');
    await global.testUtils.waitForServer(app);
  });

  afterAll(() => {
    // Cleanup
    if (app && app.close) {
      app.close();
    }
  });

  describe('Feature Scenario', () => {
    it('should test feature', async () => {
      const response = await request(app)
        .get('/api/feature')
        .expect(200);

      expect(response.body).toHaveProperty('data');
    });
  });
});
```

## 📚 Best Practices

### 1. Test Isolation

- ✅ Each test should be independent
- ✅ Use `beforeEach` to reset state
- ✅ Clean up resources in `afterEach`

### 2. Mock External Dependencies

- ✅ Mock Proxmox API
- ✅ Mock system commands
- ✅ Mock Docker (when needed)

### 3. Test Real Scenarios

- ✅ Test error conditions
- ✅ Test edge cases
- ✅ Test concurrent operations

### 4. Performance

- ✅ Keep tests fast (< 100ms per test)
- ✅ Use parallel execution
- ✅ Avoid unnecessary waits

### 5. Documentation

- ✅ Clear test descriptions
- ✅ Document complex scenarios
- ✅ Add comments for non-obvious code

## 🔗 Related Documentation

- [Unit Tests](../unit/README.md)
- [E2E Tests](../e2e/README.md)
- [Docker Tests](../docker/README.md)
- [Testing Strategy](../TESTING-DELIVERABLES-SUMMARY.md)

## 📧 Support

For questions or issues:
- Create an issue in the repository
- Contact the AGL Infrastructure Team
- See main [README.md](../../README.md)

---

**Last Updated:** 2025-10-28
**Maintainer:** AGL Infrastructure Team
**Coverage Target:** 80%+

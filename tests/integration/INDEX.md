# Integration Tests - Quick Navigation Index

**Phase**: 2.2 - Integration Testing
**Status**: ✅ Complete
**Last Updated**: 2025-10-28

---

## 📚 Documentation Quick Links

### Getting Started
- **[README.md](README.md)** - Start here! Complete integration testing guide
  - Quick start instructions
  - Test structure overview
  - All test suites explained
  - Mock server usage
  - Troubleshooting guide
  - Best practices

### CI/CD Integration
- **[CI-CD-INTEGRATION.md](CI-CD-INTEGRATION.md)** - Multi-platform CI/CD setup
  - GitHub Actions workflows
  - GitLab CI configuration
  - Jenkins pipelines
  - Docker-based CI
  - Dokploy integration
  - Coverage reporting
  - Notifications

### Mock Data Reference
- **[MOCK-DATA.md](MOCK-DATA.md)** - Complete mock data structures
  - Proxmox API responses
  - Network command outputs
  - Docker container data
  - Test fixtures
  - Data generators

### Project Status
- **[PHASE-2-DELIVERABLES.md](PHASE-2-DELIVERABLES.md)** - Complete deliverables summary
  - All deliverables checklist
  - Test coverage statistics
  - File structure
  - Installation guide
  - Acceptance criteria

---

## 🧪 Test Files

### Test Suites

| File | Tests | Purpose | Lines |
|------|-------|---------|-------|
| **[api.test.js](api.test.js)** | 50+ | API endpoint testing | ~400 |
| **[docker.test.js](docker.test.js)** | 50+ | Container health & lifecycle | ~500 |
| **[network.test.js](network.test.js)** | 60+ | Network connectivity | ~400 |
| **[health.test.js](health.test.js)** | 40+ | Health checks & monitoring | ~500 |

### Mock Servers

| File | Purpose | Lines |
|------|---------|-------|
| **[mocks/proxmox-mock.js](mocks/proxmox-mock.js)** | Proxmox API mock | ~250 |
| **[mocks/network-mock.js](mocks/network-mock.js)** | Network commands mock | ~220 |

### Configuration

| File | Purpose |
|------|---------|
| **[jest.config.js](jest.config.js)** | Jest test configuration |
| **[setup.js](setup.js)** | Global test setup |
| **[teardown.js](teardown.js)** | Global test cleanup |
| **[helpers/test-setup.js](helpers/test-setup.js)** | Custom matchers & utilities |

---

## 🚀 Quick Commands

### Run Tests
```bash
# All integration tests
npm run test:integration

# Specific test file
npm run test:integration -- api.test.js

# With coverage
npm run test:integration -- --coverage

# Watch mode
npm run test:integration -- --watch

# Verbose output
npm run test:integration -- --verbose
```

### Verify Setup
```bash
# Run verification script
./tests/integration/verify-setup.sh

# Check dependencies
npm list --depth=0
```

### View Coverage
```bash
# Generate and open report
npm run test:integration -- --coverage
open coverage/integration/lcov-report/index.html
```

---

## 📋 Test Suite Breakdown

### 1. API Integration Tests
**File**: `api.test.js`

**What it tests:**
- ✅ Health check endpoint (`/health`)
- ✅ Infrastructure overview (`/api/overview`)
- ✅ Container list (`/api/containers`)
- ✅ Network status (`/api/network`)
- ✅ Storage status (`/api/storage`)
- ✅ Error handling (500, 404, timeouts)
- ✅ Performance & load testing
- ✅ Security headers (CORS, Helmet)

**Key scenarios:**
- Mock Proxmox backend responses
- Response validation & schema checking
- Concurrent request handling
- Timeout & error recovery

### 2. Docker Container Tests
**File**: `docker.test.js`

**What it tests:**
- ✅ Docker daemon availability
- ✅ Container creation & startup
- ✅ Startup time measurement
- ✅ Health status monitoring
- ✅ Resource usage tracking
- ✅ Container restarts
- ✅ Log retrieval
- ✅ Network configuration
- ✅ Graceful shutdown
- ✅ Resource limits (memory, CPU)

**Key scenarios:**
- Real Docker integration (skips if unavailable)
- Lifecycle validation
- Performance benchmarks
- Resource constraint testing

### 3. Network Connectivity Tests
**File**: `network.test.js`

**What it tests:**
- ✅ WireGuard status & peers
- ✅ Tailscale status & peers
- ✅ Network interfaces
- ✅ DNS resolution
- ✅ Ping connectivity
- ✅ Latency measurement
- ✅ Concurrent network checks

**Key scenarios:**
- Command output mocking
- Peer connectivity validation
- Network topology verification
- Error handling

### 4. Health Check Tests
**File**: `health.test.js`

**What it tests:**
- ✅ Basic health check response
- ✅ Response time validation (< 50ms)
- ✅ Concurrent request handling
- ✅ Memory leak detection
- ✅ Load testing (1000+ requests)
- ✅ Recovery from failures
- ✅ K8s/Docker probe compatibility

**Key scenarios:**
- High-concurrency testing
- Stability validation
- Performance monitoring
- Resource leak detection

---

## 🎭 Mock Servers Usage

### Proxmox Mock
```javascript
const ProxmoxMock = require('./mocks/proxmox-mock');

// Setup all mocks
const mock = new ProxmoxMock();
mock.setupAll();

// Cleanup
mock.cleanup();
```

**Provides:**
- Authentication (API token & password)
- Node information & status
- Container & VM lists
- Storage information
- Error & timeout simulation

### Network Mock
```javascript
const NetworkMock = require('./mocks/network-mock');

// Setup all mocks
const mock = new NetworkMock();
mock.setupAll();

// Mock specific commands
mock.mockWireGuard(3); // 3 peers
mock.mockTailscale(5); // 5 peers
```

**Provides:**
- WireGuard command output
- Tailscale status JSON
- Network interface data
- Ping responses
- DNS resolution

---

## 🛠️ Development Workflow

### 1. First Time Setup
```bash
# Clone repository
git clone <repo-url>
cd agl-hostman

# Install dependencies
npm install

# Verify setup
./tests/integration/verify-setup.sh

# Run tests
npm run test:integration
```

### 2. Writing New Tests
```bash
# 1. Create test file
touch tests/integration/new-feature.test.js

# 2. Follow template in README.md

# 3. Run your test
npm run test:integration -- new-feature.test.js

# 4. Check coverage
npm run test:integration -- new-feature.test.js --coverage
```

### 3. Debugging Tests
```bash
# Run with debugger
node --inspect-brk node_modules/.bin/jest \
  --config tests/integration/jest.config.js \
  --runInBand \
  api.test.js

# Open chrome://inspect in browser
```

### 4. CI/CD Integration
```bash
# Copy GitHub Actions workflow
cp .github/workflows/integration-tests.yml \
   .github/workflows/

# Push to trigger CI
git push origin feature-branch
```

---

## 📊 Coverage & Reporting

### Generate Coverage
```bash
# HTML report
npm run test:integration -- --coverage

# JSON report
npm run test:integration -- --coverage --coverageReporters=json

# Text summary
npm run test:integration -- --coverage --coverageReporters=text
```

### Coverage Targets
```
Global Thresholds:
- Statements: 80%
- Branches: 80%
- Functions: 80%
- Lines: 80%
```

### View Reports
```bash
# Open HTML report
open coverage/integration/lcov-report/index.html

# View JSON summary
cat coverage/integration/coverage-summary.json | jq
```

---

## 🐛 Troubleshooting

### Quick Fixes

| Issue | Solution |
|-------|----------|
| Docker tests failing | Ensure Docker is running: `docker ps` |
| Port already in use | Kill process: `lsof -ti:3000 \| xargs kill -9` |
| Timeout errors | Increase timeout in test: `jest.setTimeout(30000)` |
| Mock not working | Check mock setup in `beforeEach()` |
| Coverage too low | Add more test scenarios |

### Common Commands
```bash
# Check Docker
docker ps

# Check Node version
node -v

# Reinstall dependencies
rm -rf node_modules && npm install

# Clear Jest cache
jest --clearCache
```

---

## 📞 Support & Resources

### Internal Documentation
- [Main README](README.md)
- [CI/CD Guide](CI-CD-INTEGRATION.md)
- [Mock Data Reference](MOCK-DATA.md)
- [Phase 2 Deliverables](PHASE-2-DELIVERABLES.md)

### External Resources
- [Jest Documentation](https://jestjs.io/docs/getting-started)
- [Supertest](https://github.com/visionmedia/supertest)
- [Dockerode](https://github.com/apocas/dockerode)
- [Nock](https://github.com/nock/nock)

### Project Links
- Main Documentation: `/docs`
- Testing Strategy: `tests/TESTING-DELIVERABLES-SUMMARY.md`
- API Documentation: `src/dashboard/api/`

---

## 🎯 Quick Reference

### Test Execution Times
| Suite | Avg Time | Max Time |
|-------|----------|----------|
| API | ~5s | ~10s |
| Docker | ~30s | ~60s |
| Network | ~3s | ~5s |
| Health | ~10s | ~20s |
| **Total** | **~50s** | **~90s** |

### File Locations
```
tests/integration/
├── *.test.js       # Test suites
├── *.md            # Documentation
├── mocks/          # Mock servers
├── helpers/        # Test utilities
├── fixtures/       # Test data
└── coverage/       # Coverage reports (generated)
```

### Key Scripts
```json
{
  "test:integration": "jest --config tests/integration/jest.config.js",
  "test:watch": "jest --watch",
  "test:ci": "npm run test:unit && npm run test:integration && npm run test:e2e"
}
```

---

## ✅ Checklist for New Contributors

Before running tests:
- [ ] Node.js 18+ installed
- [ ] Dependencies installed (`npm install`)
- [ ] Docker running (optional, for Docker tests)
- [ ] Environment verified (`./verify-setup.sh`)
- [ ] Documentation reviewed (this file + README.md)

Ready to contribute:
- [ ] Tests passing locally
- [ ] Coverage meets 80% threshold
- [ ] No lint errors
- [ ] Documentation updated if needed
- [ ] CI/CD pipeline configured

---

**Quick Start**: Read [README.md](README.md) first, then run `npm run test:integration`

**Need Help?**: Check [TROUBLESHOOTING](README.md#troubleshooting) section

**Contributing**: See [Phase 2 Deliverables](PHASE-2-DELIVERABLES.md)

---

*Last Updated: 2025-10-28 | Phase 2.2 Complete ✅*

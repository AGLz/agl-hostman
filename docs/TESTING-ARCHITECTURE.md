# Testing Architecture - Visual Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    AGL HOSTMAN TESTING SUITE                     │
│                        Pest PHP v3                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ├─── Configuration Layer
                              │    ├── Pest.php (Helpers, Expectations)
                              │    ├── phpunit.xml (Suites, Coverage)
                              │    └── composer.json (Dependencies)
                              │
                              ├─── Test Execution Layer
                              │    ├── Parallel Execution (10-20x faster)
                              │    ├── Database Transactions
                              │    └── HTTP Mocking
                              │
                              └─── Test Suites (5 Categories)
                                   │
                                   ├── [1] UNIT TESTS (80% target)
                                   │    ├── Services (15 services)
                                   │    │   ├── ProxmoxApiClient ✓
                                   │    │   ├── N8NService ✓
                                   │    │   ├── AIModelService
                                   │    │   ├── BackupService
                                   │    │   └── ... 11 more
                                   │    │
                                   │    ├── DTOs (2 DTOs)
                                   │    │   ├── ProxmoxApiResponse ✓
                                   │    │   └── ContainerMetrics ✓
                                   │    │
                                   │    ├── Models (15 models)
                                   │    │   ├── LxcContainer ✓
                                   │    │   ├── ProxmoxServer
                                   │    │   ├── User
                                   │    │   └── ... 12 more
                                   │    │
                                   │    ├── Jobs (5 jobs)
                                   │    │   ├── SyncWithN8N
                                   │    │   ├── MonitorContainerHealth
                                   │    │   └── ... 3 more
                                   │    │
                                   │    └── Repositories (2+ repos)
                                   │
                                   ├── [2] FEATURE TESTS (90% target)
                                   │    ├── API Endpoints
                                   │    │   ├── Infrastructure API ✓
                                   │    │   ├── Backup API
                                   │    │   ├── AI Model API
                                   │    │   └── ... more
                                   │    │
                                   │    ├── Controllers (18 controllers)
                                   │    │   ├── DashboardController
                                   │    │   ├── UserController
                                   │    │   └── ... 16 more
                                   │    │
                                   │    ├── Livewire (12 components)
                                   │    │   ├── MonitoringDashboard
                                   │    │   ├── ContainerHealthCard
                                   │    │   └── ... 10 more
                                   │    │
                                   │    └── Authentication
                                   │        ├── WorkOS SSO
                                   │        └── RBAC flows
                                   │
                                   ├── [3] INTEGRATION TESTS
                                   │    ├── Proxmox Integration ✓
                                   │    │   ├── Full container lifecycle
                                   │    │   ├── Cluster operations
                                   │    │   └── Error recovery
                                   │    │
                                   │    ├── N8N Integration
                                   │    │   ├── Webhook delivery
                                   │    │   └── Batch operations
                                   │    │
                                   │    ├── Queue Integration
                                   │    │   ├── Job processing
                                   │    │   └── Failed jobs
                                   │    │
                                   │    └── AI Integration
                                   │        └── Multi-AI orchestration
                                   │
                                   ├── [4] ARCHITECTURE TESTS (100%)
                                   │    ├── Models ✓
                                   │    │   ├── Extend Eloquent
                                   │    │   ├── Use HasFactory
                                   │    │   └── Define fillable/guarded
                                   │    │
                                   │    ├── Controllers ✓
                                   │    │   ├── Have suffix
                                   │    │   ├── Use DI
                                   │    │   └── Strict types
                                   │    │
                                   │    ├── Services ✓
                                   │    │   ├── Have suffix
                                   │    │   ├── Constructor injection
                                   │    │   └── No static methods
                                   │    │
                                   │    └── General ✓
                                   │        ├── No debug functions
                                   │        ├── DTOs readonly
                                   │        └── No circular deps
                                   │
                                   └── [5] PERFORMANCE TESTS
                                        ├── API Response Time ✓
                                        │   └── < 200ms threshold
                                        │
                                        ├── Database Queries ✓
                                        │   ├── N+1 detection
                                        │   ├── Index usage
                                        │   └── Chunking
                                        │
                                        ├── Cache Effectiveness ✓
                                        │   └── 2x speed improvement
                                        │
                                        └── Memory Usage ✓
                                            └── < 128MB limit
```

---

## Test Flow Architecture

```
┌──────────────┐
│   Developer  │
│  Writes Code │
└──────┬───────┘
       │
       ├─── Local Testing ────────────────────────────┐
       │                                               │
       │    1. composer test                          │
       │       └── Run all tests in parallel          │
       │                                               │
       │    2. composer test:unit                     │
       │       └── Quick feedback (< 10s)             │
       │                                               │
       │    3. composer test:coverage                 │
       │       └── Check coverage % (target: 70%+)    │
       │                                               │
       └──────────────────────────────────────────────┘
       │
       ├─── Git Push ────────────────────────────────┐
       │                                              │
       │    GitHub Actions Triggered                 │
       │                                              │
       │    ┌────────────────────────────────────┐   │
       │    │  Job 1: Tests                      │   │
       │    │  ├── PHP 8.2 (lowest deps)         │   │
       │    │  ├── PHP 8.2 (highest deps)        │   │
       │    │  ├── PHP 8.3 (lowest deps)         │   │
       │    │  └── PHP 8.3 (highest deps) ✓      │   │
       │    │      ├── Code Style (Pint)         │   │
       │    │      ├── Unit Tests                │   │
       │    │      ├── Feature Tests              │   │
       │    │      ├── Integration Tests          │   │
       │    │      ├── Architecture Tests         │   │
       │    │      ├── Performance Tests          │   │
       │    │      └── Generate Coverage          │   │
       │    └────────────────────────────────────┘   │
       │                                              │
       │    ┌────────────────────────────────────┐   │
       │    │  Job 2: Static Analysis            │   │
       │    │  ├── PHPStan                       │   │
       │    │  └── Psalm                         │   │
       │    └────────────────────────────────────┘   │
       │                                              │
       │    ┌────────────────────────────────────┐   │
       │    │  Job 3: Security Check             │   │
       │    │  └── composer audit                │   │
       │    └────────────────────────────────────┘   │
       │                                              │
       └──────────────────────────────────────────────┘
       │
       └─── Results ──────────────────────────────────┐
                                                       │
            ├── PR Comment (Coverage %)               │
            ├── Codecov Report                        │
            ├── Coverage Artifact (HTML)              │
            └── Pass/Fail Status                      │
                                                       │
       ┌────────────────────────────────────────────┐ │
       │  Coverage < 70% = PR Blocked               │ │
       │  Coverage ≥ 70% = PR Approved              │ │
       │  Architecture Tests Fail = PR Blocked      │ │
       │  Performance Tests Slow = Warning          │ │
       └────────────────────────────────────────────┘ │
                                                       │
       ┌───────────────────────────────────────────────┘
       │
       ├─── Merge to Main ───────────────────────────┐
       │                                              │
       │    Production Deployment                     │
       │    ├── All tests passing                    │
       │    ├── Coverage ≥ 70%                       │
       │    ├── Architecture compliant               │
       │    └── Performance within limits            │
       │                                              │
       └──────────────────────────────────────────────┘
```

---

## Coverage Calculation Flow

```
┌─────────────────────────────────────────────────────┐
│              COVERAGE CALCULATION                    │
└─────────────────────────────────────────────────────┘
                      │
     ┌────────────────┼────────────────┐
     │                │                │
     ▼                ▼                ▼
┌─────────┐    ┌──────────┐    ┌──────────┐
│  Lines  │    │ Functions│    │ Branches │
│ Covered │    │  Covered │    │  Covered │
└────┬────┘    └─────┬────┘    └─────┬────┘
     │               │               │
     └───────┬───────┴───────┬───────┘
             │               │
             ▼               ▼
        ┌─────────────────────────┐
        │   Xdebug Analysis       │
        │   Tracks execution      │
        └───────────┬─────────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │   Coverage Report       │
        │   - HTML (visual)       │
        │   - Clover (XML)        │
        │   - Text (console)      │
        └───────────┬─────────────┘
                    │
                    ▼
        ┌─────────────────────────┐
        │   Coverage Percentage   │
        │                         │
        │   Target: ≥ 70%         │
        │   Current: TBD          │
        │                         │
        │   Services: 80%         │
        │   Controllers: 85%      │
        │   Models: 90%           │
        │   DTOs: 95%             │
        └─────────────────────────┘
```

---

## Database Testing Strategy

```
┌──────────────────────────────────────────────────────┐
│           DATABASE TESTING STRATEGY                   │
└──────────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
     ┌────────┐  ┌─────────┐  ┌──────────┐
     │ SQLite │  │Database │  │ Factory  │
     │In-Mem  │  │ Trans.  │  │ Seeding  │
     └────┬───┘  └────┬────┘  └────┬─────┘
          │           │            │
          └──────┬────┴────┬───────┘
                 │         │
                 ▼         ▼
       ┌────────────────────────────┐
       │  Before Each Test:         │
       │  1. Start transaction      │
       │  2. Run migrations         │
       │  3. Seed with factories    │
       └───────────┬────────────────┘
                   │
                   ▼
       ┌────────────────────────────┐
       │  Run Test                  │
       │  - Create test data        │
       │  - Execute code            │
       │  - Assert results          │
       └───────────┬────────────────┘
                   │
                   ▼
       ┌────────────────────────────┐
       │  After Test:               │
       │  - Rollback transaction    │
       │  - Clean state restored    │
       └────────────────────────────┘
                   │
                   ▼
       ┌────────────────────────────┐
       │  Benefits:                 │
       │  - Fast (in-memory)        │
       │  - Isolated (rollback)     │
       │  - Parallel-safe           │
       │  - No cleanup needed       │
       └────────────────────────────┘
```

---

## Test Data Factory Pattern

```
┌─────────────────────────────────────────────────────┐
│              FACTORY PATTERN                         │
└─────────────────────────────────────────────────────┘
                       │
          ┌────────────┼────────────┐
          │            │            │
          ▼            ▼            ▼
   ┌───────────┐ ┌──────────┐ ┌──────────┐
   │  Default  │ │  States  │ │ Custom   │
   │   State   │ │          │ │ Methods  │
   └─────┬─────┘ └────┬─────┘ └────┬─────┘
         │            │            │
         ├────────────┼────────────┤
         │
         ▼
┌──────────────────────────────────────────┐
│  LxcContainerFactory                     │
│                                          │
│  Default:                                │
│  - Random VMID (100-999)                 │
│  - Random name, hostname                 │
│  - Status: random                        │
│  - Memory: 512-8192 MB                   │
│  - Cores: 1-8                            │
│                                          │
│  States:                                 │
│  - running()      → status: running      │
│  - stopped()      → status: stopped      │
│  - highResource() → 16GB RAM, 16 cores   │
│  - protected()    → is_protected: true   │
│  - template()     → is_template: true    │
│                                          │
│  Custom:                                 │
│  - withVmid(100)  → specific VMID        │
│                                          │
│  Usage:                                  │
│  LxcContainer::factory()                 │
│    ->running()                           │
│    ->highResource()                      │
│    ->create();                           │
└──────────────────────────────────────────┘
```

---

## Performance Optimization Strategy

```
┌──────────────────────────────────────────────────────┐
│        PERFORMANCE OPTIMIZATION LAYERS                │
└──────────────────────────────────────────────────────┘

Layer 1: PARALLEL EXECUTION
├── 10-20x faster than sequential
├── Multiple processes spawn
├── Isolated database per process
└── Results aggregated

Layer 2: DATABASE OPTIMIZATION
├── SQLite in-memory (no disk I/O)
├── Database transactions (auto rollback)
├── LazyRefreshDatabase (only when needed)
└── Factory caching

Layer 3: HTTP MOCKING
├── No external API calls
├── Instant responses
├── Predictable data
└── VCR-like recording for integration

Layer 4: SMART CACHING
├── Factory result caching
├── Configuration caching
├── Composer autoloader optimization
└── OpCache enabled

Layer 5: TEST ORGANIZATION
├── Fast tests first (Unit)
├── Slow tests tagged (Integration)
├── Performance tests on-demand
└── Parallel-safe design

RESULT: 100,000+ tests/minute achievable
```

---

## File Organization

```
src/
├── Pest.php                      # Main configuration
├── phpunit.xml                   # PHPUnit config
├── composer.json                 # Dependencies
│
├── tests/
│   ├── README.md                 # Complete guide
│   ├── TestCase.php             # Base test case
│   │
│   ├── Unit/                    # 80% coverage target
│   │   ├── Services/
│   │   │   ├── ProxmoxApiClientTest.php     ✓
│   │   │   ├── N8NServiceTest.php           ✓
│   │   │   └── ... 13 more
│   │   ├── DTOs/
│   │   │   ├── ProxmoxApiResponseTest.php   ✓
│   │   │   └── ContainerMetricsTest.php     ✓
│   │   ├── Models/
│   │   │   ├── LxcContainerTest.php         ✓
│   │   │   └── ... 14 more
│   │   ├── Jobs/
│   │   └── Repositories/
│   │
│   ├── Feature/                 # 90% coverage target
│   │   ├── Api/
│   │   │   └── InfrastructureControllerTest.php  ✓
│   │   ├── Controllers/
│   │   ├── Livewire/
│   │   └── Auth/
│   │
│   ├── Integration/
│   │   ├── Proxmox/
│   │   │   └── ProxmoxApiIntegrationTest.php     ✓
│   │   ├── N8N/
│   │   ├── Queue/
│   │   └── AI/
│   │
│   ├── Architecture/            # 100% enforcement
│   │   ├── ModelsTest.php                        ✓
│   │   ├── ControllersTest.php                   ✓
│   │   ├── ServicesTest.php                      ✓
│   │   └── GeneralTest.php                       ✓
│   │
│   ├── Performance/
│   │   └── ApiResponseTimeTest.php               ✓
│   │
│   └── Database/
│       ├── Factories/
│       │   ├── LxcContainerFactory.php           ✓
│       │   └── ProxmoxServerFactory.php          ✓
│       └── Seeders/
│           └── TestDatabaseSeeder.php            ✓
│
└── coverage/                    # Generated reports
    ├── html/
    │   └── index.html           # Visual report
    └── clover.xml               # CI/CD format
```

---

## Coverage Progression Roadmap

```
Week 1: UNIT TESTS (8.5% → 30%)
├── Services (15 files)
│   ├── ProxmoxApiClient          ✓
│   ├── N8NService                ✓
│   ├── AIModelService            ○
│   ├── BackupService             ○
│   └── ... 11 more               ○
├── DTOs (2 files)                ✓✓
└── Models (15 files)
    ├── LxcContainer              ✓
    └── ... 14 more               ○

Week 2: FEATURE TESTS (30% → 50%)
├── API Endpoints
│   ├── Infrastructure            ✓
│   ├── Backup                    ○
│   ├── AI Model                  ○
│   └── ... more                  ○
└── Controllers (18 files)
    └── All controllers           ○

Week 3: INTEGRATION + LIVEWIRE (50% → 65%)
├── Integration Tests
│   ├── Proxmox                   ✓
│   ├── N8N                       ○
│   ├── Queue                     ○
│   └── AI                        ○
└── Livewire (12 components)      ○

Week 4: OPTIMIZATION (65% → 75%+)
├── Jobs (5 files)                ○
├── Repositories                  ○
├── Edge cases                    ○
└── Optimization                  ○

FINAL: 75%+ coverage achieved! 🎉
```

---

**Legend:**
- ✓ = Implemented
- ○ = To be implemented
- ✓✓ = Fully implemented

**Status:** Ready for execution
**Estimated Time:** 4 weeks to 70%+ coverage
**Current State:** 19 test files, 85+ test cases created

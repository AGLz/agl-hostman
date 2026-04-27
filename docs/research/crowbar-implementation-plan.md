# Crowbar Implementation Plan - Transferring agl-hostman Improvements

> **Version**: 1.0.0
> **Date**: 2025-10-30
> **Agent**: Hive Mind Coder Agent
> **Purpose**: Step-by-step implementation strategy for transferring agl-hostman improvements to crowbar project

---

## 📋 Executive Summary

**Objective**: Transfer the comprehensive documentation structure, development workflows, and tooling improvements from agl-hostman to crowbar project.

**Timeline**: 3 weeks (Phase 1: Documentation, Phase 2: Integration, Phase 3: Validation)

**Risk Level**: Medium (Context adaptation required: infrastructure → mobile marketplace)

**Success Criteria**:
- Complete CLAUDE.md update with crowbar-specific context
- Establish docs/ directory with 6 core documents
- Configure Archon MCP integration for task management
- Implement Agent OS workflows for mobile development
- Set up branch strategy and Harbor/Dokploy integration

---

## 🎯 Implementation Priority Order

### Priority 1: CLAUDE.md Update (Week 1, Days 1-2)
- **Current State**: Basic project overview (480 lines)
- **Target State**: Comprehensive navigation guide (400 lines)
- **Key Changes**: Add document navigation, modular loading, performance metrics

### Priority 2: Documentation Structure (Week 1, Days 3-5)
- **Create**: `docs/` directory with 6 core files
- **Adapt**: Infrastructure concepts to mobile marketplace context
- **Focus**: Development workflows, coding standards, quick reference

### Priority 3: Archon MCP Integration (Week 2, Days 1-2)
- **Purpose**: Centralized task management and knowledge base
- **Connection**: Configure MCP endpoints for crowbar project
- **Benefits**: Cross-session memory, task tracking, code examples

### Priority 4: Agent Configurations (Week 2, Days 3-4)
- **Skills**: Install Agent OS skills for mobile development
- **Workflows**: Create SPARC methodology specs for React Native
- **Coordination**: Set up hive mind collaboration patterns

### Priority 5: Branch Strategy (Week 2, Day 5)
- **Current**: No documented strategy
- **Target**: Git workflow with develop/main branches
- **Integration**: Connect with CI/CD pipeline

### Priority 6: Harbor Integration (Week 3, Days 1-2)
- **Purpose**: Container registry for backend deployment
- **Configuration**: harbor.aglz.io:5000 integration
- **Benefit**: Automated Docker image management

### Priority 7: Dokploy Configuration (Week 3, Days 3-5)
- **Platform**: dok.aglz.io deployment automation
- **Method**: Docker Compose for backend
- **Monitoring**: Health checks, logging, rollback procedures

---

## 📂 File-by-File Implementation Strategy

### 1. CLAUDE.md (Root Level)

**Action**: Major update (replace content)

**Current**: 480 lines, basic project overview
**Target**: 400 lines, navigation-focused with modular loading

**Key Sections to Add**:
```markdown
## 🔖 CRITICAL: Always Read These Documents

**Before any crowbar development, ALWAYS read:**
- `docs/WORKFLOWS.md` - SPARC methodology, Agent OS, mobile workflows
- `docs/RULES.md` - Coding standards, execution patterns, best practices
- `docs/QUICK-START.md` - Fast reference for commands, testing, deployment
- `docs/ARCHON.md` - Archon MCP integration (task management, knowledge base)
- `docs/MOBILE.md` - React Native specific guidelines
- `docs/BACKEND.md` - Node.js/Express API patterns

**How to load on-demand**: Use `@docs/filename.md` syntax to load only when needed.
```

**Sections to Keep**:
- Project Overview (update to reference docs)
- Technical Architecture (summarize, link to BACKEND.md/MOBILE.md)
- Current Status (metrics dashboard)
- Key Commands (link to QUICK-START.md)

**Sections to Remove/Move**:
- Detailed architecture → Move to `docs/BACKEND.md` and `docs/MOBILE.md`
- Team structure → Move to `docs/PROJECT-STATUS.md`
- Detailed workflows → Move to `docs/WORKFLOWS.md`

**Template**:
```markdown
# CLAUDE.md - Crowbar Project Configuration

> **Version**: 2.0.0 | **Updated**: 2025-10-30
> **Project**: Crowbar - Gamified Mystery Box Marketplace
> **Status**: MVP Complete (80%) - Production Preparation Phase

## 🔖 CRITICAL: Always Read These Documents
[Document navigation guide]

## 📚 Document Navigation - When to Read Which Document
[Detailed guide with example queries]

## 📍 Project Context
[High-level summary with links to detailed docs]

## 🚨 CRITICAL RULES - Quick Reference
[Golden rule: concurrent execution, file organization]

## 🎯 Workflows & Methodologies
[Agent OS and SPARC methodology overview]

## 📊 Performance & Features
[Metrics and benefits]

## 🔧 Quick Operations
[Essential commands with links to QUICK-START.md]
```

---

### 2. docs/WORKFLOWS.md (New File)

**Action**: Create from agl-hostman template, adapt to mobile development

**Content Adaptation**:
- Replace infrastructure workflows → React Native workflows
- Keep Agent OS integration (7 commands, 16 skills)
- Keep SPARC methodology (5 phases)
- Update available agents list for mobile development

**Crowbar-Specific Workflows** (4 specs to create):
1. **Mobile Component Development** (`specs/mobile-component.yaml`)
2. **API Integration Testing** (`specs/api-integration-test.yaml`)
3. **E2E Test Suite Execution** (`specs/e2e-test-run.yaml`)
4. **Production Build Validation** (`specs/prod-build-validate.yaml`)

**Example Workflow**:
```yaml
name: mobile-component-development
description: TDD workflow for React Native components
agents:
  - type: specification
    task: Define component requirements and acceptance criteria
  - type: coder
    task: Implement component with TypeScript strict mode
  - type: tester
    task: Write unit tests with React Native Testing Library
  - type: reviewer
    task: Validate component against ACCEPTANCE_CRITERIA.md
testing:
  framework: jest
  coverage_target: 85%
output:
  - component: src/components/
  - tests: tests/components/
  - stories: storybook/
```

---

### 3. docs/RULES.md (New File)

**Action**: Create from agl-hostman template, adapt to mobile/backend context

**Key Adaptations**:
- Keep concurrent execution rules (CRITICAL)
- Keep file organization rules (CRITICAL)
- Keep mandatory subagent usage (CRITICAL)
- Update examples to React Native/Node.js code

**Crowbar-Specific Rules**:
```markdown
## 📁 File Organization Rules

**NEVER save to root folder. Use these directories:**

**Backend** (`crowbar-backend/`):
- `/src/api/v1/controllers` - Request handlers
- `/src/api/v1/routes` - Route definitions
- `/src/api/v1/validators` - Joi schemas
- `/src/core/services` - Business logic
- `/tests` - Test files

**Mobile** (`crowbar-mobile/`):
- `/src/components` - Reusable UI components
- `/src/screens` - Screen components
- `/src/services` - API clients and business logic
- `/src/store/slices` - Redux state management
- `/tests` - Test files (unit, integration, e2e)

## 🎯 Mobile-Specific Standards

**React Native Best Practices**:
- ✅ TypeScript strict mode enabled
- ✅ Maximum 500 lines per file
- ✅ ESLint + Prettier enforcement
- ✅ Brazilian Portuguese for comments
- ✅ Conventional Commits format
- ✅ 85%+ test coverage requirement

**Testing Requirements**:
- Unit tests: Jest + React Native Testing Library
- E2E tests: Detox
- Integration tests: Supertest (backend)
- Minimum 80% backend, 85% mobile coverage
```

---

### 4. docs/QUICK-START.md (New File)

**Action**: Create from agl-hostman template, adapt to crowbar context

**Replace Infrastructure Commands** → **Mobile/Backend Commands**:

**Environment Detection** → **Project Detection**:
```bash
# Detect which project you're in
if [[ -f "crowbar-mobile/package.json" ]]; then
    echo "Mobile project (React Native)"
elif [[ -f "crowbar-backend/package.json" ]]; then
    echo "Backend project (Node.js/Express)"
fi
```

**Quick Connections** → **Quick Development**:
```bash
# Backend Development
cd crowbar-backend
npm run dev            # Start with nodemon
npm test              # Run tests
npm run lint          # ESLint

# Mobile Development
cd crowbar-mobile
npm start             # Start Metro bundler
npm run android       # Launch Android emulator
npm run ios           # Launch iOS simulator
npm run quality       # Lint + Format + Type-check
```

**Essential Commands** → **Testing & Deployment**:
```bash
# E2E Testing
cd crowbar-mobile
npm run test:e2e      # Detox E2E tests

# Production Builds
npm run build:android       # Android APK
npm run build:ios          # iOS IPA
npm run build:production   # Both platforms

# Backend Deployment (Dokploy)
cd crowbar-backend
docker-compose build       # Build image
docker-compose push        # Push to Harbor
# Trigger Dokploy webhook
```

---

### 5. docs/ARCHON.md (New File)

**Action**: Create from agl-hostman template, adapt MCP connection

**Key Changes**:
- Keep MCP tools reference (28 tools)
- Update project context: infrastructure → mobile marketplace
- Create crowbar-specific MCP usage examples

**Crowbar-Specific MCP Usage**:
```typescript
// Create project for MVP features
archon:manage_project({
  action: "create",
  name: "Crowbar Mobile - Gamification Phase",
  description: "Implement box opening animations and achievement system",
  status: "active",
  tags: ["mobile", "react-native", "gamification"]
})

// Track mobile development tasks
archon:manage_task({
  action: "create",
  title: "Implement box opening animation with Lottie",
  project_id: "crowbar-mobile-gamification",
  priority: "high",
  status: "todo",
  description: "Create engaging box opening experience with Reanimated and Lottie"
})

// Search React Native code examples
archon:rag_search_code_examples({
  query: "React Native animations Reanimated",
  language: "typescript",
  limit: 5
})
```

**Project Structure in Archon**:
```
Projects:
├── Crowbar Backend - API Development
│   ├── Tasks: API endpoints, database migrations, payment integration
│   └── Documents: API specs, architecture diagrams
│
├── Crowbar Mobile - Core Features
│   ├── Tasks: Authentication, marketplace, cart, checkout
│   └── Documents: Component specs, screen flows
│
└── Crowbar Mobile - Gamification
    ├── Tasks: Animations, achievements, leaderboard
    └── Documents: Animation specs, game mechanics
```

---

### 6. docs/MOBILE.md (New File)

**Action**: Create new (consolidate mobile-specific content from TECHNICAL_ANALYSIS.md)

**Content**:
- React Native architecture (from TECHNICAL_ANALYSIS.md lines 222-357)
- Redux state management patterns
- API integration with httpClient
- Testing strategy (Jest, Detox)
- Platform-specific configurations (Android/iOS)
- Performance optimizations
- Offline support patterns

**Example Section**:
```markdown
## 🏗️ Architecture Patterns

### Component Structure
```
src/components/
├── common/              # Shared UI components
│   ├── Button.tsx      # Reusable button
│   ├── Card.tsx        # Card component
│   └── Input.tsx       # Form input
├── achievements/        # Gamification components
├── animations/          # Animation wrappers
└── [feature]/          # Feature-specific components
```

### State Management
```typescript
// Redux Toolkit Slice Pattern
import { createSlice, createAsyncThunk } from '@reduxjs/toolkit'

export const fetchBoxes = createAsyncThunk(
  'boxes/fetchBoxes',
  async (filters, { rejectWithValue }) => {
    try {
      const response = await httpClient.get('/api/v1/boxes', { params: filters })
      return response.data
    } catch (error) {
      return rejectWithValue(error.response.data)
    }
  }
)

const boxSlice = createSlice({
  name: 'boxes',
  initialState: { items: [], loading: false, error: null },
  reducers: {},
  extraReducers: (builder) => {
    builder
      .addCase(fetchBoxes.pending, (state) => { state.loading = true })
      .addCase(fetchBoxes.fulfilled, (state, action) => {
        state.items = action.payload
        state.loading = false
      })
      .addCase(fetchBoxes.rejected, (state, action) => {
        state.error = action.payload
        state.loading = false
      })
  }
})
```
```

---

### 7. docs/BACKEND.md (New File)

**Action**: Create new (consolidate backend content from TECHNICAL_ANALYSIS.md)

**Content**:
- Node.js/Express architecture (from TECHNICAL_ANALYSIS.md lines 53-220)
- Database models and relationships
- API versioning strategy (v1 migration)
- Authentication & security
- Payment integration (Pagar.me)
- Real-time features (Socket.IO)

**Example Section**:
```markdown
## 🗄️ Database Schema

### Core Models

```javascript
// User Model
User {
  id: UUID (PK)
  email: STRING (unique)
  uid: STRING (Firebase UID)
  role: ENUM('user', 'seller', 'superadmin')
  createdAt: TIMESTAMP
  updatedAt: TIMESTAMP

  // Associations
  hasMany: Box (as owner)
  hasMany: Order
  hasMany: FavoriteBox
  hasMany: Address
}

// Box Model
Box {
  id: UUID (PK)
  title: STRING
  description: TEXT
  price: DECIMAL(10,2)
  stock: INTEGER
  status: ENUM('active', 'inactive', 'sold_out')
  category_id: UUID (FK)
  owner_id: UUID (FK to User)

  // Associations
  belongsTo: User (as owner)
  belongsTo: Category
  hasMany: Product
  hasMany: Order
}
```

### API Patterns

```javascript
// Modern Controller Pattern (src/api/v1/controllers/)
class BoxController {
  async index(req, res, next) {
    try {
      const { category, status, page = 1, limit = 20 } = req.query
      const boxes = await BoxService.findAll({ category, status, page, limit })
      res.json({ success: true, data: boxes })
    } catch (error) {
      next(error) // Centralized error handling
    }
  }
}
```
```

---

## 🔧 Configuration Templates for Crowbar

### 1. Agent OS Skills Configuration

**File**: `crowbar-mobile/.agent-os/config.yml`

```yaml
project:
  name: crowbar-mobile
  type: react-native
  language: typescript

skills:
  infrastructure:
    - verification-before-completion
    - testing-anti-patterns
    - condition-based-waiting

  development:
    - using-superpowers
    - testing-skills-with-subagents

  mobile:
    - frontend-components
    - frontend-accessibility
    - frontend-responsive
    - frontend-css

workflows:
  - specs/mobile-component.yaml
  - specs/api-integration-test.yaml
  - specs/e2e-test-run.yaml
  - specs/prod-build-validate.yaml

memory:
  namespace: crowbar-mobile
  storage: sqlite
  persistence: true
```

---

### 2. SPARC Methodology Configuration

**File**: `crowbar-mobile/.sparc/config.json`

```json
{
  "project": "crowbar-mobile",
  "methodology": "sparc",
  "phases": {
    "specification": {
      "template": "mobile-feature-spec.md",
      "output": "ai-docs/planning/"
    },
    "pseudocode": {
      "language": "typescript",
      "output": "ai-docs/design/"
    },
    "architecture": {
      "diagrams": true,
      "output": "ai-docs/architecture/"
    },
    "refinement": {
      "tdd": true,
      "coverage_target": 85,
      "framework": "jest"
    },
    "completion": {
      "validation": "ai-docs/planning/ACCEPTANCE_CRITERIA.md",
      "integration_tests": true
    }
  },
  "agents": {
    "coordinator": "sparc-coord",
    "specification": "specification",
    "architecture": "architect",
    "implementation": "sparc-coder",
    "testing": "tester",
    "review": "reviewer"
  }
}
```

---

### 3. Archon MCP Connection

**File**: `crowbar-mobile/.claude/mcp-servers.json`

```json
{
  "mcpServers": {
    "archon-wg": {
      "transport": "http",
      "url": "http://10.6.0.21:8051/mcp",
      "description": "Archon AI Command Center (WireGuard)"
    },
    "archon-tailscale": {
      "transport": "http",
      "url": "http://100.80.30.59:8051/mcp",
      "description": "Archon AI Command Center (Tailscale backup)"
    }
  }
}
```

**Setup Command**:
```bash
# From development environment
claude mcp add --transport http archon-wg http://10.6.0.21:8051/mcp
claude mcp list  # Verify connection
```

---

### 4. Harbor Registry Configuration

**File**: `crowbar-backend/.harbor/config.yml`

```yaml
registry:
  url: harbor.aglz.io:5000
  project: crowbar

images:
  backend:
    name: harbor.aglz.io:5000/crowbar/backend
    tag_strategy: git-sha
    latest: true

authentication:
  username: ${HARBOR_USERNAME}
  password: ${HARBOR_PASSWORD}

automation:
  push_on_build: true
  cleanup_policy:
    keep_last: 10
    keep_tags: ["latest", "production-*"]
```

**Docker Compose Update**:
```yaml
# crowbar-backend/docker-compose.yml
version: '3.8'

services:
  crowbar-backend:
    image: harbor.aglz.io:5000/crowbar/backend:${GIT_SHA:-latest}
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - NODE_ENV=production
      - DATABASE_URL=${DATABASE_URL}
    ports:
      - "5000:5000"
```

---

### 5. Dokploy Deployment Configuration

**File**: `crowbar-backend/.dokploy/deploy.yml`

```yaml
project:
  name: crowbar-backend
  description: Crowbar mystery box marketplace API

deployment:
  method: docker-compose
  file: docker-compose.yml

  registry:
    url: harbor.aglz.io:5000
    credentials:
      username: ${HARBOR_USERNAME}
      password: ${HARBOR_PASSWORD}

  environment:
    NODE_ENV: production
    DATABASE_URL: ${DATABASE_URL}
    FIREBASE_ADMIN_KEY: ${FIREBASE_ADMIN_KEY}
    PAGARME_API_KEY: ${PAGARME_API_KEY}

  health_check:
    endpoint: /health
    interval: 30s
    timeout: 10s
    retries: 3

  monitoring:
    logs: true
    metrics: true
    alerts:
      - type: error_rate
        threshold: 5%
      - type: response_time
        threshold: 2s

webhooks:
  github:
    enabled: true
    branches: ["main", "develop"]
    auto_deploy: true

  harbor:
    enabled: true
    on_push: true
```

**Webhook Setup**:
```bash
# GitHub webhook URL (from Dokploy dashboard)
https://dok.aglz.io/webhooks/github/crowbar-backend

# Harbor webhook URL
https://dok.aglz.io/webhooks/harbor/crowbar-backend
```

---

### 6. Branch Strategy Configuration

**File**: `crowbar-mobile/.git/config`

```ini
[core]
    repositoryformatversion = 0
    filemode = true
    bare = false

[branch "main"]
    remote = origin
    merge = refs/heads/main
    description = Production-ready code

[branch "develop"]
    remote = origin
    merge = refs/heads/develop
    description = Integration branch for features

[branch]
    autosetupmerge = always
    autosetuprebase = always
```

**File**: `crowbar-mobile/.github/BRANCH_STRATEGY.md`

```markdown
# Branch Strategy

## Main Branches

### main
- **Purpose**: Production-ready code
- **Protection**: Required reviews, passing CI
- **Deployment**: Auto-deploy to production (manual approval)
- **Merges**: Only from `develop` via PR

### develop
- **Purpose**: Integration branch
- **Protection**: Passing CI required
- **Deployment**: Auto-deploy to staging
- **Merges**: From feature/* branches

## Supporting Branches

### feature/*
- **Pattern**: `feature/box-opening-animation`
- **From**: `develop`
- **Merge to**: `develop`
- **Lifetime**: Until feature complete

### fix/*
- **Pattern**: `fix/cart-calculation-error`
- **From**: `develop`
- **Merge to**: `develop`
- **Lifetime**: Until fix verified

### hotfix/*
- **Pattern**: `hotfix/payment-critical-bug`
- **From**: `main`
- **Merge to**: `main` AND `develop`
- **Lifetime**: Immediate (< 24h)

### release/*
- **Pattern**: `release/v1.2.0`
- **From**: `develop`
- **Merge to**: `main` AND `develop`
- **Lifetime**: Until production release

## Workflow Example

```bash
# Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/achievement-system

# Work on feature
git add .
git commit -m "feat: add achievement tracking service"

# Push and create PR
git push origin feature/achievement-system
# Create PR: feature/achievement-system → develop

# After PR approval and merge
git checkout develop
git pull origin develop
git branch -d feature/achievement-system
```
```

---

## ⚠️ Risks and Mitigation Strategies

### Risk 1: Context Mismatch (HIGH)
**Issue**: Documentation assumes infrastructure management, crowbar is mobile marketplace
**Impact**: Confusion, incorrect implementation patterns
**Mitigation**:
- Create crowbar-specific examples in every document
- Replace infrastructure terminology with mobile/e-commerce terms
- Add "Crowbar Context" sections explaining adaptations
- Validate with mobile development team

### Risk 2: Tooling Incompatibility (MEDIUM)
**Issue**: Agent OS/SPARC may not have mobile-specific workflows
**Impact**: Reduced automation benefits
**Mitigation**:
- Create custom workflow specs for React Native
- Extend skills with mobile-specific patterns
- Document workarounds for missing features
- Contribute mobile workflows back to Agent OS

### Risk 3: Over-Documentation (MEDIUM)
**Issue**: Too much documentation reduces agility
**Impact**: Developers ignore docs, maintenance burden
**Mitigation**:
- Keep docs concise (< 500 lines each)
- Use on-demand loading pattern (@docs/file.md)
- Focus on "when to read" guidance
- Regular doc reviews and pruning

### Risk 4: Team Adoption (MEDIUM)
**Issue**: Team may resist new workflows and tools
**Impact**: Low usage, benefits not realized
**Mitigation**:
- Gradual rollout (Phase 1: Docs only, Phase 2: Tools)
- Training sessions on Agent OS and SPARC
- Quick wins demonstration (task tracking, code examples)
- Collect feedback and iterate

### Risk 5: MCP Integration Failure (LOW)
**Issue**: Archon MCP may not be accessible from crowbar dev environment
**Impact**: Task management and knowledge base unavailable
**Mitigation**:
- Test MCP connection from crowbar workspace
- Provide SSH tunnel alternative
- Document offline fallback procedures
- Local Archon instance option

### Risk 6: Azure Integration Complexity (MEDIUM)
**Issue**: Dokploy/Harbor configured for Proxmox, crowbar uses Azure
**Impact**: Deployment automation doesn't work
**Mitigation**:
- Azure-specific deployment guide in docs/DEPLOYMENT.md
- Azure Container Registry as Harbor alternative
- Azure DevOps pipelines documentation
- Hybrid approach: Keep Dokploy for staging, Azure for prod

---

## ✅ Validation and Testing Checklist

### Phase 1: Documentation Validation (Week 1)

**CLAUDE.md**:
- [ ] Navigation guide has all 6 documents referenced
- [ ] On-demand loading syntax explained (@docs/file.md)
- [ ] Project context updated to mobile marketplace
- [ ] Quick operations specific to crowbar (npm scripts)
- [ ] Performance benefits included
- [ ] File size < 450 lines

**docs/WORKFLOWS.md**:
- [ ] Agent OS commands documented (7 total)
- [ ] SPARC methodology explained (5 phases)
- [ ] Mobile-specific workflows created (4 specs)
- [ ] Integration with Archon MCP shown
- [ ] React Native examples throughout
- [ ] File size < 600 lines

**docs/RULES.md**:
- [ ] Concurrent execution rules present
- [ ] File organization for mobile/backend
- [ ] Mandatory subagent usage explained
- [ ] TypeScript strict mode rules
- [ ] Brazilian Portuguese comment rule
- [ ] 85% coverage requirement
- [ ] File size < 400 lines

**docs/QUICK-START.md**:
- [ ] Environment detection (mobile vs backend)
- [ ] Quick development commands (npm scripts)
- [ ] Testing procedures (unit, E2E)
- [ ] Production build instructions
- [ ] Troubleshooting guide
- [ ] File size < 350 lines

**docs/ARCHON.md**:
- [ ] MCP connection instructions
- [ ] All 28 tools documented
- [ ] Crowbar-specific usage examples
- [ ] Project structure in Archon
- [ ] Knowledge base integration
- [ ] File size < 400 lines

**docs/MOBILE.md**:
- [ ] React Native architecture
- [ ] Redux patterns documented
- [ ] API integration examples
- [ ] Testing strategy (Jest, Detox)
- [ ] Platform configs (Android, iOS)
- [ ] File size < 500 lines

**docs/BACKEND.md**:
- [ ] Node.js/Express patterns
- [ ] Database schema documented
- [ ] API versioning explained
- [ ] Security practices
- [ ] Payment integration (Pagar.me)
- [ ] File size < 500 lines

---

### Phase 2: Integration Validation (Week 2)

**Agent OS Setup**:
- [ ] Installed globally: `npm install -g @agentos/cli`
- [ ] Initialized in mobile project: `agentos init`
- [ ] Skills configured in `.agent-os/config.yml`
- [ ] 4 workflow specs created in `specs/`
- [ ] Test workflow execution: `agentos run specs/mobile-component.yaml`

**SPARC Configuration**:
- [ ] Config file created: `.sparc/config.json`
- [ ] Test spec phase: `npx claude-flow sparc run spec-pseudocode "test feature"`
- [ ] Test architecture phase: `npx claude-flow sparc run architect "test service"`
- [ ] Test TDD phase: `npx claude-flow sparc tdd "test component"`

**Archon MCP**:
- [ ] MCP server added: `claude mcp add archon-wg http://10.6.0.21:8051/mcp`
- [ ] Connection verified: `claude mcp list`
- [ ] Test project creation: `archon:manage_project`
- [ ] Test task creation: `archon:manage_task`
- [ ] Test knowledge search: `archon:rag_search_knowledge_base`

**Branch Strategy**:
- [ ] Main branch protected (requires reviews)
- [ ] Develop branch auto-deploys to staging
- [ ] Feature branch workflow tested
- [ ] Hotfix workflow documented
- [ ] Git hooks configured (pre-commit, pre-push)

**Harbor Registry**:
- [ ] Harbor project created: `crowbar`
- [ ] Docker image pushed: `harbor.aglz.io:5000/crowbar/backend`
- [ ] Webhook configured for auto-push
- [ ] Cleanup policy set (keep last 10)
- [ ] Authentication tested

**Dokploy Deployment**:
- [ ] Project created in Dokploy dashboard
- [ ] Docker Compose method configured
- [ ] Environment variables set
- [ ] Health check endpoint verified
- [ ] GitHub webhook configured
- [ ] Test deployment successful

---

### Phase 3: End-to-End Validation (Week 3)

**Documentation Loading**:
- [ ] Test on-demand loading: Reference `@docs/WORKFLOWS.md` in Claude Code
- [ ] Verify navigation works: "How to run E2E tests?" → QUICK-START.md
- [ ] Check modular benefits: Token usage reduced by 30%+

**Development Workflow**:
- [ ] Create feature branch following strategy
- [ ] Use Agent OS for component development
- [ ] Track task in Archon MCP
- [ ] Run SPARC TDD workflow
- [ ] Create PR, verify CI passes
- [ ] Merge to develop, check staging deploy

**Deployment Pipeline**:
- [ ] Push code to develop branch
- [ ] Verify Docker build in Harbor
- [ ] Dokploy auto-deploys to staging
- [ ] Health check passes
- [ ] Create release branch
- [ ] Deploy to production via main branch
- [ ] Verify monitoring and logs

**Team Feedback**:
- [ ] Developer survey: Docs helpful? (Target: 4/5)
- [ ] Adoption metrics: % using Archon MCP (Target: 50%)
- [ ] Time savings: Task completion faster? (Target: 20% faster)
- [ ] Quality metrics: Test coverage improved? (Target: 85%+)

**Performance Metrics**:
- [ ] Token usage reduction: Measured before/after (Target: 30%+)
- [ ] Development speed: Feature completion time (Target: 20% faster)
- [ ] Code quality: ESLint errors reduced (Target: < 5 errors)
- [ ] Test coverage: Mobile at 85%+ (from current ~70%)

---

## 📊 Success Metrics

### Quantitative Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| Documentation Size | 480 lines (CLAUDE.md only) | 2,800 lines (7 docs) | Line count |
| Token Usage | 100% (full CLAUDE.md load) | 30-40% (on-demand) | Claude Code API |
| Development Speed | Baseline feature time | 20% faster | Sprint velocity |
| Test Coverage (Mobile) | ~70% | 85%+ | Jest coverage report |
| Test Coverage (Backend) | ~80% | 85%+ | Jest coverage report |
| ESLint Errors | ~50 errors | < 5 errors | `npm run lint` output |
| Archon MCP Usage | 0 tasks | 50+ tasks/month | Archon analytics |
| CI/CD Success Rate | ~80% | 95%+ | GitHub Actions metrics |

### Qualitative Metrics

| Metric | Success Criteria | Measurement |
|--------|------------------|-------------|
| Developer Satisfaction | 4/5 rating on docs | Survey after 2 weeks |
| Tool Adoption | 50%+ team using Archon | Usage analytics |
| Workflow Clarity | < 5 clarification requests/week | Support tickets |
| Onboarding Time | New dev productive in < 3 days | Onboarding feedback |

---

## 🚀 Implementation Timeline

### Week 1: Documentation Foundation
**Days 1-2**: CLAUDE.md update
- Morning: Review agl-hostman template
- Afternoon: Adapt to crowbar context
- Evening: Validate with team

**Days 3-4**: Core docs creation (WORKFLOWS.md, RULES.md)
- Create mobile-specific workflow specs
- Adapt coding standards to React Native
- Document testing requirements

**Day 5**: Reference docs (QUICK-START.md, ARCHON.md)
- Quick command reference
- MCP integration guide
- Troubleshooting procedures

---

### Week 2: Tool Integration
**Days 1-2**: Agent OS & SPARC setup
- Install Agent OS CLI
- Configure skills for mobile development
- Create SPARC workflow configs
- Test spec execution

**Days 3-4**: Archon MCP integration
- Configure MCP endpoints
- Create crowbar projects in Archon
- Migrate existing tasks
- Test knowledge base

**Day 5**: Branch strategy & Git workflow
- Configure branch protection
- Set up Git hooks
- Document workflow procedures
- Test feature branch flow

---

### Week 3: Deployment Integration
**Days 1-2**: Harbor registry setup
- Create crowbar project in Harbor
- Configure Docker builds
- Set up webhooks
- Test image push/pull

**Days 3-4**: Dokploy configuration
- Create deployment project
- Configure environment variables
- Set up health checks
- Test auto-deployment

**Day 5**: Validation & documentation
- Run full validation checklist
- Collect metrics (token usage, coverage)
- Team feedback session
- Update docs with learnings

---

## 📝 Implementation Notes

### Key Differences: agl-hostman vs crowbar

| Aspect | agl-hostman | crowbar | Adaptation Required |
|--------|-------------|---------|---------------------|
| **Domain** | Infrastructure management | Mobile marketplace | HIGH - Complete context change |
| **Tech Stack** | Docker, Proxmox, WireGuard | React Native, Node.js, Azure | MEDIUM - Keep patterns, change examples |
| **Network Focus** | LAN, WireGuard mesh, Tailscale | Cloud APIs, Firebase, Payment gateways | HIGH - Replace network sections |
| **Deployment** | Proxmox LXC containers | Azure App Service, mobile app stores | HIGH - New deployment docs needed |
| **Development** | Bash scripts, infrastructure code | TypeScript, React components, API routes | MEDIUM - Different code examples |
| **Team Size** | 1-2 DevOps | 15-25 full team | LOW - Scales well |

### Adaptation Strategy

1. **Keep Structure, Change Content**
   - Document structure (6-7 files) is universal
   - Navigation pattern works for any project
   - Concurrent execution rules apply everywhere
   - Change examples from infrastructure → mobile

2. **Focus on Development Workflows**
   - Replace infrastructure workflows with mobile workflows
   - Keep SPARC methodology (language-agnostic)
   - Keep Agent OS integration (task-agnostic)
   - Add React Native specific patterns

3. **Simplify Network Sections**
   - Remove WireGuard, Tailscale, LAN sections
   - Add Azure networking, Firebase config
   - Focus on API endpoints, webhook integration
   - Document local development environment

4. **Enhance Mobile-Specific Content**
   - Add Android/iOS build procedures
   - Document platform-specific quirks
   - Testing strategies (unit, E2E, integration)
   - App store submission process

---

## 🎯 Next Steps After Implementation

### Immediate (Week 4)
- Team training session on new documentation
- Onboard first feature using new workflows
- Collect initial feedback
- Fix any critical issues

### Short-term (Month 1)
- Measure adoption metrics
- Refine workflows based on usage
- Create additional workflow specs
- Expand Archon knowledge base

### Medium-term (Month 2-3)
- Advanced Agent OS skills development
- Custom mobile development skills
- Automated testing workflows
- Performance optimization workflows

### Long-term (Month 4+)
- Contribute mobile workflows to Agent OS
- Share learnings with community
- Continuous improvement based on metrics
- Scale to other projects

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-30
**Maintainer**: Hive Mind Coder Agent
**Next Review**: Post-Implementation (2025-11-20)

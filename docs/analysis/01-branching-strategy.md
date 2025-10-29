# Branching Strategy and Git Workflow Analysis

> **Document**: Deployment Workflow Analysis - Part 1
> **Version**: 1.0.0
> **Created**: 2025-10-28
> **Author**: Analyst Agent (Hive Mind)

---

## 📋 Executive Summary

This document defines the complete branching strategy for the AGL infrastructure management project, establishing clear promotion paths from development through production with automated CI/CD integration.

---

## 🎯 Environment Topology

### Environment Hierarchy

```
┌─────────────────────────────────────────────────────────────┐
│                        PRODUCTION                            │
│                         (main)                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AGLSRV1 Production Containers                       │   │
│  │  - CT180 (dokploy-prod)                             │   │
│  │  - Harbor Registry (production tags)                 │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                             ▲
                             │ PR + Approvals (2)
                             │
┌─────────────────────────────────────────────────────────────┐
│                           UAT                                │
│                        (release)                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AGLSRV1 UAT Environment                            │   │
│  │  - CT181 (dokploy-uat)                              │   │
│  │  - Harbor: harbor.aglz.io/uat/*                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                             ▲
                             │ PR + Approval (1)
                             │
┌─────────────────────────────────────────────────────────────┐
│                           QA                                 │
│                      (staging)                               │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  AGLSRV1 QA Environment                             │   │
│  │  - CT182 (dokploy-qa)                               │   │
│  │  - Harbor: harbor.aglz.io/qa/*                      │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                             ▲
                             │ PR (auto-merge on CI pass)
                             │
┌─────────────────────────────────────────────────────────────┐
│                       DEVELOPMENT                            │
│                       (develop)                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  CT179 (agldv03) - Primary Development              │   │
│  │  - Docker Compose stacks                            │   │
│  │  - Harbor: harbor.aglz.io/dev/*                     │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                             ▲
                             │ PR from feature branches
                             │
┌─────────────────────────────────────────────────────────────┐
│                   FEATURE BRANCHES                           │
│              (feature/*, bugfix/*, hotfix/*)                 │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Developer Workstations                              │   │
│  │  - WSL2 (AGLHQ11)                                   │   │
│  │  - CT179 (agldv03)                                  │   │
│  │  - CT108 (agldv06)                                  │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 🌳 Branch Structure

### Long-Lived Branches

#### 1. **main** (Production)
- **Purpose**: Production-ready code
- **Protection Level**: Maximum
- **Auto-Deploy**: Yes (to CT180 via Dokploy)
- **Merge From**: release only
- **Deployment Target**: AGLSRV1 production containers

**Protection Rules**:
- ✅ Require 2 approvals minimum
- ✅ Require status checks to pass
- ✅ Require conversation resolution
- ✅ Require signed commits
- ✅ No force push
- ✅ No deletion
- ✅ Restrict who can push (maintainers only)
- ✅ Require linear history

#### 2. **release** (UAT)
- **Purpose**: User acceptance testing
- **Protection Level**: High
- **Auto-Deploy**: Yes (to CT181 via Dokploy)
- **Merge From**: staging only
- **Deployment Target**: AGLSRV1 UAT environment

**Protection Rules**:
- ✅ Require 1 approval minimum
- ✅ Require status checks to pass
- ✅ Require conversation resolution
- ✅ No force push
- ✅ No deletion
- ✅ Restrict who can push (maintainers + leads)

#### 3. **staging** (QA)
- **Purpose**: Quality assurance and integration testing
- **Protection Level**: Medium
- **Auto-Deploy**: Yes (to CT182 via Dokploy)
- **Merge From**: develop only
- **Deployment Target**: AGLSRV1 QA environment

**Protection Rules**:
- ✅ Require status checks to pass
- ✅ Auto-merge when checks pass
- ✅ No force push
- ✅ No deletion

#### 4. **develop** (Development)
- **Purpose**: Integration branch for features
- **Protection Level**: Light
- **Auto-Deploy**: Optional (to CT179 Docker stacks)
- **Merge From**: feature/*, bugfix/*
- **Deployment Target**: CT179 development environment

**Protection Rules**:
- ✅ Require status checks to pass
- ✅ Delete head branches on merge
- ⚠️ Allow force push (for rebasing only)

---

### Short-Lived Branches

#### Feature Branches
**Naming**: `feature/<issue-number>-<short-description>`

**Examples**:
- `feature/123-wireguard-mesh-expansion`
- `feature/456-archon-mcp-integration`
- `feature/789-docker-compose-optimization`

**Lifecycle**:
1. Branch from `develop`
2. Develop feature
3. Create PR to `develop`
4. Delete after merge

#### Bugfix Branches
**Naming**: `bugfix/<issue-number>-<short-description>`

**Examples**:
- `bugfix/234-fix-nfs-mount-timeout`
- `bugfix/567-resolve-docker-network-conflict`

**Lifecycle**:
1. Branch from `develop`
2. Fix bug
3. Create PR to `develop`
4. Delete after merge

#### Hotfix Branches
**Naming**: `hotfix/<issue-number>-<short-description>`

**Examples**:
- `hotfix/890-critical-security-patch`
- `hotfix/901-production-disk-full`

**Lifecycle**:
1. Branch from `main`
2. Fix critical issue
3. Create PR to `main` AND `develop`
4. Fast-track approval process
5. Delete after merge

---

## 🔄 Pull Request Workflow

### PR Templates

#### Feature/Bugfix PR to Develop
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Feature
- [ ] Bugfix
- [ ] Refactor
- [ ] Documentation
- [ ] Infrastructure

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex logic
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests passing locally
- [ ] No new warnings generated

## Testing
Describe testing performed

## Related Issues
Closes #<issue-number>
```

#### Staging PR (develop → staging)
```markdown
## Release Summary
List of features and bugfixes in this integration

## Changes Since Last Staging
- Feature: <description>
- Bugfix: <description>

## QA Checklist
- [ ] All unit tests passing
- [ ] Integration tests passing
- [ ] No critical security issues
- [ ] Dependencies updated
- [ ] Database migrations tested
- [ ] Rollback procedure documented

## Deployment Notes
Special considerations for QA deployment

## Related PRs
- #<pr-number>
- #<pr-number>
```

#### UAT PR (staging → release)
```markdown
## UAT Release
Version: <semantic-version>

## Tested in QA
- [ ] All features validated
- [ ] Performance benchmarks met
- [ ] Security scan passed
- [ ] Load testing completed
- [ ] Backward compatibility verified

## User Acceptance Criteria
- [ ] Business requirements met
- [ ] User stories completed
- [ ] Stakeholder sign-off

## Deployment Plan
Detailed deployment steps for UAT

## Rollback Plan
How to revert if issues found
```

#### Production PR (release → main)
```markdown
## Production Release
Version: <semantic-version>
Release Date: <date>

## UAT Sign-Off
- [ ] All UAT tests passed
- [ ] Stakeholder approval obtained
- [ ] Documentation complete
- [ ] Monitoring alerts configured
- [ ] Backup verified

## Production Checklist
- [ ] Maintenance window scheduled
- [ ] Stakeholders notified
- [ ] Rollback plan tested
- [ ] Post-deployment verification plan
- [ ] Incident response team on standby

## Release Notes
User-facing changes and improvements

## Technical Changes
Infrastructure and backend changes

## Known Issues
Any accepted limitations or workarounds
```

---

## 👥 Approval Matrix

| Branch | Minimum Approvers | Required Roles | Auto-Merge |
|--------|------------------|----------------|------------|
| main | 2 | Maintainer + Lead | No |
| release | 1 | Lead or Maintainer | No |
| staging | 0 | - | Yes (on CI pass) |
| develop | 0 | - | Optional |

### Reviewer Responsibilities

**Maintainers** (main branch):
- Final security review
- Infrastructure impact assessment
- Production risk evaluation
- Compliance verification

**Leads** (release branch):
- Business logic validation
- User acceptance criteria check
- Documentation completeness
- Performance implications

**Developers** (develop branch):
- Code quality review
- Test coverage check
- Coding standards compliance
- Peer review

---

## 🔐 Merge Policies

### Merge Strategy by Branch

| Target Branch | Strategy | Reason |
|--------------|----------|--------|
| main | Squash + Merge | Clean history, single commit per release |
| release | Squash + Merge | Consolidate QA fixes |
| staging | Merge Commit | Preserve feature branch history |
| develop | Merge Commit | Track feature integration points |

### Merge Restrictions

**main**:
- Only from `release` branch
- Requires CI/CD pipeline success
- Requires security scan pass
- Requires 2 approvals
- Requires signed commits

**release**:
- Only from `staging` branch
- Requires CI/CD pipeline success
- Requires 1 approval
- Must pass UAT checklist

**staging**:
- Only from `develop` branch
- Requires CI/CD pipeline success
- Auto-merges when checks pass

**develop**:
- From `feature/*` or `bugfix/*`
- Requires CI/CD pipeline success
- Auto-delete source branch after merge

---

## 🚀 Promotion Flow

### Standard Promotion Path

```
feature/123 → develop → staging → release → main
  (PR)        (PR)      (PR)      (PR)

Timeline:
- feature → develop: Within sprint (1-3 days)
- develop → staging: Sprint end (every 2 weeks)
- staging → release: After QA pass (3-5 days)
- release → main: After UAT sign-off (2-3 days)
```

### Fast-Track (Hotfix) Path

```
hotfix/890 → main (emergency)
   └─────────→ develop (backport)

Timeline:
- hotfix → main: Emergency (< 4 hours)
- hotfix → develop: Immediate after main merge
```

---

## 📊 Branch Metrics

### Key Performance Indicators

1. **Lead Time**: Time from feature branch creation to production
   - Target: < 3 weeks for standard features
   - Critical: < 4 hours for hotfixes

2. **PR Cycle Time**: Time from PR creation to merge
   - develop: < 1 day
   - staging: < 2 days
   - release: < 3 days
   - main: < 1 day (after UAT)

3. **Branch Lifetime**:
   - Feature branches: < 5 days
   - Bugfix branches: < 2 days
   - Hotfix branches: < 4 hours

4. **Deployment Frequency**:
   - develop: Multiple times per day
   - staging: Every 2 weeks (sprint boundary)
   - release: Every 4 weeks
   - main: Every 4-6 weeks

---

## 🔍 Branch Health Checks

### Automated Checks

**Pre-Merge Checks** (all branches):
- ✅ Code compiles/builds successfully
- ✅ Unit tests pass (100% of tests)
- ✅ Linting rules pass (no errors)
- ✅ Security scan (no critical vulnerabilities)
- ✅ License compliance check

**develop → staging**:
- ✅ Integration tests pass
- ✅ API contract tests pass
- ✅ Database migration tests pass
- ✅ Docker image builds successfully

**staging → release**:
- ✅ End-to-end tests pass
- ✅ Performance benchmarks met
- ✅ Load tests pass
- ✅ Security penetration tests pass
- ✅ Browser compatibility tests (if applicable)

**release → main**:
- ✅ UAT sign-off documented
- ✅ Release notes generated
- ✅ Rollback procedure validated
- ✅ Monitoring configured
- ✅ Stakeholder approval recorded

---

## 🛡️ Security Considerations

### Branch Access Control

**GitHub Teams**:
- **Maintainers**: Full access to all branches
- **Leads**: Push to develop, staging, release (not main)
- **Developers**: Push to feature/* only
- **CI/CD Bot**: Push to develop, staging, release, main

### Commit Signing

**Required for**:
- main (enforced)
- release (enforced)
- staging (recommended)
- develop (optional)

**Setup**:
```bash
# Configure GPG signing
git config --global commit.gpgsign true
git config --global user.signingkey <your-key-id>

# Sign commits
git commit -S -m "feat: add new feature"
```

### Secrets Management

**Never commit**:
- API keys
- Passwords
- Private keys
- Database credentials
- Environment-specific configs

**Use instead**:
- GitHub Secrets for CI/CD
- Vault or environment variables at runtime
- `.env` files (gitignored) for local development

---

## 📈 Continuous Improvement

### Weekly Branch Review

**Review Metrics**:
- Average PR cycle time by branch
- Number of failed merges
- Hotfix frequency
- Branch lifetime violations

**Action Items**:
- Identify bottlenecks
- Update branch protection rules
- Refine approval process
- Improve automation

### Monthly Strategy Review

**Evaluate**:
- Deployment frequency targets
- Lead time improvements
- Quality gate effectiveness
- Developer feedback

**Adjust**:
- Branch policies
- Merge strategies
- Approval requirements
- Automation coverage

---

## 🔗 Related Documents

- **[CI/CD Pipeline Design](./02-cicd-pipeline.md)** - Automation workflows
- **[Environment Configuration](./03-environment-config.md)** - Environment setup
- **[Workflow Optimization](./04-workflow-optimization.md)** - Process improvements

---

**Document Owner**: Infrastructure Team
**Last Review**: 2025-10-28
**Next Review**: 2025-11-28
**Status**: Draft - Pending Implementation

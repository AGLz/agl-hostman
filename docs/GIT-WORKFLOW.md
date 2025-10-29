# Git Workflow - AGL Hostman

> **Version**: 1.0.0 | **Last Updated**: 2025-10-28

## 📋 Table of Contents

1. [Branch Structure](#-branch-structure)
2. [Workflow Overview](#-workflow-overview)
3. [Branch Protection Rules](#-branch-protection-rules)
4. [Pull Request Process](#-pull-request-process)
5. [Deployment Flow](#-deployment-flow)
6. [Hotfix Procedure](#-hotfix-procedure)
7. [Common Commands](#-common-commands)

---

## 🌳 Branch Structure

We use a **4-tier branching strategy** optimized for multi-environment deployments:

```
main (production)
  ↑
release (UAT)
  ↑
staging (QA)
  ↑
develop (dev)
  ↑
feature/* (developer branches)
```

### Branch Purposes

| Branch | Environment | Purpose | Auto-Deploy |
|--------|-------------|---------|-------------|
| **develop** | Development (CT179) | Integration branch for features | ✅ Yes |
| **staging** | QA (CT180) | Testing and quality assurance | ✅ Yes |
| **release** | UAT (CT181) | User acceptance testing | ⚠️ Manual |
| **main** | Production (CT182+) | Stable production code | ⚠️ Manual |

### Feature Branches

- **Naming**: `feature/<ticket-id>-<short-description>`
- **Example**: `feature/ARCH-123-harbor-integration`
- **Base**: Always branch from `develop`
- **Lifetime**: Delete after merge

---

## 🔄 Workflow Overview

### Standard Feature Development

```bash
# 1. Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/ARCH-123-new-dashboard

# 2. Make changes and commit
git add .
git commit -m "feat: add new dashboard component"

# 3. Push and create PR to develop
git push -u origin feature/ARCH-123-new-dashboard

# 4. After PR approval, merge to develop
# (automatic deployment to dev environment)

# 5. Promote to staging when ready
git checkout staging
git pull origin staging
git merge develop
git push origin staging

# 6. After QA approval, promote to release
git checkout release
git pull origin release
git merge staging
git push origin release

# 7. After UAT approval, promote to main
git checkout main
git pull origin main
git merge release --no-ff
git tag -a v1.2.3 -m "Release v1.2.3"
git push origin main --tags
```

---

## 🛡️ Branch Protection Rules

### develop Branch
- **Approvals Required**: 0 (fast iteration)
- **Status Checks Required**:
  - ✅ Lint and Test
  - ✅ Security Scan (Trivy)
  - ✅ Docker Build
- **Auto-Deploy**: Development environment (CT179)
- **Merge Strategy**: Squash and merge

### staging Branch
- **Approvals Required**: 1 (QA lead or senior dev)
- **Status Checks Required**:
  - ✅ All develop checks
  - ✅ Integration tests
- **Auto-Deploy**: QA environment (CT180)
- **Merge Strategy**: Merge commit (preserve history)

### release Branch
- **Approvals Required**: 1 (product owner or tech lead)
- **Status Checks Required**:
  - ✅ All staging checks
  - ✅ Smoke tests
- **Auto-Deploy**: UAT environment (CT181)
- **Merge Strategy**: Merge commit
- **Notes**: Release candidate testing

### main Branch
- **Approvals Required**: 2 (tech lead + product owner)
- **Status Checks Required**:
  - ✅ All release checks
  - ✅ Production health checks
- **Auto-Deploy**: Production (CT182+) with blue-green
- **Merge Strategy**: Merge commit (--no-ff)
- **Notes**: Requires manual trigger, creates git tag

---

## 📝 Pull Request Process

### Creating a PR

1. **Use PR Template**: `.github/PULL_REQUEST_TEMPLATE.md`
2. **Fill Required Sections**:
   - Description of changes
   - Type of change
   - Environment target
   - Testing performed
   - Related issues

3. **Self-Review Checklist**:
   - [ ] Code follows style guidelines
   - [ ] Tests added/updated
   - [ ] Documentation updated
   - [ ] No secrets in code
   - [ ] Docker build succeeds
   - [ ] Security scan passes

### PR Review Process

**develop → staging**:
- 1 approval required (QA lead)
- All CI checks must pass
- Integration tests validated

**staging → release**:
- 1 approval required (product owner)
- QA sign-off documented
- Smoke tests passed

**release → main**:
- 2 approvals required (tech lead + product owner)
- UAT sign-off documented
- Production readiness verified

---

## 🚀 Deployment Flow

### Automatic Deployments

```
feature/* → develop → CI/CD → Dev (CT179)
               ↓
           staging → CI/CD → QA (CT180)
```

### Manual Promotions

```
staging → release → Manual Deploy → UAT (CT181)
            ↓
         main → Manual Deploy → Production (CT182+)
                                  ↓
                           Blue-Green Deployment
                                  ↓
                           Health Check Validation
                                  ↓
                           Traffic Switch (if healthy)
```

### Environment URLs

- **Dev**: http://agl-hostman-dev.aglz.io
- **QA**: https://agl-hostman-qa.aglz.io
- **UAT**: https://agl-hostman-uat.aglz.io
- **Production**: https://agl-hostman.aglz.io

---

## 🔥 Hotfix Procedure

For **critical production issues** that can't wait for regular release cycle:

### Process

```bash
# 1. Create hotfix branch from main
git checkout main
git pull origin main
git checkout -b hotfix/URGENT-fix-critical-bug

# 2. Make minimal changes
git add .
git commit -m "hotfix: fix critical production bug"

# 3. Push and create PR to main
git push -u origin hotfix/URGENT-fix-critical-bug

# 4. After emergency approval (2 approvers), merge to main
# (triggers production deployment)

# 5. Back-merge to all branches
git checkout develop
git merge hotfix/URGENT-fix-critical-bug
git push origin develop

git checkout staging
git merge hotfix/URGENT-fix-critical-bug
git push origin staging

git checkout release
git merge hotfix/URGENT-fix-critical-bug
git push origin release

# 6. Delete hotfix branch
git branch -d hotfix/URGENT-fix-critical-bug
git push origin --delete hotfix/URGENT-fix-critical-bug
```

### Hotfix Approval Requirements

- **Severity**: P0/P1 issues only
- **Approvals**: 2 required (both tech lead + product owner)
- **Testing**: Must include immediate smoke tests
- **Communication**: Notify all stakeholders immediately
- **Post-Mortem**: Required within 24 hours

---

## 💻 Common Commands

### Setup

```bash
# Clone repository
git clone https://github.com/agl/agl-hostman.git
cd agl-hostman

# Track all remote branches
git fetch --all
git branch -a

# Checkout environment branches
git checkout develop
git checkout staging
git checkout release
git checkout main
```

### Daily Workflow

```bash
# Start new feature
git checkout develop
git pull origin develop
git checkout -b feature/ARCH-123-description

# Regular commits
git add .
git commit -m "feat: add feature description"

# Keep feature branch updated
git fetch origin
git rebase origin/develop

# Push changes
git push -u origin feature/ARCH-123-description
```

### Promotion Workflow

```bash
# Promote develop → staging
git checkout staging
git pull origin staging
git merge develop --no-ff
git push origin staging

# Promote staging → release
git checkout release
git pull origin release
git merge staging --no-ff
git push origin release

# Promote release → main (production)
git checkout main
git pull origin main
git merge release --no-ff
git tag -a v1.2.3 -m "Release v1.2.3: <description>"
git push origin main --tags
```

### Rollback

```bash
# Quick rollback in production
git checkout main
git revert HEAD
git push origin main

# Rollback to specific version
git checkout main
git reset --hard v1.2.2
git push origin main --force-with-lease
```

---

## 📊 Workflow Metrics (DORA)

### Target Metrics

| Metric | Current | 3 Months | 6 Months | 12 Months (Elite) |
|--------|---------|----------|----------|-------------------|
| **Deployment Frequency** | Weekly | Daily | Multiple/day | Multiple/day |
| **Lead Time** | 2-4 weeks | <7 days | <5 days | <3 days |
| **MTTR** | ~2 hours | <1 hour | <30 min | <15 min |
| **Change Failure Rate** | ~30% | <30% | <20% | <15% |

---

## 🔗 Related Documentation

- **CI/CD Workflows**: `.github/workflows/`
- **Deployment Guide**: `docs/DOKPLOY.md`
- **Infrastructure Map**: `docs/INFRA.md`
- **Archon Integration**: `docs/ARCHON.md`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-10-28
**Maintained By**: DevOps Team

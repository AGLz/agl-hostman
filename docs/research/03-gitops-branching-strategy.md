# GitOps Branching Strategy for Multi-Environment Workflows

> **Research Date**: 2025-10-28
> **Status**: GitOps Architecture Recommendations
> **Focus**: dev → qa → uat → main deployment pipeline

---

## Executive Summary

Modern GitOps workflows have evolved beyond traditional branching strategies. The industry consensus is clear: **branch-per-environment is an anti-pattern** for GitOps configuration management. Instead, **folder-based environment organization on a single main branch** provides superior reliability, traceability, and operational safety.

This document outlines the recommended GitOps strategy for the `agl-hostman` multi-environment deployment pipeline.

---

## The Anti-Pattern: Branch-Per-Environment

### ❌ What NOT to Do

**Traditional (but problematic) approach**:
```
Repository: agl-hostman-gitops
├── dev branch      (development configuration)
├── qa branch       (QA configuration)
├── uat branch      (UAT configuration)
└── main branch     (production configuration)
```

### Why This Fails

**Problem 1: Merge Conflicts and Configuration Drift**
```bash
# Scenario: Promoting QA to Production
git checkout main
git merge qa  # DANGER: Merges ALL changes, not just the image version

# What you want:
- Update image tag: v1.2.2 → v1.2.3

# What you get:
- Image tag change
- Replica count change (QA had 2, prod has 5)
- Resource limits (QA had lower limits)
- Environment variables (QA database URL)
- Configuration drift from other developers' changes
```

**Problem 2: Commit History Dependency**
- Merging requires linear commit history
- Cherry-picking specific changes is error-prone
- Conflicts arise from unrelated configuration changes
- Impossible to promote a specific version without its entire history

**Problem 3: Complexity Scales Exponentially**
```
Parameters to manage:
- Image tags (4 environments)
- Replica counts (different per env)
- Resource limits (CPU, memory)
- Environment variables (20+ per app)
- Storage volumes
- Network policies
- Ingress rules

With 4 environments and 50 configuration parameters:
= 200 potential merge conflict points
```

**Problem 4: Race Conditions**
```bash
# Two developers work simultaneously
Developer A: Updates QA replica count (commit abc123)
Developer B: Promotes image to staging (commit def456)

# When Developer B merges qa → staging:
# They unintentionally include Developer A's replica change
# Result: Unexpected configuration in staging
```

---

## The Recommended Pattern: Folder-Based Environments

### ✅ Modern GitOps Architecture

**Single Main Branch with Environment Folders**:
```
Repository: agl-hostman-gitops (single main branch)
├── envs/
│   ├── dev/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── configmap.yaml
│   │   └── version.yaml         # Image tag: dev-abc123
│   │
│   ├── qa/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── configmap.yaml
│   │   └── version.yaml         # Image tag: qa-v1.2.3
│   │
│   ├── uat/
│   │   ├── kustomization.yaml
│   │   ├── deployment.yaml
│   │   ├── configmap.yaml
│   │   └── version.yaml         # Image tag: uat-v1.2.3
│   │
│   └── prod/
│       ├── kustomization.yaml
│       ├── deployment.yaml
│       ├── configmap.yaml
│       └── version.yaml         # Image tag: v1.2.3
│
├── base/                         # Shared configuration
│   ├── deployment.yaml
│   ├── service.yaml
│   └── kustomization.yaml
│
└── README.md
```

### Key Principles

1. **All Environments in Single Branch**:
   - Every commit shows the state of ALL environments
   - No merge conflicts between environments
   - Clear audit trail of changes

2. **Promotion = File Copy**:
   - Promote by copying files, not merging branches
   - Commit history is irrelevant
   - Only changed files are affected

3. **Independent Environment Configuration**:
   - Each environment has complete configuration
   - Changes don't cascade unintentionally
   - Clear separation of concerns

---

## Promotion Workflow

### Manual Promotion (Simple & Reliable)

**Step 1: QA Promotion**
```bash
# After dev testing passes
# Simply copy the version file from dev to qa

cd agl-hostman-gitops

# Copy version specification
cp envs/dev/version.yaml envs/qa/version.yaml

# Optional: Update version tag for clarity
sed -i 's/dev-/qa-/' envs/qa/version.yaml

# Commit the promotion
git add envs/qa/version.yaml
git commit -m "promote: dev-abc123 → qa-v1.2.3

Promoted from dev environment after successful testing.
Changes:
- Updated image tag: dev-abc123 → qa-v1.2.3
- No other configuration changes

Testing notes:
- Unit tests: ✅ Passed
- Integration tests: ✅ Passed
- Developer sign-off: @developer
"

git push origin main
```

**Step 2: UAT Promotion**
```bash
# After QA validation
cp envs/qa/version.yaml envs/uat/version.yaml

# Update tag
sed -i 's/qa-/uat-/' envs/uat/version.yaml

git add envs/uat/version.yaml
git commit -m "promote: qa-v1.2.3 → uat-v1.2.3

Promoted from QA after validation.
QA sign-off: @qa-lead
Test results: https://qa-dashboard/tests/1234
"

git push origin main
```

**Step 3: Production Release**
```bash
# After UAT stakeholder approval
cp envs/uat/version.yaml envs/prod/version.yaml

# Production uses semantic versioning
sed -i 's/uat-v/v/' envs/prod/version.yaml

git add envs/prod/version.yaml
git commit -m "release: v1.2.3 to production

Promoted from UAT after stakeholder approval.

Approvals:
- UAT Lead: @uat-lead
- Product Owner: @product
- Security Review: @security

Release notes: https://docs/releases/v1.2.3
"

# Tag the release
git tag -a v1.2.3 -m "Release v1.2.3"

git push origin main --tags
```

### Automated Promotion (CI/CD Integration)

**GitHub Actions Workflow**:
```yaml
name: Promote to QA

on:
  workflow_dispatch:
    inputs:
      source_env:
        description: 'Source environment'
        required: true
        type: choice
        options:
          - dev
          - qa
          - uat
      target_env:
        description: 'Target environment'
        required: true
        type: choice
        options:
          - qa
          - uat
          - prod
      version:
        description: 'Version to promote (e.g., v1.2.3)'
        required: true
        type: string

jobs:
  promote:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout GitOps Repository
        uses: actions/checkout@v4
        with:
          repository: agl/agl-hostman-gitops
          token: ${{ secrets.GITOPS_TOKEN }}

      - name: Validate Promotion Path
        run: |
          # Ensure valid promotion order: dev → qa → uat → prod
          case "${{ inputs.source_env }}-${{ inputs.target_env }}" in
            "dev-qa"|"qa-uat"|"uat-prod")
              echo "✅ Valid promotion path"
              ;;
            *)
              echo "❌ Invalid promotion path"
              exit 1
              ;;
          esac

      - name: Copy Configuration
        run: |
          # Copy version file
          cp envs/${{ inputs.source_env }}/version.yaml \
             envs/${{ inputs.target_env }}/version.yaml

          # Update image tag
          sed -i "s|image:.*|image: harbor.aglz.io/agl-hostman-${{ inputs.target_env }}/hostman:${{ inputs.version }}|" \
             envs/${{ inputs.target_env }}/version.yaml

      - name: Create Pull Request
        uses: peter-evans/create-pull-request@v5
        with:
          commit-message: |
            promote: ${{ inputs.source_env }} → ${{ inputs.target_env }} (${{ inputs.version }})

            Automated promotion from ${{ inputs.source_env }} to ${{ inputs.target_env }}
            Version: ${{ inputs.version }}
            Triggered by: ${{ github.actor }}
          branch: promote-${{ inputs.target_env }}-${{ inputs.version }}
          title: "🚀 Promote ${{ inputs.version }} to ${{ inputs.target_env }}"
          body: |
            ## Promotion Details
            - **Source**: ${{ inputs.source_env }}
            - **Target**: ${{ inputs.target_env }}
            - **Version**: ${{ inputs.version }}
            - **Triggered by**: @${{ github.actor }}

            ## Checklist
            - [ ] Review configuration changes
            - [ ] Verify image version
            - [ ] Approval from ${{ inputs.target_env }} lead

            ## Auto-Deployment
            This PR will automatically deploy to ${{ inputs.target_env }} upon merge.
          labels: |
            promotion
            ${{ inputs.target_env }}

      - name: Notify Team
        if: success()
        run: |
          echo "✅ Promotion PR created for ${{ inputs.target_env }}"
          # Add Slack/Discord notification here
```

---

## Configuration Management with Kustomize

### Base Configuration (Shared)

**base/deployment.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agl-hostman
spec:
  replicas: 1  # Default, overridden per environment
  selector:
    matchLabels:
      app: agl-hostman
  template:
    metadata:
      labels:
        app: agl-hostman
    spec:
      containers:
      - name: hostman
        image: harbor.aglz.io/agl-hostman/hostman:latest  # Placeholder
        ports:
        - containerPort: 3000
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
```

**base/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml

commonLabels:
  app: agl-hostman
  managed-by: kustomize
```

### Environment Overlays

**envs/dev/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: dev

bases:
  - ../../base

patchesStrategicMerge:
  - deployment.yaml
  - version.yaml

configMapGenerator:
  - name: hostman-config
    literals:
      - ENVIRONMENT=development
      - LOG_LEVEL=debug
      - API_URL=https://api-dev.aglz.io

replicas:
  - name: agl-hostman
    count: 1
```

**envs/dev/version.yaml**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agl-hostman
spec:
  template:
    spec:
      containers:
      - name: hostman
        image: harbor.aglz.io/agl-hostman-dev/hostman:dev-abc123
```

**envs/qa/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: qa

bases:
  - ../../base

patchesStrategicMerge:
  - deployment.yaml
  - version.yaml

configMapGenerator:
  - name: hostman-config
    literals:
      - ENVIRONMENT=qa
      - LOG_LEVEL=info
      - API_URL=https://api-qa.aglz.io

replicas:
  - name: agl-hostman
    count: 2  # QA has more replicas for load testing
```

**envs/prod/kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: production

bases:
  - ../../base

patchesStrategicMerge:
  - deployment.yaml
  - version.yaml

configMapGenerator:
  - name: hostman-config
    literals:
      - ENVIRONMENT=production
      - LOG_LEVEL=warn
      - API_URL=https://api.aglz.io

replicas:
  - name: agl-hostman
    count: 3  # Production high availability

# Production-specific resources
resources:
  - hpa.yaml           # Horizontal Pod Autoscaler
  - pdb.yaml           # Pod Disruption Budget
  - network-policy.yaml
```

---

## Deployment with Dokploy (Docker-Based Alternative)

For non-Kubernetes environments (using Dokploy), the folder structure adapts:

**Repository Structure**:
```
agl-hostman-gitops/
├── envs/
│   ├── dev/
│   │   ├── docker-compose.yaml
│   │   ├── .env
│   │   └── version.txt         # Image tag reference
│   │
│   ├── qa/
│   │   ├── docker-compose.yaml
│   │   ├── .env
│   │   └── version.txt
│   │
│   ├── uat/
│   │   ├── docker-compose.yaml
│   │   ├── .env
│   │   └── version.txt
│   │
│   └── prod/
│       ├── docker-compose.yaml
│       ├── .env
│       └── version.txt
│
└── base/
    └── docker-compose.base.yaml
```

**envs/dev/docker-compose.yaml**:
```yaml
version: '3.8'

services:
  hostman:
    image: harbor.aglz.io/agl-hostman-dev/hostman:${VERSION}
    container_name: hostman-dev
    restart: unless-stopped

    environment:
      - NODE_ENV=development
      - LOG_LEVEL=debug
      - API_URL=https://api-dev.aglz.io

    ports:
      - "3001:3000"

    volumes:
      - ./data:/app/data

    networks:
      - hostman-dev

    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

networks:
  hostman-dev:
    driver: bridge
```

**envs/dev/.env**:
```bash
VERSION=dev-abc123
REPLICAS=1
CPU_LIMIT=1
MEMORY_LIMIT=512m
```

**envs/dev/version.txt**:
```
dev-abc123
```

**Promotion Script for Dokploy**:
```bash
#!/bin/bash
# promote.sh - Promote between Dokploy environments

SOURCE_ENV=$1
TARGET_ENV=$2
VERSION=$3

if [ -z "$VERSION" ]; then
  # Extract version from source environment
  VERSION=$(cat envs/$SOURCE_ENV/version.txt)
fi

# Update version in target environment
echo "$VERSION" > envs/$TARGET_ENV/version.txt

# Update docker-compose .env file
sed -i "s/VERSION=.*/VERSION=$VERSION/" envs/$TARGET_ENV/.env

# Commit changes
git add envs/$TARGET_ENV/
git commit -m "promote: $SOURCE_ENV → $TARGET_ENV ($VERSION)"
git push origin main

# Trigger Dokploy deployment via API
curl -X POST "https://dokploy.aglz.io/api/deploy" \
  -H "Authorization: Bearer $DOKPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"environment\": \"$TARGET_ENV\",
    \"version\": \"$VERSION\"
  }"

echo "✅ Promoted $VERSION from $SOURCE_ENV to $TARGET_ENV"
```

**Usage**:
```bash
# Promote dev to QA
./promote.sh dev qa

# Promote QA to UAT with specific version
./promote.sh qa uat v1.2.3

# Promote UAT to production
./promote.sh uat prod v1.2.3
```

---

## Policy-Based Automated Promotion

### Automatic Promotion Triggers

**envs/promotion-policy.yaml**:
```yaml
promotion_policies:
  - name: "Auto-promote Dev to QA"
    source: dev
    target: qa

    conditions:
      - type: "tests_passed"
        required: true
      - type: "security_scan"
        severity: "HIGH"
        block: true
      - type: "developer_approval"
        count: 1

    actions:
      - copy_version: true
      - create_pr: true
      - notify: ["qa-team-slack-channel"]

  - name: "Auto-promote QA to UAT"
    source: qa
    target: uat

    conditions:
      - type: "qa_tests_passed"
        required: true
      - type: "soak_test"
        duration: "24h"
      - type: "qa_lead_approval"
        required: true

    actions:
      - copy_version: true
      - create_pr: true
      - notify: ["uat-stakeholders"]

  - name: "Manual Promotion to Production"
    source: uat
    target: prod

    conditions:
      - type: "manual_trigger_only"
      - type: "multi_approval"
        approvers: ["product-owner", "security-team", "ops-lead"]
      - type: "change_window"
        schedule: "tue-thu 10:00-16:00"

    actions:
      - copy_version: true
      - create_pr: true
      - require_manual_merge: true
      - create_git_tag: true
      - notify: ["all-teams"]
```

### GitHub Action for Policy Enforcement

```yaml
name: Enforce Promotion Policy

on:
  pull_request:
    branches: [main]
    paths:
      - 'envs/**/version.yaml'

jobs:
  validate-promotion:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Detect Environment Change
        id: detect
        run: |
          # Detect which environment is being updated
          CHANGED_FILES=$(git diff --name-only ${{ github.event.pull_request.base.sha }} ${{ github.sha }})

          if echo "$CHANGED_FILES" | grep -q "envs/qa/"; then
            echo "target=qa" >> $GITHUB_OUTPUT
          elif echo "$CHANGED_FILES" | grep -q "envs/uat/"; then
            echo "target=uat" >> $GITHUB_OUTPUT
          elif echo "$CHANGED_FILES" | grep -q "envs/prod/"; then
            echo "target=prod" >> $GITHUB_OUTPUT
          fi

      - name: Check Tests
        if: steps.detect.outputs.target == 'qa'
        run: |
          # Verify all tests passed in source environment
          # Query CI system for test results
          echo "✅ All tests passed"

      - name: Check Security Scan
        if: steps.detect.outputs.target == 'qa'
        run: |
          # Query Harbor API for vulnerability scan results
          curl -u "${{ secrets.HARBOR_USER }}:${{ secrets.HARBOR_TOKEN }}" \
            "https://harbor.aglz.io/api/v2.0/projects/agl-hostman-dev/repositories/hostman/artifacts/dev-abc123/scan_overview"

      - name: Require Approvals
        if: steps.detect.outputs.target == 'prod'
        run: |
          # Enforce required approvals for production
          REQUIRED_APPROVERS=("product-owner" "security-team" "ops-lead")
          # Check GitHub API for approvals
          echo "✅ All required approvals obtained"

      - name: Check Change Window
        if: steps.detect.outputs.target == 'prod'
        run: |
          # Verify deployment is within allowed change window
          DAY=$(date +%a)
          HOUR=$(date +%H)

          if [[ "$DAY" =~ ^(Tue|Wed|Thu)$ ]] && [ "$HOUR" -ge 10 ] && [ "$HOUR" -le 16 ]; then
            echo "✅ Within change window"
          else
            echo "❌ Outside change window (Tue-Thu 10:00-16:00)"
            exit 1
          fi
```

---

## Rollback Strategy

### Quick Rollback (Revert Commit)

```bash
# Rollback production to previous version
cd agl-hostman-gitops

# Find the last good version commit
git log --oneline envs/prod/version.yaml

# Example output:
# abc1234 release: v1.2.3 to production
# def5678 release: v1.2.2 to production  ← Rollback to this

# Revert to previous version
git revert abc1234 --no-commit
git commit -m "rollback: production from v1.2.3 to v1.2.2

Incident: API errors in production (INC-12345)
Severity: P1
Rolled back by: @oncall-engineer

Previous version v1.2.2 confirmed stable.
Root cause analysis: https://docs/incidents/INC-12345
"

git push origin main

# GitOps controller (ArgoCD/Flux) will automatically apply the rollback
```

### Emergency Rollback (Skip GitOps)

```bash
# For critical production incidents, bypass GitOps temporarily

# Direct deployment to Dokploy
curl -X POST "https://dokploy.aglz.io/api/deploy" \
  -H "Authorization: Bearer $DOKPLOY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "environment": "prod",
    "image": "harbor.aglz.io/agl-hostman-prod/hostman:v1.2.2",
    "bypass_gitops": true,
    "incident_id": "INC-12345"
  }'

# IMPORTANT: Update GitOps repo afterward to match reality
git checkout main
echo "v1.2.2" > envs/prod/version.txt
git commit -m "docs: update prod version after emergency rollback"
git push origin main
```

---

## Monitoring & Observability

### Drift Detection

**Compare Desired State (Git) vs. Actual State (Deployment)**:

```bash
#!/bin/bash
# check-drift.sh - Detect configuration drift

ENVIRONMENT=$1

# Get desired version from Git
DESIRED_VERSION=$(cat envs/$ENVIRONMENT/version.txt)

# Get actual deployed version from Dokploy API
ACTUAL_VERSION=$(curl -s "https://dokploy.aglz.io/api/status?env=$ENVIRONMENT" \
  | jq -r '.image' \
  | cut -d: -f2)

if [ "$DESIRED_VERSION" != "$ACTUAL_VERSION" ]; then
  echo "⚠️  Configuration drift detected in $ENVIRONMENT"
  echo "Desired: $DESIRED_VERSION"
  echo "Actual: $ACTUAL_VERSION"

  # Alert ops team
  # Send Slack notification
  # Create incident ticket

  exit 1
else
  echo "✅ $ENVIRONMENT in sync"
fi
```

### Audit Trail

**Track all environment changes**:
```bash
# View promotion history
git log --oneline --grep="promote:" envs/prod/

# View all production releases
git log --oneline --all --decorate --graph envs/prod/version.yaml

# Find who deployed what and when
git log --pretty=format:"%h %an %ad %s" --date=short envs/prod/

# Example output:
# abc1234 ops-lead 2025-10-28 release: v1.2.3 to production
# def5678 ops-lead 2025-10-21 release: v1.2.2 to production
# ghi9012 ops-lead 2025-10-14 release: v1.2.1 to production
```

---

## Best Practices Summary

### ✅ DO

1. **Use Folder-Based Environments**
   - Single main branch
   - All environments visible in one place
   - File copy for promotions

2. **Immutable Versions**
   - Semantic versioning (v1.2.3)
   - Include git SHA for traceability
   - Never reuse tags

3. **Clear Commit Messages**
   - Use conventional commits format
   - Include promotion details
   - Reference tickets/approvals

4. **Automated Testing**
   - Validate changes before merge
   - Check policy compliance
   - Verify configuration syntax

5. **Audit Everything**
   - Track all promotions
   - Require approvals
   - Maintain change log

### ❌ DON'T

1. **Avoid Branches for Environments**
   - No dev/qa/uat/prod branches
   - Merge conflicts and drift guaranteed
   - Hard to reason about state

2. **Don't Skip Environments**
   - Always follow dev → qa → uat → prod
   - No direct dev → prod promotions
   - Exception: Security hotfixes

3. **No Manual Changes**
   - Never edit deployed configs directly
   - All changes through Git
   - If manual change needed, sync Git immediately

4. **Don't Use Latest Tags**
   - Avoid :latest in any environment
   - Especially critical in production
   - Use immutable version tags

5. **No Shared Secrets in Git**
   - Use external secret managers
   - Reference secrets, don't embed
   - Rotate secrets regularly

---

## Comparison: Branch-Based vs Folder-Based

| Aspect | Branch-Based | Folder-Based | Winner |
|--------|-------------|--------------|--------|
| **Promotion Method** | Git merge | File copy | 🏆 Folder |
| **Merge Conflicts** | Common | Rare | 🏆 Folder |
| **Configuration Drift** | High risk | Low risk | 🏆 Folder |
| **Commit History** | Matters | Irrelevant | 🏆 Folder |
| **Visibility** | One branch at a time | All environments visible | 🏆 Folder |
| **Audit Trail** | Complex | Simple | 🏆 Folder |
| **Learning Curve** | Steep | Gentle | 🏆 Folder |
| **Rollback** | Revert merge (complex) | Revert file copy (simple) | 🏆 Folder |
| **CI/CD Integration** | Complex | Straightforward | 🏆 Folder |
| **Industry Adoption** | Legacy | Modern standard | 🏆 Folder |

**Verdict**: Folder-based wins in all categories.

---

## Conclusion

### 🎯 Recommended Strategy for agl-hostman

**Adopt folder-based GitOps with single main branch**:

```
agl-hostman-gitops/
├── envs/
│   ├── dev/        (automatic deployment on merge to dev branch)
│   ├── qa/         (manual promotion with PR approval)
│   ├── uat/        (manual promotion with stakeholder approval)
│   └── prod/       (manual promotion with multi-approval + change window)
├── base/           (shared Kustomize base or docker-compose templates)
└── scripts/        (promotion automation scripts)
```

**Benefits for agl-hostman project**:
1. ✅ Simple and reliable promotions
2. ✅ No merge conflicts
3. ✅ Clear audit trail
4. ✅ Easy rollbacks
5. ✅ Compatible with Dokploy and Kubernetes
6. ✅ Industry best practice

**Implementation Timeline**:
- Week 1: Create folder structure
- Week 2: Implement promotion scripts
- Week 3: Set up CI/CD automation
- Week 4: Team training and documentation

---

**Research Completed**: 2025-10-28
**Researcher**: Hive Mind Research Agent
**Next Document**: Dashboard Framework Recommendations

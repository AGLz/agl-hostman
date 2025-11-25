# Promotion Workflows Guide

> **Phase**: 3.4 - Environment Promotion Automation
> **Version**: 1.0.0
> **Last Updated**: 2025-11-20

---

## Overview

This guide documents the automated promotion workflows between environments:
- **dev → qa**: Automatic (on develop branch push)
- **qa → uat**: Manual (1 approval required)
- **uat → production**: Manual (2 approvals required - lead-developer + admin)

---

## Workflow Diagrams

### Workflow 1: dev → qa (Automatic)

```
┌─────────────┐
│   GitHub    │
│ Push Event  │
│  (develop)  │
└──────┬──────┘
       │
       ▼
┌──────────────────┐
│ GitHub Webhook   │
│ Signature Check  │
└──────┬───────────┘
       │
       ▼
┌──────────────────────┐
│ Create Promotion     │
│ status: deploying    │
│ is_automatic: true   │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│ Deploy to QA         │
│ Run CI/CD Pipeline   │
└──────┬───────────────┘
       │
       ├─ Success ──┐
       │            ▼
       │     ┌──────────────────┐
       │     │ Run Integration  │
       │     │ Tests            │
       │     └────┬──────────────┘
       │          │
       │          ├─ Pass ──┐
       │          │         ▼
       │          │   ┌──────────────┐
       │          │   │ Complete     │
       │          │   │ Notify Team  │
       │          │   └──────────────┘
       │          │
       │          └─ Fail ──┐
       │                    ▼
       └─ Failure ────> ┌─────────────┐
                        │ Auto-Rollback│
                        │ Notify Team   │
                        └──────────────┘
```

### Workflow 2: qa → uat (1 Approval)

```
┌─────────────────┐
│ Request         │
│ Promotion       │
│ (API/CLI)       │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Check QA Stability  │
│ (24h uptime min)    │
└────────┬────────────┘
         │
         ├─ Eligible ──┐
         │             ▼
         │        ┌──────────────────┐
         │        │ Create Promotion │
         │        │ status: pending  │
         │        │ requires: 1      │
         │        └────────┬─────────┘
         │                 │
         │                 ▼
         │        ┌──────────────────┐
         │        │ Request Approval │
         │        │ (lead-dev/admin) │
         │        └────────┬─────────┘
         │                 │
         │                 ▼
         │        ┌──────────────────┐
         │        │ Wait for         │
         │        │ Approval (24h)   │
         │        └────┬─────────────┘
         │             │
         │             ├─ Approved ──┐
         │             │             ▼
         │             │      ┌──────────────┐
         │             │      │ Deploy to UAT│
         │             │      │ Smoke Tests  │
         │             │      └──────────────┘
         │             │
         │             └─ Rejected/Expired ──┐
         │                                   ▼
         └─ Not Eligible ─────────────> ┌─────────────┐
                                         │ Cancel      │
                                         │ Notify      │
                                         └─────────────┘
```

### Workflow 3: uat → production (2 Approvals)

```
┌─────────────────┐
│ Request         │
│ Production      │
│ Promotion       │
└────────┬────────┘
         │
         ▼
┌─────────────────────┐
│ Check UAT Stability │
│ (72h uptime min)    │
└────────┬────────────┘
         │
         ├─ Eligible ──┐
         │             ▼
         │        ┌────────────────────┐
         │        │ Create Promotion   │
         │        │ status: pending    │
         │        │ requires: 2        │
         │        └────────┬───────────┘
         │                 │
         │                 ▼
         │        ┌─────────────────────┐
         │        │ Request Approvals   │
         │        │ (lead-dev + admin)  │
         │        └────────┬────────────┘
         │                 │
         │                 ▼
         │        ┌─────────────────────┐
         │        │ Collect Approvals   │
         │        │ (24h deadline)      │
         │        └────┬────────────────┘
         │             │
         │             ├─ 1st Approval ──┐
         │             │                 ▼
         │             │         ┌────────────────┐
         │             │         │ Wait for 2nd   │
         │             │         │ Approval       │
         │             │         └────┬───────────┘
         │             │              │
         │             └─ 2nd Approval ──┐
         │                               ▼
         │                      ┌─────────────────────┐
         │                      │ Blue-Green Deploy   │
         │                      │ Traffic: 10%        │
         │                      └─────────┬───────────┘
         │                                │
         │                                ▼
         │                      ┌─────────────────────┐
         │                      │ Monitor 15min       │
         │                      │ Traffic: 50%        │
         │                      └─────────┬───────────┘
         │                                │
         │                                ▼
         │                      ┌─────────────────────┐
         │                      │ Monitor 30min       │
         │                      │ Traffic: 100%       │
         │                      └─────────┬───────────┘
         │                                │
         │                                ├─ Success ──┐
         │                                │            ▼
         │                                │      ┌──────────┐
         │                                │      │ Complete │
         │                                │      │ Notify   │
         │                                │      └──────────┘
         │                                │
         │                                └─ Failure ──┐
         │                                             ▼
         └─ Rejected/Expired ──────────────> ┌──────────────┐
                                              │ Auto-Rollback│
                                              │ Alert Team   │
                                              └──────────────┘
```

---

## API Endpoints

### Promotion Actions

```http
POST /api/promotion/qa-to-uat
Content-Type: application/json
Authorization: Bearer {token}

{
  "version": "v1.2.3"
}
```

```http
POST /api/promotion/uat-to-production
Content-Type: application/json
Authorization: Bearer {token}

{
  "version": "v1.2.3"
}
```

### Approval Actions

```http
POST /api/promotion/{id}/approve
Content-Type: application/json
Authorization: Bearer {token}

{
  "notes": "Approved after review"
}
```

```http
POST /api/promotion/{id}/reject
Content-Type: application/json
Authorization: Bearer {token}

{
  "reason": "Failed integration tests"
}
```

### Dashboard Endpoints

```http
GET /api/promotion/pipeline
GET /api/promotion/metrics
GET /api/promotion/active
GET /api/promotion/history?days=30
GET /api/promotion/{id}/approvals
GET /api/promotion/pending-approvals
```

---

## CLI Commands

### Request Promotion

```bash
# QA → UAT
php artisan deployment:promote qa uat --version=v1.2.3 --requester=john@agl.com

# UAT → Production
php artisan deployment:promote uat production --version=v1.2.3 --requester=admin@agl.com
```

### Approve Promotion

```bash
php artisan deployment:approve {promotionId} \
  --approver=lead-developer@agl.com \
  --notes="Approved after testing"
```

### Rollback

```bash
php artisan deployment:rollback {promotionId}
```

### Check Status

```bash
php artisan deployment:status
```

---

## Notification Channels

### Slack

Promotions send notifications to Slack with color-coded messages:
- 🚀 **Blue**: Promotion requested
- ✅ **Green**: Approved/Completed
- ⚙️ **Gray**: Deploying
- ❌ **Red**: Failed
- 🔄 **Yellow**: Rollback initiated

### Discord

Similar to Slack with Discord webhooks.

### Email

Email notifications sent to configured recipients for:
- Approval requests
- Promotion completed
- Promotion failed
- Rollback alerts

---

## Best Practices

### 1. Version Naming

Use semantic versioning:
```
v{MAJOR}.{MINOR}.{PATCH}
Example: v1.2.3
```

### 2. Approval Notes

Always provide context:
```
"Approved after successful UAT testing by QA team"
"All regression tests passed"
"Stakeholder sign-off received"
```

### 3. Rejection Reasons

Be specific:
```
"Integration tests failing - user authentication broken"
"Performance regression detected - load time increased 50%"
"Security vulnerability found in dependency"
```

### 4. Monitoring After Deployment

- **QA**: Monitor for 24 hours before promoting to UAT
- **UAT**: Monitor for 72 hours before promoting to production
- **Production**: Monitor for 1 hour after each traffic increase (10% → 50% → 100%)

---

## Troubleshooting

### Promotion Stuck in Pending

```bash
# Check approval status
php artisan deployment:status

# Check who needs to approve
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/{id}/approvals
```

### Automatic Rollback Not Working

1. Check deployment logs
2. Verify rollback configuration
3. Test rollback manually
4. Check notification delivery

### GitHub Webhook Not Triggering

1. Verify webhook signature secret
2. Check webhook URL is accessible
3. Review GitHub webhook delivery logs
4. Test webhook manually

---

## Configuration

See `.env.example` for all configuration options:
- `PROMOTION_AUTO_DEV_TO_QA`
- `PROMOTION_QA_TO_UAT_APPROVALS`
- `PROMOTION_UAT_TO_PROD_APPROVALS`
- `PROMOTION_APPROVAL_TIMEOUT_HOURS`
- `PROMOTION_QA_STABILITY_HOURS`
- `PROMOTION_UAT_STABILITY_HOURS`

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Phase**: 3.4 - Environment Promotion Automation

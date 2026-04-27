# Promotion Approval Process Guide

> **Version**: 1.0.0
> **Last Updated**: 2025-11-20

---

## Overview

This guide details the approval process for environment promotions, including approval chains, notification workflows, and best practices.

---

## Approval Chain

### QA → UAT (1 Approval)

**Approvers**: Lead-Developer OR Admin
**Deadline**: 24 hours
**Process**:

1. Developer requests promotion
2. System creates approval request
3. Notification sent to all qualified approvers
4. First to approve triggers deployment
5. Rejected/expired cancels promotion

### UAT → Production (2 Approvals)

**Approvers**: Lead-Developer AND Admin (both required)
**Deadline**: 24 hours
**Process**:

1. Admin/Lead requests production promotion
2. System creates approval request
3. Notifications sent to both approvers
4. Collect 1st approval
5. Wait for 2nd approval
6. Once both approved, deployment triggers
7. Any rejection cancels promotion

---

## Approval Roles

### Lead-Developer

**Permissions**:
- Approve QA → UAT
- Approve UAT → Production (1st approval)
- Request all promotions
- Reject promotions

**Responsibilities**:
- Technical review
- Code quality verification
- Test coverage validation
- Risk assessment

### Admin

**Permissions**:
- Approve QA → UAT
- Approve UAT → Production (2nd approval)
- Request all promotions
- Reject promotions
- Emergency rollback

**Responsibilities**:
- Business approval
- Stakeholder sign-off
- Compliance verification
- Final authorization

---

## Notification Workflow

### Approval Request Email

```
Subject: Production Promotion Approval Required: v1.2.3

Hi [Approver Name],

A promotion to [target environment] requires your approval:

Version: v1.2.3
Source: [source environment]
Target: [target environment]
Requested by: [requester email]
Requested at: [timestamp]
Deadline: [24h from now]

[Approve Button] [Reject Button] [View Details]

To approve via CLI:
php artisan deployment:approve [promotion-id] --approver=[your-email]

To approve via API:
POST /api/promotion/[promotion-id]/approve
Authorization: Bearer [your-token]

This request expires in 24 hours.

---
AGL Deployment System
```

### Slack Notification

```
🚀 Promotion Approval Required

Environment: qa → uat
Version: v1.2.3
Requested by: john@agl.com

Remaining Approvals: 1/1

[Approve] [Reject] [View Details]

Expires: 24h
```

---

## Approval Process

### Via API

```bash
# Approve
curl -X POST https://api.agl.com/promotion/{id}/approve \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "notes": "Approved after successful testing"
  }'

# Reject
curl -X POST https://api.agl.com/promotion/{id}/reject \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Integration tests failing"
  }'
```

### Via CLI

```bash
# Approve
php artisan deployment:approve abc123def456 \
  --approver=lead-developer@agl.com \
  --notes="Approved after code review"

# Check pending approvals
php artisan deployment:status
```

### Via Dashboard

1. Navigate to Promotions Dashboard
2. View "Pending Approvals" section
3. Click "Review" on promotion
4. Review changes, tests, metrics
5. Click "Approve" or "Reject"
6. Enter notes/reason
7. Submit

---

## Best Practices

### Approval Notes

**Good Examples**:
```
"Approved after successful UAT testing by QA team"
"All regression tests passed, performance metrics within acceptable range"
"Stakeholder sign-off received via email on 2025-11-20"
"Emergency fix approved by CTO for critical security patch"
```

**Bad Examples**:
```
"OK"
"Approved"
"Looks good"
```

### Rejection Reasons

**Good Examples**:
```
"Integration tests failing - user authentication broken in login flow"
"Performance regression detected - API response time increased 50% (500ms → 750ms)"
"Security vulnerability found in dependency axios@1.2.3 (CVE-2025-12345)"
"Database migration missing - contacts table not created"
```

**Bad Examples**:
```
"Tests failed"
"Not ready"
"Issues found"
```

---

## Approval Metrics

### Tracking

```sql
-- Average approval time
SELECT 
  AVG(EXTRACT(EPOCH FROM (approved_at - requested_at))) / 3600 as avg_hours
FROM production_approvals
WHERE status = 'approved';

-- Approval rate by approver
SELECT 
  u.name,
  COUNT(*) FILTER (WHERE pa.status = 'approved') as approved,
  COUNT(*) FILTER (WHERE pa.status = 'rejected') as rejected,
  COUNT(*) FILTER (WHERE pa.status = 'expired') as expired
FROM production_approvals pa
JOIN users u ON pa.approver_id = u.id
GROUP BY u.name;
```

### Target Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Average approval time | <4 hours | During business hours |
| Approval rate | >90% | Approved vs total requests |
| Expiration rate | <5% | Expired approvals |
| Rejection rate | <10% | Rejected approvals |

---

## Troubleshooting

### Approval Not Received

**Symptoms**: Approver not notified
**Checks**:
1. Verify approver has correct role
2. Check email/Slack configuration
3. Review notification logs
4. Test notification channels

**Solution**:
```bash
# Test notifications
php artisan tinker
$service = app(\App\Services\Notification\NotificationService::class);
$service->testChannel('slack');
$service->testChannel('email');
```

### Approval Stuck

**Symptoms**: Promotion not progressing after approval
**Checks**:
1. Verify all required approvals received
2. Check approval status
3. Review deployment logs

**Solution**:
```bash
# Check approval status
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/{id}/approvals

# Manually trigger if needed
php artisan deployment:execute {promotionId}
```

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Phase**: 3.4 - Environment Promotion Automation

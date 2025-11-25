# Promotion Troubleshooting Guide

> **Version**: 1.0.0
> **Last Updated**: 2025-11-20

---

## Common Issues

### 1. Auto-Promotion Not Triggering

**Symptoms**:
- Push to develop branch
- No promotion created
- No notification received

**Diagnosis**:
```bash
# Check GitHub webhook deliveries
# Go to: GitHub → Settings → Webhooks → Recent Deliveries

# Check webhook logs
tail -f storage/logs/laravel.log | grep webhook

# Test webhook manually
curl -X POST https://api.agl.com/webhooks/github/push \
  -H "X-Hub-Signature-256: sha256=..." \
  -H "Content-Type: application/json" \
  -d '{"ref":"refs/heads/develop","after":"abc123"}'
```

**Solutions**:

1. **Verify Webhook Secret**:
```bash
# In .env
GITHUB_WEBHOOK_SECRET=your-secret-here

# In GitHub webhook settings
Secret: [same secret]
```

2. **Check Webhook URL**:
```
URL should be: https://api.agl.com/webhooks/github/push
NOT: https://api.agl.com/api/webhooks/github/push
```

3. **Verify Branch Name**:
```php
// In webhook payload
"ref": "refs/heads/develop"  // Correct
"ref": "develop"              // Incorrect
```

---

### 2. Promotion Stuck in Pending Approval

**Symptoms**:
- Promotion created
- No approvals received
- Deadline approaching

**Diagnosis**:
```bash
# Check approval status
php artisan deployment:status

# Get approval details
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/{id}/approvals

# Check who needs to approve
php artisan tinker
$promotion = Promotion::find('{id}');
$promotion->approvals;
```

**Solutions**:

1. **Verify Approver Roles**:
```bash
php artisan tinker

# Check if user has correct role
$user = User::where('email', 'approver@agl.com')->first();
$user->getRoleNames(); // Should include 'lead-developer' or 'admin'

# Assign role if missing
$user->assignRole('lead-developer');
```

2. **Check Notification Delivery**:
```bash
# Test Slack
php artisan tinker
$service = app(\App\Services\Notification\NotificationService::class);
$service->testChannel('slack');

# Check email queue
php artisan queue:work --once
```

3. **Manual Approval**:
```bash
php artisan deployment:approve {promotionId} \
  --approver=lead-developer@agl.com \
  --notes="Manual approval after notification issue"
```

---

### 3. Rollback Not Working

**Symptoms**:
- Promotion failed
- Rollback not triggered
- Old version still deployed

**Diagnosis**:
```bash
# Check promotion status
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/{id}/approvals

# Check rollback logs
tail -f storage/logs/laravel.log | grep rollback

# Verify environment status
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/environments/{id}
```

**Solutions**:

1. **Manual Rollback**:
```bash
php artisan deployment:rollback {promotionId}
```

2. **Verify Backup Exists**:
```bash
# Check deployment service has backup
php artisan tinker
$env = Environment::find('{id}');
$env->deployments()->latest()->first();
```

3. **Emergency Rollback**:
```bash
# Direct environment rollback
php artisan deployment:rollback-environment {environmentId} \
  --version=v1.2.2
```

---

### 4. Notifications Not Sending

**Symptoms**:
- Promotions working
- No Slack/Discord/Email notifications
- Silent failures

**Diagnosis**:
```bash
# Check configuration
php artisan config:show alerts

# Test each channel
php artisan tinker
$service = app(\App\Services\Notification\NotificationService::class);
$service->testChannel('slack');   // Check response
$service->testChannel('discord'); // Check response
$service->testChannel('email');   // Check response

# Check logs
tail -f storage/logs/laravel.log | grep notification
```

**Solutions**:

1. **Slack Issues**:
```bash
# Verify webhook URL
ALERTS_SLACK_ENABLED=true
ALERTS_SLACK_WEBHOOK_URL=https://hooks.slack.com/services/T00/B00/xxx

# Test webhook manually
curl -X POST https://hooks.slack.com/services/T00/B00/xxx \
  -H "Content-Type: application/json" \
  -d '{"text":"Test from AGL"}'

# Common issues:
# - Webhook URL expired/revoked
# - Slack app not installed
# - Channel permissions wrong
```

2. **Discord Issues**:
```bash
# Verify webhook URL
ALERTS_DISCORD_ENABLED=true
ALERTS_DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxx/yyy

# Test webhook manually
curl -X POST https://discord.com/api/webhooks/xxx/yyy \
  -H "Content-Type: application/json" \
  -d '{"content":"Test from AGL"}'

# Common issues:
# - Webhook deleted
# - Bot permissions insufficient
# - Rate limited
```

3. **Email Issues**:
```bash
# Check mail configuration
php artisan config:show mail

# Test email sending
php artisan tinker
Mail::raw('Test email', function($msg) {
    $msg->to('admin@agl.com')->subject('Test');
});

# Check queue
php artisan queue:work --once

# Common issues:
# - SMTP credentials wrong
# - Port blocked (25, 587, 465)
# - Recipients list empty
```

---

### 5. Approval Timeout Issues

**Symptoms**:
- Approvals expiring before review
- 24h deadline too short
- Approvers in different timezones

**Solutions**:

1. **Extend Approval Timeout**:
```bash
# In .env
PROMOTION_APPROVAL_TIMEOUT_HOURS=48  # Increase to 48h
```

2. **Manual Extension**:
```bash
php artisan tinker

$promotion = Promotion::find('{id}');
$promotion->update(['approval_deadline' => now()->addHours(24)]);
```

3. **Cancel Expired and Recreate**:
```bash
# Cancel expired
php artisan tinker
$promotion = Promotion::find('{id}');
$promotion->update(['status' => 'cancelled']);

# Create new request
php artisan deployment:promote qa uat --version=v1.2.3
```

---

### 6. Eligibility Check Failing

**Symptoms**:
- Promotion request rejected
- "Not eligible" error
- Stability hours not met

**Diagnosis**:
```bash
# Check eligibility
php artisan tinker
$service = app(\App\Services\Deployment\PromotionWorkflowService::class);
$result = $service->checkPromotionEligibility('qa', 'uat');
print_r($result);
```

**Solutions**:

1. **Uptime Not Met**:
```bash
# Check last deployment time
$env = Environment::where('type', 'qa')->first();
$lastDeploy = $env->deployments()->where('status', 'completed')->latest()->first();
$hoursSince = $lastDeploy->completed_at->diffInHours(now());

echo "Hours since deploy: {$hoursSince}";
echo "Required: 24 (for QA→UAT) or 72 (for UAT→Prod)";

# Solution: Wait longer or override (emergency only)
PROMOTION_QA_STABILITY_HOURS=1  # Temporary override
```

2. **Critical Alerts Present**:
```bash
# Check alerts
$env = Environment::where('type', 'qa')->first();
$criticalAlerts = $env->alerts()
    ->where('severity', 'critical')
    ->where('created_at', '>', now()->subHours(24))
    ->get();

echo "Critical alerts: " . $criticalAlerts->count();

# Solution: Resolve alerts first
```

3. **Pending Deployments**:
```bash
# Check pending deployments
$env = Environment::where('type', 'qa')->first();
$pending = $env->deployments()
    ->whereIn('status', ['pending', 'deploying'])
    ->get();

echo "Pending deployments: " . $pending->count();

# Solution: Wait for deployments to complete
```

---

## Diagnostic Commands

### Check System Health

```bash
# Overall promotion pipeline
php artisan deployment:status

# Active promotions
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/active

# Promotion metrics
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/metrics

# Pending approvals
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/promotion/pending-approvals
```

### Check Logs

```bash
# Promotion logs
tail -f storage/logs/laravel.log | grep -i promotion

# Webhook logs
tail -f storage/logs/laravel.log | grep -i webhook

# Notification logs
tail -f storage/logs/laravel.log | grep -i notification

# Deployment logs
tail -f storage/logs/laravel.log | grep -i deploy

# Error logs only
tail -f storage/logs/laravel.log | grep -i error
```

### Database Queries

```sql
-- Recent promotions
SELECT 
  id, 
  source_version, 
  status, 
  created_at,
  requires_approvals,
  (SELECT COUNT(*) FROM production_approvals WHERE promotion_id = promotions.id AND status = 'approved') as approved_count
FROM promotions
ORDER BY created_at DESC
LIMIT 10;

-- Pending approvals
SELECT 
  p.id as promotion_id,
  p.source_version,
  u.name as approver,
  pa.status,
  pa.expires_at
FROM production_approvals pa
JOIN promotions p ON pa.promotion_id = p.id
JOIN users u ON pa.approver_id = u.id
WHERE pa.status = 'pending'
ORDER BY pa.expires_at;

-- Failed promotions (last 7 days)
SELECT 
  id,
  source_version,
  status,
  rollback_reason,
  created_at
FROM promotions
WHERE status IN ('failed', 'rolled_back')
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;
```

---

## Emergency Procedures

### Force Approve Production Deployment

**⚠️ WARNING**: Only use in emergencies (critical security patches, etc.)

```bash
# 1. Create emergency promotion
php artisan deployment:promote uat production \
  --version=v1.2.3 \
  --requester=emergency@agl.com

# 2. Get promotion ID from output
PROMOTION_ID=abc123def456

# 3. Force approve with both required approvals
php artisan deployment:approve $PROMOTION_ID \
  --approver=lead-developer@agl.com \
  --notes="EMERGENCY: Critical security patch CVE-2025-12345"

php artisan deployment:approve $PROMOTION_ID \
  --approver=admin@agl.com \
  --notes="EMERGENCY: Approved by CTO for immediate deployment"

# 4. Monitor deployment
watch -n 2 'php artisan deployment:status'
```

### Emergency Rollback

```bash
# 1. Find promotion ID
php artisan deployment:status

# 2. Immediate rollback
php artisan deployment:rollback {promotionId}

# 3. Verify rollback
curl -H "Authorization: Bearer {token}" \
  https://api.agl.com/environments/production

# 4. Notify team
# Manual notification if automated fails
```

---

## Prevention

### Best Practices

1. **Test in Lower Environments First**
   - Always test QA before UAT
   - Always test UAT before Production
   - Never skip environments

2. **Monitor Stability**
   - Check logs before promoting
   - Review metrics before promoting
   - Verify no alerts before promoting

3. **Clear Approval Notes**
   - Document what was tested
   - Include test results
   - Reference ticket/issue numbers

4. **Communication**
   - Notify team before production deployments
   - Schedule production deployments during low-traffic hours
   - Have rollback plan ready

---

**Document Version**: 1.0.0
**Last Updated**: 2025-11-20
**Phase**: 3.4 - Environment Promotion Automation

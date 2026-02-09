# Webhooks Documentation

## Overview

The AGL Infrastructure API supports incoming webhooks from various services for automation and event-driven workflows. Webhooks are secured with secrets and provide real-time notifications about events.

## Available Webhooks

### GitHub Webhooks

Receive notifications about GitHub repository events such as pushes, pull requests, and workflow runs.

**Endpoint:** `POST /api/webhooks/github/push`

**Headers:**
```
Content-Type: application/json
X-GitHub-Event: push
X-Hub-Signature-256: sha256=...
X-GitHub-Delivery: unique-delivery-id
```

**Payload Example:**
```json
{
  "ref": "refs/heads/main",
  "repository": {
    "name": "agl-hostman",
    "full_name": "agl/agl-hostman"
  },
  "pusher": {
    "name": "john-doe",
    "email": "john@agl.com"
  },
  "commits": [
    {
      "id": "abc123",
      "message": "Update API documentation",
      "timestamp": "2024-01-15T10:30:00Z",
      "author": {
        "name": "John Doe",
        "email": "john@agl.com"
      }
    }
  ]
}
```

**Use Cases:**
- Trigger deployments on push
- Run automated tests
- Update documentation
- Notify team members

### Harbor Webhooks

Receive notifications about container registry events.

**Endpoint:** `POST /api/webhooks/harbor`

**Headers:**
```
Content-Type: application/json
Authorization: <secret>
```

**Payload Example:**
```json
{
  "type": "PUSH_ARTIFACT",
  "occur_at": 1705310400,
  "operator": "admin",
  "event_data": {
    "resources": [
      {
        "digest": "sha256:abc123...",
        "tag": "v1.2.0",
        "resource_url": "project/image:v1.2.0"
      }
    ],
    "repository": {
      "name": "agl-app",
      "namespace": "production"
    }
  }
}
```

**Use Cases:**
- Auto-deploy new images
- Trigger vulnerability scans
- Update image registry
- Notify on security updates

### Dokploy Webhooks

Receive deployment status updates from Dokploy.

**Endpoint:** `POST /api/webhooks/dokploy`

**Headers:**
```
Content-Type: application/json
X-Dokploy-Secret: <secret>
```

**Payload Example:**
```json
{
  "deployment_id": "deploy-123",
  "application": "web-app",
  "status": "success",
  "environment": "qa",
  "commit": {
    "sha": "abc123def456",
    "branch": "develop",
    "message": "Add new feature"
  },
  "started_at": "2024-01-15T10:00:00Z",
  "completed_at": "2024-01-15T10:05:23Z",
  "duration_seconds": 323
}
```

**Use Cases:**
- Update deployment status
- Trigger downstream workflows
- Send notifications
- Track deployment metrics

### Slack Interactive Webhooks

Handle interactive components from Slack (buttons, menus, modals).

**Endpoint:** `POST /api/webhooks/slack`

**Headers:**
```
Content-Type: application/x-www-form-urlencoded
X-Slack-Signature: v0=...
X-Slack-Request-Timestamp: 1705310400
```

**Payload Example:**
```json
{
  "type": "block_actions",
  "user": {
    "id": "U12345",
    "name": "john-doe"
  },
  "api_app_id": "A12345",
  "trigger_id": "12345.98765.abcd",
  "actions": [
    {
      "action_id": "deploy_button",
      "block_id": "action_block",
      "text": {
        "type": "plain_text",
        "text": "Deploy"
      },
      "value": "deploy_qa"
    }
  ]
}
```

**Use Cases:**
- Deploy via Slack buttons
- Approve deployments
- Trigger workflows
- Interactive alerts

### PagerDuty Webhooks

Receive alert notifications from PagerDuty.

**Endpoint:** `POST /api/webhooks/pagerduty`

**Headers:**
```
Content-Type: application/json
```

**Payload Example:**
```json
{
  "incident": {
    "id": "P12345",
    "title": "High CPU Usage on AGLSRV1",
    "status": "triggered",
    "severity": "critical",
    "service": {
      "id": "S12345",
      "name": "Infrastructure"
    },
    "created_at": "2024-01-15T10:30:00Z",
    "assignments": [
      {
        "assignee": {
          "id": "U12345",
          "summary": "John Doe"
        }
      }
    ]
  }
}
```

**Use Cases:**
- Sync incidents
- Auto-remediation
- Notify on-call engineers
- Track incident metrics

### Deployment Webhooks

Track deployment lifecycle events.

**Endpoint:** `POST /api/webhooks/deployment`

**Headers:**
```
Content-Type: application/json
X-Webhook-Secret: <secret>
```

**Payload Example:**
```json
{
  "deployment_id": "deploy-123",
  "event": "started",
  "environment": "production",
  "application": "web-app",
  "version": "v1.2.0",
  "timestamp": "2024-01-15T10:00:00Z",
  "metadata": {
    "triggered_by": "john.doe@agl.com",
    "triggered_from": "api",
    "source": "github"
  }
}
```

**Use Cases:**
- Deploy notifications
- Audit trail
- Performance tracking
- Rollback triggers

### Pull Request Webhooks

Receive notifications about pull request events.

**Endpoint:** `POST /api/webhooks/pr`

**Headers:**
```
Content-Type: application/json
X-GitHub-Event: pull_request
```

**Payload Example:**
```json
{
  "action": "opened",
  "number": 123,
  "pull_request": {
    "id": 12345,
    "title": "Add new API endpoint",
    "state": "open",
    "user": {
      "login": "john-doe"
    },
    "head": {
      "ref": "feature/new-endpoint",
      "sha": "abc123"
    },
    "base": {
      "ref": "main",
      "sha": "def456"
    }
  }
}
```

**Use Cases:**
- Automated testing
- Code review notifications
- Preview deployments
- Merge restrictions

## Security

### Webhook Secrets

All webhooks are secured with secrets:

1. Generate a secret in the admin panel
2. Configure the secret in the sending service
3. The API verifies signatures on incoming requests

**Signature Verification (HMAC-SHA256):**

```php
$signature = hash_hmac('sha256', $payload, $webhook_secret);
$expected = 'sha256=' . $signature;

if ($signature !== $expected) {
    abort(403, 'Invalid signature');
}
```

```python
import hmac
import hashlib

signature = hmac.new(
    webhook_secret.encode(),
    payload.encode(),
    hashlib.sha256
).hexdigest()
expected = f'sha256={signature}'

if signature != expected:
    raise Exception('Invalid signature')
```

### IP Whitelisting

Restrict webhook sources by IP address:

```bash
# Add to .env
WEBHOOK_ALLOWED_IPS=192.168.1.0/24,10.0.0.0/8
```

### Rate Limiting

Webhooks are rate-limited to prevent abuse:

- **Per endpoint**: 60 requests per minute
- **Per IP**: 1000 requests per hour

Exceeded rate limits return `429 Too Many Requests`.

## Configuring Webhooks

### GitHub

1. Go to repository Settings > Webhooks
2. Click "Add webhook"
3. Set Payload URL to: `https://your-domain.com/api/webhooks/github/push`
4. Set Content type to: `application/json`
5. Select events: Pushes, Pull requests, Workflow runs
6. Add secret from AGL admin panel

### Harbor

1. Go to Project > Webhooks
2. Click "New Webhook"
3. Set Endpoint URL to: `https://your-domain.com/api/webhooks/harbor`
4. Add auth header from AGL admin panel
5. Select events: Push images, Scan finished

### Dokploy

1. Go to Application > Webhooks
2. Add webhook URL: `https://your-domain.com/api/webhooks/dokploy`
3. Configure events: Deployment started, Deployment success, Deployment failed

### Slack

1. Create a Slack app at https://api.slack.com/apps
2. Enable Interactive Components
3. Set Request URL to: `https://your-domain.com/api/webhooks/slack`
4. Configure signing secret
5. Add bot permissions and scopes

## Testing Webhooks

### Using cURL

```bash
curl -X POST https://your-domain.com/api/webhooks/github/push \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: push" \
  -d '{
    "ref": "refs/heads/main",
    "repository": {"name": "test"},
    "pusher": {"name": "test"}
  }'
```

### Using ngrok for Local Testing

```bash
# Install ngrok
brew install ngrok

# Start ngrok tunnel
ngrok http 8000

# Use the HTTPS URL in webhook configuration
# Example: https://abc123.ngrok.io/api/webhooks/github/push
```

### Webhook Testing Tools

- **Webhook.site**: https://webhook.site - Inspect webhook payloads
- **Request Bin**: https://requestbin.com - Debug webhooks
- **Hookdeck**: https://hookdeck.com - Webhook infrastructure

## Error Handling

### Retries

Webhooks are automatically retried on failure:

- **Retry attempts**: 3
- **Backoff**: Exponential (1s, 2s, 4s)
- **Timeout**: 30 seconds per request

### Error Response

```json
{
  "success": false,
  "message": "Invalid webhook signature",
  "code": 403
}
```

### Monitoring

Monitor webhook deliveries in the dashboard:

- Success rate
- Average response time
- Error logs
- Retry attempts

## Best Practices

1. **Verify signatures** on all incoming webhooks
2. **Return 2xx status** quickly (process asynchronously)
3. **Log all webhooks** for debugging
4. **Handle duplicates** (webhooks may be sent multiple times)
5. **Set appropriate timeouts** for processing
6. **Monitor failures** and set up alerts
7. **Use idempotency keys** for critical operations
8. **Keep secrets** secure and rotate regularly

## Troubleshooting

### Webhook Not Received

- Check webhook URL is correct
- Verify secret/key is configured
- Check IP whitelist settings
- Review rate limit status

### Signature Verification Failed

- Verify secret matches on both ends
- Check encoding (UTF-8)
- Ensure raw payload is used (not parsed)

### Processing Timeout

- Move heavy processing to background jobs
- Increase timeout limits
- Implement queuing for webhooks

## Examples

### Express.js (Node.js)

```javascript
app.post('/api/webhooks/github/push', (req, res) => {
  const signature = req.headers['x-hub-signature-256'];
  const payload = JSON.stringify(req.body);

  if (!verifySignature(payload, signature, WEBHOOK_SECRET)) {
    return res.status(403).json({ error: 'Invalid signature' });
  }

  // Process webhook asynchronously
  processGitHubWebhook(req.body);

  // Return immediately
  res.status(200).json({ received: true });
});
```

### Flask (Python)

```python
@app.route('/api/webhooks/github/push', methods=['POST'])
def github_webhook():
    signature = request.headers.get('X-Hub-Signature-256')
    payload = request.get_data()

    if not verify_signature(payload, signature, WEBHOOK_SECRET):
        return jsonify({'error': 'Invalid signature'}), 403

    # Process webhook
    process_github_webhook(request.get_json())

    return jsonify({'received': True}), 200
```

### Laravel (PHP)

```php
Route::post('/webhooks/github/push', function (Request $request) {
    $signature = $request->header('X-Hub-Signature-256');
    $payload = $request->getContent();

    if (!verifySignature($payload, $signature, config('webhooks.github_secret'))) {
        return response()->json(['error' => 'Invalid signature'], 403);
    }

    // Process webhook
    ProcessGitHubWebhook::dispatch($request->all());

    return response()->json(['received' => true]);
});
```

## Support

For webhook-related issues:
- Documentation: https://docs.agl.com/webhooks
- Email: webhooks@agl.com
- Status: https://status.agl.com

# AGL Hostman API cURL Examples

## Authentication Examples

### Get User Profile
```bash
# After authentication, get current user
curl -X GET "https://api.agl.hostman/api/user" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### WorkOS Authentication
```bash
# Redirect to WorkOS
curl -I "https://api.agl.hostman/api/auth/workos/redirect"

# Handle WorkOS callback (replace with actual code)
curl "https://api.agl.hostman/api/auth/workos/callback?code=YOUR_AUTH_CODE"
```

### Logout
```bash
# Logout from WorkOS
curl -X POST "https://api.agl.hostman/api/auth/workos/logout" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## N8N Workflow Examples

### List All Workflows
```bash
curl -X GET "https://api.agl.hostman/api/n8n/workflows" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Create New Workflow
```bash
curl -X POST "https://api.agl.hostman/api/n8n/workflows" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Database Backup",
    "description": "Automated database backup workflow",
    "category": "backup",
    "tags": ["database", "backup", "daily"]
  }' | jq
```

### Get Specific Workflow
```bash
curl -X GET "https://api.agl.hostman/api/n8n/workflows/my-workflow" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Update Workflow
```bash
curl -X PUT "https://api.agl.hostman/api/n8n/workflows/my-workflow" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Updated backup workflow with retention policy"
  }' | jq
```

### Delete Workflow
```bash
curl -X DELETE "https://api.agl.hostman/api/n8n/workflows/my-workflow" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Activate Workflow
```bash
curl -X POST "https://api.agl.hostman/api/n8n/workflows/my-workflow/activate" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Trigger Workflow
```bash
curl -X POST "https://api.agl.hostman/api/n8n/trigger/my-workflow" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "payload": {
      "action": "deploy",
      "environment": "production",
      "branch": "main"
    },
    "headers": {
      "X-Custom-Header": "value"
    },
    "retries": 3
  }' | jq
```

### Get Workflow Executions
```bash
curl -X GET "https://api.agl.hostman/api/n8n/workflows/my-workflow/executions?status=success&page=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

## Infrastructure Management Examples

### List Physical Locations
```bash
curl -X GET "https://api.agl.hostman/api/infrastructure/locations" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Server Details
```bash
curl -X GET "https://api.agl.hostman/api/infrastructure/servers/HQ" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Infrastructure Status
```bash
curl -X GET "https://api.agl.hostman/api/infrastructure/status" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Infrastructure Analytics
```bash
curl -X GET "https://api.agl.hostman/api/infrastructure/analytics" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

## Container Management Examples

### Create Container
```bash
curl -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web-server-01",
    "template": "ubuntu-22.04",
    "config": {
      "cpu": 4,
      "memory": 8192,
      "disk": 100
    },
    "resources": {
      "network": "public",
      "storage": "ssd"
    }
  }' | jq
```

### Clone Container
```bash
curl -X POST "https://api.agl.hostman/api/containers/123/clone" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "web-server-02",
    "full_clone": false
  }' | jq
```

### Backup Container
```bash
curl -X POST "https://api.agl.hostman/api/containers/123/backup" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "description": "Weekly backup",
    "retention_days": 30
  }' | jq
```

### List Container Snapshots
```bash
curl -X GET "https://api.agl.hostman/api/containers/123/snapshots" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Migrate Container
```bash
curl -X POST "https://api.agl.hostman/api/containers/123/migrate" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "target_location": "DC2",
    "live_migration": true
  }' | jq
```

## Backup Management Examples

### List Backups
```bash
curl -X GET "https://api.agl.hostman/api/backup/list" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Create Backup
```bash
curl -X POST "https://api.agl.hostman/api/backup/create" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Database-Backup-2024",
    "type": "database",
    "description": "Monthly database backup",
    "retention_days": 90
  }' | jq
```

### Download Backup
```bash
curl -X GET "https://api.agl.hostman/api/backup/download/456" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -o backup.zip
```

### Restore Backup
```bash
curl -X POST "https://api.agl.hostman/api/backup/restore/456" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "target_environment": "production"
  }' | jq
```

## Harbor Registry Examples

### List Projects
```bash
curl -X GET "https://api.agl.hostman/api/harbor/projects" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Create Project
```bash
curl -X POST "https://api.agl.hostman/api/harbor/projects" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-app",
    "description": "My application container images",
    "public": false
  }' | jq
```

### Get Project Details
```bash
curl -X GET "https://api.agl.hostman/api/harbor/projects/my-app" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### List Repositories
```bash
curl -X GET "https://api.agl.hostman/api/harbor/repositories" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Repository Details
```bash
curl -X GET "https://api.agl.hostman/api/harbor/repositories/my-app/webapp" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Trigger Vulnerability Scan
```bash
curl -X POST "https://api.agl.hostman/api/harbor/scan" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "project": "my-app",
    "repository": "webapp",
    "reference": "latest"
  }' | jq
```

## Dokploy Application Examples

### List Applications
```bash
curl -X GET "https://api.agl.hostman/api/dokploy/applications" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Create Application
```bash
curl -X POST "https://api.agl.hostman/api/dokploy/applications" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "my-web-app",
    "repository": "https://github.com/user/my-app.git",
    "build_command": "npm run build",
    "start_command": "npm start",
    "environment": {
      "NODE_ENV": "production",
      "PORT": 3000
    }
  }' | jq
```

### Start Application
```bash
curl -X POST "https://api.agl.hostman/api/dokploy/applications/1/start" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Stop Application
```bash
curl -X POST "https://api.agl.hostman/api/dokploy/applications/1/stop" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Deploy Application
```bash
curl -X POST "https://api.agl.hostman/api/dokploy/deploy" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "application_id": 1,
    "environment": "staging",
    "message": "Deploying latest changes"
  }' | jq
```

### Get Application Logs
```bash
curl -X GET "https://api.agl.hostman/api/dokploy/logs?application_id=1" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

## Deployment Pipeline Examples

### Deploy to QA
```bash
curl -X POST "https://api.agl.hostman/api/deployment/qa/deploy" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "branch": "main",
    "environment": {
      "variables": {
        "NODE_ENV": "production",
        "DEBUG": "false"
      }
    },
    "notification": {
      "slack": true,
      "email": false
    }
  }' | jq
```

### Get QA Deployment Status
```bash
curl -X GET "https://api.agl.hostman/api/deployment/qa/status" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get QA Deployment Logs
```bash
curl -X GET "https://api.agl.hostman/api/deployment/qa/logs" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Deploy to UAT
```bash
curl -X POST "https://api.agl.hostman/api/deployment/uat/deploy" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "source_deployment_id": "456",
    "approval_required": true
  }' | jq
```

### Rollback QA
```bash
curl -X POST "https://api.agl.hostman/api/deployment/qa/rollback" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

## Promotion Management Examples

### Promote QA to UAT
```bash
curl -X POST "https://api.agl.hostman/api/promotion/qa-to-uat" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "qa_deployment_id": "456",
    "release_notes": "Bug fixes and performance improvements",
    "scheduled_at": "2024-02-12T10:00:00Z"
  }' | jq
```

### List Pending Promotions
```bash
curl -X GET "https://api.agl.hostman/api/promotion/pending" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Promotion Status
```bash
curl -X GET "https://api.agl.hostman/api/promotion/123/status" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Approve Promotion
```bash
curl -X POST "https://api.agl.hostman/api/promotion/123/approve" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approval_notes": "Approved for production deployment"
  }' | jq
```

## Monitoring Examples

### Get System Metrics
```bash
curl -X GET "https://api.agl.hostman/api/monitoring/metrics" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get System Health
```bash
curl -X GET "https://api.agl.hostman/api/monitoring/health" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get Monitoring Alerts
```bash
curl -X GET "https://api.agl.hostman/api/monitoring/alerts" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Acknowledge Alert
```bash
curl -X POST "https://api.agl.hostman/api/alerts/123/acknowledge" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "comment": "Investigating high CPU usage"
  }' | jq
```

### Resolve Alert
```bash
curl -X POST "https://api.agl.hostman/api/alerts/123/resolve" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "resolution_notes": "CPU usage normalized after scaling"
  }' | jq
```

### Collect Metrics Manually
```bash
curl -X POST "https://api.agl.hostman/api/monitoring/collect" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## RBAC Examples

### Get Current User RBAC Info
```bash
curl -X GET "https://api.agl.hostman/api/rbac/me" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Get RBAC Overview
```bash
curl -X GET "https://api.agl.hostman/api/rbac/overview" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### List Roles
```bash
curl -X GET "https://api.agl.hostman/api/roles" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Create Role
```bash
curl -X POST "https://api.agl.hostman/api/roles" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "backup-operator",
    "description": "Can manage backups and restores",
    "permissions": [
      "backup.view",
      "backup.create",
      "backup.restore"
    ]
  }' | jq
```

### List Permissions
```bash
curl -X GET "https://api.agl.hostman/api/permissions" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

## Webhook Examples

### Handle GitHub Push Event
```bash
# Receive GitHub webhook
curl -X POST "https://api.agl.hostman/api/webhooks/github" \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/main",
    "before": "abc123",
    "after": "def456",
    "repository": {
      "name": "my-app",
      "full_name": "user/my-app"
    },
    "pusher": {
      "name": "john-doe"
    }
  }' | jq
```

### Handle Harbor Push Event
```bash
curl -X POST "https://api.agl.hostman/api/webhooks/harbor" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "push",
    "event_data": {
      "repository": "my-app/webapp",
      "tag": "latest"
    }
  }' | jq
```

## Common Patterns

### Handle Pagination
```bash
curl -X GET "https://api.agl.hostman/api/n8n/workflows?page=2&per_page=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Filter Results
```bash
curl -X GET "https://api.agl.hostman/api/alerts?severity=high&status=active" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Include Additional Data
```bash
curl -X GET "https://api.agl.hostman/api/n8n/workflows?statistics=true" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" | jq
```

### Error Handling
```bash
# Check for errors
response=$(curl -s -w "%{http_code}" -X GET "https://api.agl.hostman/api/user" \
  -H "Authorization: Bearer $API_TOKEN")

http_code="${response: -3}"
body="${response%???}"

if [ "$http_code" -eq 200 ]; then
  echo "Success: $body"
else
  echo "Error ($http_code): $body"
fi
```

## Tips for cURL Usage

1. **Use -s flag** for silent mode to clean up output
2. **Use -i flag** to include HTTP headers in the response
3. **Use -w flag** to custom format the output
4. **Use jq** for JSON formatting and parsing
5. **Store credentials** in environment variables
6. **Use -L flag** to follow redirects
7. **Use --connect-timeout** to set connection timeout

## Advanced cURL Examples

### Upload File
```bash
curl -X POST "https://api.agl.hostman/api/containers/upload" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/container.iso" \
  -F "name=my-container" | jq
```

### Stream Logs
```bash
# Follow deployment logs
curl -N "https://api.agl.hostman/api/deployment/qa/logs?deployment_id=123" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

### Multi-part Request
```bash
curl -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: multipart/form-data" \
  -F "name=my-container" \
  -F "template=ubuntu-22.04" \
  -F "config=@config.json"
```
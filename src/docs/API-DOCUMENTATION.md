# AGL Infrastructure Admin Platform - API Documentation

## Overview
The AGL Infrastructure Admin Platform provides a comprehensive REST API for managing infrastructure, AI orchestration, and automation workflows. All endpoints are secured with either JWT Bearer tokens or API keys.

## Base URL
```
Production: https://api.agl.com
Staging: https://staging-api.agl.com
Development: http://localhost:8000/api
```

## Authentication

### Bearer Token Authentication
Most endpoints require authentication via JWT Bearer token.

```http
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...
```

### API Key Authentication
Alternative authentication method for programmatic access.

```http
X-API-Key: ak_1234567890abcdefghijklmnopqrstuvwxyz
```

## Rate Limiting
- Default: 60 requests per minute
- Can be configured per API key
- Headers returned:
  - `X-RateLimit-Limit`: Maximum requests
  - `X-RateLimit-Remaining`: Remaining requests
  - `X-RateLimit-Reset`: Reset timestamp

## API Endpoints

### Authentication

#### Login
`POST /api/auth/login`

Request:
```json
{
  "email": "admin@agl.com",
  "password": "password123",
  "remember": true
}
```

Response:
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@agl.com",
    "role": "admin"
  }
}
```

#### Logout
`POST /api/auth/logout`

Headers: `Authorization: Bearer {token}`

Response:
```json
{
  "message": "Successfully logged out"
}
```

#### Get Current User
`GET /api/auth/me`

Headers: `Authorization: Bearer {token}`

Response:
```json
{
  "id": 1,
  "name": "Admin User",
  "email": "admin@agl.com",
  "role": "admin",
  "permissions": ["manage_infrastructure", "manage_users"],
  "created_at": "2024-03-15T10:00:00Z"
}
```

### Infrastructure

#### Get Infrastructure Status
`GET /api/infrastructure/status`

Headers: `Authorization: Bearer {token}`

Response:
```json
{
  "servers": [
    {
      "name": "AGLSRV1",
      "status": "online",
      "cpu_usage": 45.2,
      "memory_usage": 62.8,
      "disk_usage": 78.5,
      "containers": 12,
      "vms": 3
    }
  ],
  "summary": {
    "total_servers": 6,
    "online_servers": 5,
    "total_containers": 68,
    "total_vms": 15,
    "health_score": 92.5
  }
}
```

#### Get Infrastructure Metrics
`GET /api/infrastructure/metrics?server=AGLSRV1&period=24h`

Parameters:
- `server` (optional): Filter by server name
- `period` (optional): Time period (1h, 6h, 24h, 7d, 30d)

Response:
```json
{
  "cpu": [
    {"timestamp": "2024-03-15T10:00:00Z", "value": 45.2},
    {"timestamp": "2024-03-15T11:00:00Z", "value": 48.7}
  ],
  "memory": [
    {"timestamp": "2024-03-15T10:00:00Z", "value": 62.8},
    {"timestamp": "2024-03-15T11:00:00Z", "value": 65.3}
  ],
  "disk": [
    {"timestamp": "2024-03-15T10:00:00Z", "value": 78.5},
    {"timestamp": "2024-03-15T11:00:00Z", "value": 78.8}
  ],
  "network": [
    {"timestamp": "2024-03-15T10:00:00Z", "rx": 1024000, "tx": 512000},
    {"timestamp": "2024-03-15T11:00:00Z", "rx": 1124000, "tx": 612000}
  ]
}
```

#### Analyze Infrastructure
`POST /api/infrastructure/analyze`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "focus": "performance",
  "servers": ["AGLSRV1", "AGLSRV2"]
}
```

Response:
```json
{
  "health_score": 85.7,
  "issues": [
    {
      "severity": "warning",
      "component": "AGLSRV2",
      "description": "High memory usage detected",
      "recommendation": "Consider adding more RAM or optimizing applications"
    }
  ],
  "predictions": [
    {
      "metric": "disk_usage",
      "trend": "increasing",
      "alert_threshold": "7 days"
    }
  ],
  "recommendations": [
    {
      "priority": "high",
      "action": "Upgrade AGLSRV2 memory",
      "impact": "Prevent potential outages"
    }
  ]
}
```

### AI Models

#### List AI Models
`GET /api/ai-models`

Headers: `Authorization: Bearer {token}`

Response:
```json
[
  {
    "id": "claude-3",
    "name": "Claude 3",
    "provider": "anthropic",
    "status": "available",
    "capabilities": ["text-generation", "code", "analysis"],
    "max_tokens": 100000,
    "cost_per_1k_tokens": 0.015
  },
  {
    "id": "gpt-4",
    "name": "GPT-4",
    "provider": "openai",
    "status": "available",
    "capabilities": ["text-generation", "code", "vision"],
    "max_tokens": 128000,
    "cost_per_1k_tokens": 0.03
  }
]
```

#### Execute AI Model
`POST /api/ai-models/execute`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "prompt": "Analyze the infrastructure metrics and provide recommendations",
  "model": "claude-3",
  "orchestrate": false,
  "max_tokens": 2000,
  "temperature": 0.7,
  "context": {
    "server": "AGLSRV1",
    "metrics": {...}
  }
}
```

Response:
```json
{
  "response": "Based on the metrics analysis...",
  "model_used": "claude-3",
  "tokens_used": 1523,
  "execution_time": 2.34,
  "confidence": 0.95,
  "orchestration": null
}
```

#### Multi-Model Orchestration
`POST /api/ai-models/execute`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "prompt": "Complex infrastructure optimization task",
  "orchestrate": true,
  "max_tokens": 5000
}
```

Response:
```json
{
  "response": "Consensus recommendation from multiple models...",
  "model_used": "orchestrated",
  "tokens_used": 4523,
  "execution_time": 8.67,
  "confidence": 0.92,
  "orchestration": {
    "models_consulted": ["claude-3", "gpt-4", "gemini-pro"],
    "consensus_score": 0.88
  }
}
```

### Backups

#### List Backups
`GET /api/backups?type=full&status=completed`

Parameters:
- `type` (optional): full, database, files, config
- `status` (optional): pending, running, completed, failed

Response:
```json
{
  "backups": [
    {
      "id": 1,
      "name": "backup_20240315_120000",
      "type": "full",
      "size": 1073741824,
      "status": "completed",
      "path": "/backups/backup_20240315_120000.tar.gz",
      "created_at": "2024-03-15T12:00:00Z"
    }
  ],
  "count": 1
}
```

#### Create Backup
`POST /api/backups`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "type": "full",
  "async": true,
  "notify": true,
  "email": "admin@agl.com",
  "encrypt": true,
  "compress": true,
  "retention_days": 30
}
```

Response:
```json
{
  "message": "Backup job queued",
  "type": "full",
  "status": "pending"
}
```

#### Restore Backup
`POST /api/backups/{id}/restore`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "target": "staging",
  "verify": true,
  "force": false
}
```

Response:
```json
{
  "message": "Restore initiated",
  "result": {
    "job_id": "restore_20240315_130000",
    "status": "running"
  }
}
```

### API Keys

#### List API Keys
`GET /api/api-keys`

Headers: `Authorization: Bearer {token}`

Response:
```json
[
  {
    "id": 1,
    "name": "Production API Key",
    "key": "ak_1234...abcd",
    "permissions": ["read:infrastructure", "write:containers"],
    "rate_limit": 60,
    "usage_count": 1523,
    "last_used_at": "2024-03-15T10:00:00Z",
    "expires_at": "2024-06-15T00:00:00Z",
    "is_active": true,
    "created_at": "2024-03-01T00:00:00Z"
  }
]
```

#### Create API Key
`POST /api/api-keys`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "name": "Production API Key",
  "permissions": ["read:infrastructure", "write:containers"],
  "rate_limit": 60,
  "expires_in_days": 90
}
```

Response:
```json
{
  "id": 1,
  "name": "Production API Key",
  "key": "ak_1234567890abcdefghijklmnopqrstuvwxyz",
  "secret": "sk_abcdefghijklmnopqrstuvwxyz1234567890",
  "permissions": ["read:infrastructure", "write:containers"],
  "rate_limit": 60,
  "expires_at": "2024-06-15T00:00:00Z",
  "created_at": "2024-03-15T00:00:00Z",
  "message": "Store these credentials securely. The secret will not be shown again."
}
```

### N8N Workflows

#### Execute Workflow
`POST /api/n8n/execute`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "workflow_id": "wf_infrastructure_check",
  "data": {
    "servers": ["AGLSRV1", "AGLSRV2"],
    "check_type": "health"
  }
}
```

Response:
```json
{
  "execution_id": "exec_123456",
  "status": "running",
  "message": "Workflow execution started"
}
```

#### Get Workflow Status
`GET /api/n8n/status/{executionId}`

Headers: `Authorization: Bearer {token}`

Response:
```json
{
  "execution_id": "exec_123456",
  "status": "completed",
  "result": {
    "success": true,
    "data": {...}
  },
  "started_at": "2024-03-15T10:00:00Z",
  "completed_at": "2024-03-15T10:05:00Z"
}
```

### Notifications

#### Send Notification
`POST /api/notifications`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "type": "alert",
  "priority": "high",
  "title": "Infrastructure Alert",
  "content": {
    "message": "High CPU usage detected on AGLSRV1",
    "server": "AGLSRV1",
    "metric": "cpu",
    "value": 95.5
  },
  "channels": ["email", "slack", "discord"]
}
```

Response:
```json
{
  "success": true,
  "notification_id": "notif_123456",
  "channels_sent": ["email", "slack", "discord"],
  "results": {
    "email": {"success": true},
    "slack": {"success": true},
    "discord": {"success": true}
  }
}
```

### Terraform

#### Plan Infrastructure Changes
`POST /api/terraform/plan`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "environment": "production",
  "variables": {
    "vm_count": 3,
    "cpu_cores": 4,
    "memory_gb": 16
  }
}
```

Response:
```json
{
  "success": true,
  "plan_output": "Plan: 3 to add, 0 to change, 0 to destroy.",
  "changes": [
    {
      "action": "create",
      "resource": "proxmox_vm",
      "name": "vm-prod-01"
    }
  ]
}
```

#### Apply Infrastructure Changes
`POST /api/terraform/apply`

Headers: `Authorization: Bearer {token}`

Request:
```json
{
  "environment": "production",
  "auto_approve": false
}
```

Response:
```json
{
  "success": true,
  "apply_output": "Apply complete! Resources: 3 added, 0 changed, 0 destroyed.",
  "resources_created": ["vm-prod-01", "vm-prod-02", "vm-prod-03"]
}
```

### Audit Logs

#### Get Audit Logs
`GET /api/audit-logs?action=create&user_id=1&limit=50`

Parameters:
- `action` (optional): Filter by action type
- `user_id` (optional): Filter by user
- `model_type` (optional): Filter by model type
- `limit` (optional): Number of records (default: 50)
- `offset` (optional): Pagination offset

Response:
```json
{
  "logs": [
    {
      "id": 1,
      "user_id": 1,
      "action": "api.infrastructure.analyze",
      "model_type": "Infrastructure",
      "model_id": 1,
      "old_values": null,
      "new_values": {"analyzed": true},
      "ip_address": "192.168.1.100",
      "user_agent": "Mozilla/5.0...",
      "metadata": {
        "method": "POST",
        "url": "https://api.agl.com/api/infrastructure/analyze",
        "status": 200
      },
      "created_at": "2024-03-15T10:00:00Z"
    }
  ],
  "total": 150,
  "page": 1,
  "per_page": 50
}
```

## Error Handling

All error responses follow a consistent format:

```json
{
  "message": "Validation error",
  "errors": {
    "field": ["The field is required."]
  },
  "code": 422
}
```

### Common Error Codes
- `400` Bad Request - Invalid request format
- `401` Unauthorized - Missing or invalid authentication
- `403` Forbidden - Insufficient permissions
- `404` Not Found - Resource not found
- `422` Unprocessable Entity - Validation errors
- `429` Too Many Requests - Rate limit exceeded
- `500` Internal Server Error - Server error

## WebSocket Events

The platform supports real-time updates via WebSocket connections.

### Connection
```javascript
const socket = new WebSocket('wss://api.agl.com/ws');
socket.addEventListener('open', (event) => {
  socket.send(JSON.stringify({
    type: 'auth',
    token: 'Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...'
  }));
});
```

### Events

#### Infrastructure Updates
```javascript
{
  "type": "infrastructure.update",
  "data": {
    "server": "AGLSRV1",
    "metrics": {
      "cpu": 45.2,
      "memory": 62.8
    }
  }
}
```

#### Backup Status
```javascript
{
  "type": "backup.status",
  "data": {
    "backup_id": "backup_20240315_120000",
    "status": "completed",
    "size": 1073741824
  }
}
```

#### AI Model Response
```javascript
{
  "type": "ai.response",
  "data": {
    "request_id": "req_123456",
    "response": "Analysis complete...",
    "tokens_used": 1523
  }
}
```

## SDK Examples

### PHP
```php
$client = new \GuzzleHttp\Client([
    'base_uri' => 'https://api.agl.com',
    'headers' => [
        'Authorization' => 'Bearer ' . $token,
        'Accept' => 'application/json',
    ]
]);

$response = $client->get('/api/infrastructure/status');
$data = json_decode($response->getBody(), true);
```

### Python
```python
import requests

headers = {
    'Authorization': f'Bearer {token}',
    'Accept': 'application/json'
}

response = requests.get(
    'https://api.agl.com/api/infrastructure/status',
    headers=headers
)
data = response.json()
```

### JavaScript
```javascript
const response = await fetch('https://api.agl.com/api/infrastructure/status', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Accept': 'application/json'
  }
});
const data = await response.json();
```

### cURL
```bash
curl -X GET https://api.agl.com/api/infrastructure/status \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/json"
```

## Postman Collection
Download our Postman collection for easy API testing:
[Download Postman Collection](https://api.agl.com/postman-collection.json)

## OpenAPI Specification
Access the interactive API documentation:
- Swagger UI: https://api.agl.com/api/documentation
- OpenAPI Spec: https://api.agl.com/api-docs.json

## Support
For API support, please contact:
- Email: api-support@agl.com
- Documentation: https://docs.agl.com/api
- Status Page: https://status.agl.com
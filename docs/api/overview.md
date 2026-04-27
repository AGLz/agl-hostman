# API Overview

The AGL Hostman API provides programmatic access to all system functionality, enabling automation, integration, and third-party development.

## Authentication

All API requests require authentication using Bearer tokens.

### Bearer Token Authentication

```bash
# Get token
curl -X POST "https://api.aglhostman.local/auth/login" \
     -H "Content-Type: application/json" \
     -d '{"email": "admin@aglhostman.local", "password": "password"}'

# Use token in requests
curl -H "Authorization: Bearer $TOKEN" \
     "https://api.aglhostman.local/status"
```

### API Key Authentication

```bash
# Use API key
curl -H "X-API-Key: your-api-key" \
     "https://api.aglhostman.local/status"
```

## API Endpoints

### System Status

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/status` | Get system status |
| GET | `/api/v1/health` | Get detailed health check |
| GET | `/api/v1/version` | Get system version |

### Storage Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/storage/nfs` | List NFS mounts |
| POST | `/api/v1/storage/nfs` | Create NFS mount |
| PUT | `/api/v1/storage/nfs/{id}` | Update NFS mount |
| DELETE | `/api/v1/storage/nfs/{id}` | Delete NFS mount |
| GET | `/api/v1/storage/iscsi` | List iSCSI targets |
| POST | `/api/v1/storage/iscsi` | Create iSCSI target |
| PUT | `/api/v1/storage/iscsi/{id}` | Update iSCSI target |
| DELETE | `/api/v1/storage/iscsi/{id}` | Delete iSCSI target |
| GET | `/api/v1/storage/pbs` | List PBS repositories |
| POST | `/api/v1/storage/pbs` | Create PBS repository |
| PUT | `/api/v1/storage/pbs/{id}` | Update PBS repository |
| DELETE | `/api/v1/storage/pbs/{id}` | Delete PBS repository |

### Monitoring

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/monitoring/metrics` | Get system metrics |
| GET | `/api/v1/monitoring/metrics/{metric}` | Get specific metric |
| POST | `/api/v1/monitoring/alerts` | Create alert |
| GET | `/api/v1/monitoring/alerts` | List alerts |
| PUT | `/api/v1/monitoring/alerts/{id}` | Update alert |
| DELETE | `/api/v1/monitoring/alerts/{id}` | Delete alert |
| GET | `/api/v1/monitoring/dashboards` | List dashboards |
| GET | `/api/v1/monitoring/dashboards/{id}` | Get dashboard |

### Backup Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/backups` | List backup jobs |
| POST | `/api/v1/backups` | Create backup job |
| PUT | `/api/v1/backups/{id}` | Update backup job |
| DELETE | `/api/v1/backups/{id}` | Delete backup job |
| GET | `/api/v1/backups/{id}/status` | Get backup status |
| POST | `/api/v1/backups/{id}/restore` | Restore backup |
| GET | `/api/v1/backups/history` | Get backup history |

### User Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/users` | List users |
| POST | `/api/v1/users` | Create user |
| PUT | `/api/v1/users/{id}` | Update user |
| DELETE | `/api/v1/users/{id}` | Delete user |
| GET | `/api/v1/users/{id}/permissions` | Get user permissions |
| PUT | `/api/v1/users/{id}/permissions` | Update user permissions |

### Host Management

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/v1/hosts` | List hosts |
| POST | `/api/v1/hosts` | Add host |
| PUT | `/api/v1/hosts/{id}` | Update host |
| DELETE | `/api/v1/hosts/{id}` | Remove host |
| GET | `/api/v1/hosts/{id}/status` | Get host status |
| POST | `/api/v1/hosts/{id}/restart` | Restart host |
| POST | `/api/v1/hosts/{id}/shutdown` | Shutdown host |

## Response Format

All API responses follow a consistent format:

```json
{
  "success": true,
  "data": {
    // Response data
  },
  "message": "Success message",
  "timestamp": "2025-10-14T12:00:00Z",
  "metadata": {
    "request_id": "req_123456",
    "version": "1.0.0"
  }
}
```

Error responses:

```json
{
  "success": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Error description",
    "details": {
      "field": "validation error details"
    }
  },
  "timestamp": "2025-10-14T12:00:00Z",
  "metadata": {
    "request_id": "req_123456"
  }
}
```

## Error Codes

| Code | Description |
|------|-------------|
| `VALIDATION_ERROR` | Input validation failed |
| `AUTHENTICATION_ERROR` | Authentication failed |
| `AUTHORIZATION_ERROR` | Insufficient permissions |
| `NOT_FOUND` | Resource not found |
| `INTERNAL_ERROR` | Internal server error |
| `RATE_LIMIT_ERROR` | Rate limit exceeded |
| `SERVICE_UNAVAILABLE` | Service temporarily unavailable |

## Rate Limiting

API requests are rate limited to prevent abuse:

- **Default limit**: 100 requests per minute
- **Burst limit**: 10 requests per second
- **User limits**: Configurable per user role

Rate limit headers in responses:
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1621234567
```

## API Documentation

### Interactive API Documentation

API documentation is available at:
- **Swagger UI**: `https://api.aglhostman.local/docs`
- **ReDoc**: `https://api.aglhostman.local/redoc`

### Code Generation

SDKs are available for popular programming languages:

#### JavaScript/TypeScript
```bash
npm install @aglhostman/sdk
```

```javascript
import AGLHostman from '@aglhostman/sdk';

const client = new AGLHostman({
  baseURL: 'https://api.aglhostman.local',
  token: 'your-token'
});

// Get system status
const status = await client.system.getStatus();
console.log(status);
```

#### Python
```bash
pip install agl-hostman-sdk
```

```python
from agl_hostman import AGLHostmanClient

client = AGLHostmanClient(
    base_url='https://api.aglhostman.local',
    token='your-token'
)

# Get system status
status = client.system.get_status()
print(status)
```

#### Go
```bash
go get github.com/aglhostman/sdk-go
```

```go
package main

import (
    "context"
    "fmt"
    "github.com/aglhostman/sdk-go"
)

func main() {
    client := aglhostman.NewClient(
        "https://api.aglhostman.local",
        "your-token",
    )

    // Get system status
    status, err := client.System.GetStatus(context.Background())
    if err != nil {
        panic(err)
    }
    fmt.Printf("%+v\n", status)
}
```

## Webhooks

AGL Hostman supports webhooks for real-time notifications:

### Supported Events
- `system.created`
- `system.updated`
- `system.deleted`
- `backup.started`
- `backup.completed`
- `backup.failed`
- `alert.triggered`
- `user.created`
- `user.updated`

### Configuration
```json
{
  "webhooks": [
    {
      "event": "*",
      "url": "https://your-webhook-url.com",
      "secret": "your-secret",
      "timeout": 30
    }
  ]
}
```

### Webhook Payload
```json
{
  "event": "backup.completed",
  "timestamp": "2025-10-14T12:00:00Z",
  "data": {
    "backup_id": "bak_123456",
    "status": "success",
    "size": "100GB",
    "duration": 3600
  },
  "signature": "sha256=..."
}
```

## Batch Operations

### Batch Storage Operations
```json
POST /api/v1/storage/nfs/batch
{
  "operations": [
    {
      "method": "create",
      "data": {
        "mount_point": "/mnt/test1",
        "server": "aglsrv1.local"
      }
    },
    {
      "method": "create",
      "data": {
        "mount_point": "/mnt/test2",
        "server": "aglsrv1.local"
      }
    }
  ]
}
```

### Bulk User Management
```json
POST /api/v1/users/batch
{
  "operation": "update",
  "users": [
    {
      "id": "user_1",
      "permissions": ["storage:read"]
    },
    {
      "id": "user_2",
      "permissions": ["monitoring:read"]
    }
  ]
}
```

## WebSockets

Real-time updates are available via WebSockets:

```javascript
const ws = new WebSocket('wss://api.aglhostman.local/ws');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  console.log('Received update:', data);
};

// Subscribe to specific events
ws.send(JSON.stringify({
  action: 'subscribe',
  events: ['backup.started', 'alert.triggered']
}));
```

## Pagination

List endpoints support pagination:

```json
GET /api/v1/users?page=1&per_page=10&sort=email&order=asc
```

Response:
```json
{
  "success": true,
  "data": {
    "users": [...],
    "pagination": {
      "page": 1,
      "per_page": 10,
      "total": 50,
      "total_pages": 5
    }
  }
}
```

## Search and Filtering

All list endpoints support search and filtering:

### Search
```json
GET /api/v1/users?search=john@example.com
```

### Filtering
```json
GET /api/v1/users?role=admin&active=true&created_after=2025-01-01
```

### Filtering Operators
- `eq`: Equal
- `neq`: Not equal
- `gt`: Greater than
- `gte`: Greater than or equal
- `lt`: Less than
- `lte`: Less than or equal
- `in`: In array
- `contains`: Contains string
- `startswith`: Starts with
- `endswith`: Ends with

## File Upload

### Upload Backup Configuration
```json
POST /api/v1/backups/upload
Content-Type: multipart/form-data

file=@backup-config.json
```

### Upload Certificate
```json
POST /api/v1/security/certificates/upload
Content-Type: multipart/form-data

certificate=@server.crt
private_key=@server.key
```

## API Versioning

The API uses version URLs:

- **Current**: `/api/v1/`
- **Next**: `/api/v2/` (planned)

Version selection:
```json
Accept: application/vnd.aglhostman.v1+json
```

## Examples

### Get System Status
```bash
curl -H "Authorization: Bearer $TOKEN" \
     -H "Accept: application/json" \
     "https://api.aglhostman.local/api/v1/status"
```

### Create NFS Mount
```bash
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "mount_point": "/mnt/test",
       "server": "aglsrv1.local",
       "export": "/export/data",
       "options": "defaults"
     }' \
     "https://api.aglhostman.local/api/v1/storage/nfs"
```

### Create Backup Job
```bash
curl -X POST \
     -H "Authorization: Bearer $TOKEN" \
     -H "Content-Type: application/json" \
     -d '{
       "name": "daily-backup",
       "schedule": "0 2 * * *",
       "retention": 7,
       "targets": [
         "aglsrv1.local:/export/data"
       ],
       "compression": true,
       "encryption": true
     }' \
     "https://api.aglhostman.local/api/v1/backups"
```

## Testing

### API Testing Commands
```bash
# Test API connectivity
curl -H "Authorization: Bearer $TOKEN" \
     "https://api.aglhostman.local/api/v1/health"

# Test authentication
curl -H "Authorization: Bearer invalid-token" \
     "https://api.aglhostman.local/api/v1/status"

# Test rate limiting
for i in {1..150}; do
  curl -H "Authorization: Bearer $TOKEN" \
       "https://api.aglhostman.local/api/v1/status" &
done
```

### Integration Testing
```bash
# Run integration tests
npm run test:integration

# Run with specific API version
npm run test:integration -- --api-version=v1

# Run with custom endpoint
npm run test:integration -- --endpoint=https://staging.api.aglhostman.local
```

---

*Next: [REST API](rest.md)*

*Previous: [API Overview](../api/overview.md)*
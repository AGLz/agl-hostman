# AGL Hostman API Explorer

Interactive API documentation and explorer for the AGL Hostman Infrastructure Management API.

## Features

- **Swagger UI**: Full-featured API exploration with "Try it out" functionality
- **ReDoc**: Beautiful, responsive API documentation
- **Code Examples**: Pre-built code samples in multiple languages
- **API Key Authentication**: Secure credential management with browser storage
- **JWT Token Support**: Bearer token authentication
- **Responsive Design**: Mobile-friendly interface
- **Dark Theme**: Easy on the eyes for extended use
- **Live Testing**: Test API endpoints directly from the browser

## Quick Start

### 1. Access the API Explorer

Navigate to:
```
https://docs.aglhostman.local/api-explorer/
```

### 2. Set Authentication

1. Click the **"Set API Key"** button in the header
2. Enter your API Key (from the dashboard) or JWT Token
3. Optionally, change the server URL for different environments
4. Click **"Save Credentials"**

Your credentials are stored in browser local storage for convenience.

### 3. Explore the API

- **Swagger UI Tab**: Interactive API testing with "Try it out" buttons
- **ReDoc Tab**: Read-only documentation with organized sections
- **Code Examples Tab**: Copy-paste ready code samples

## Authentication Methods

### API Key (Recommended for Production)

```bash
curl https://api.agl.com/api/infrastructure/status \
  -H "X-API-Key: YOUR_API_KEY_HERE"
```

### JWT Token

First, authenticate to get a token:

```bash
curl -X POST https://api.agl.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@agl.com",
    "password": "your-password"
  }'
```

Then use the token:

```bash
curl https://api.agl.com/api/infrastructure/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN"
```

## Configuration

The API Explorer can be customized by editing `config.js`:

```javascript
// Change the default server
apiConfig.defaultServer = 'https://your-api.com/api';

// Customize theme colors
uiConfig.primaryColor = '#your-color';

// Enable/disable features
analyticsConfig.enabled = true;
```

## API Endpoints

The AGL Hostman API provides the following endpoint categories:

| Category | Endpoints | Description |
|----------|-----------|-------------|
| **Authentication** | `/auth/*` | User login, logout, token management |
| **Infrastructure** | `/infrastructure/*` | Server status, metrics, monitoring |
| **Containers** | `/containers/*` | LXC container lifecycle management |
| **Deployments** | `/deployments/*` | Application deployment automation |
| **Backups** | `/backups/*` | Backup creation and restoration |
| **Monitoring** | `/monitoring/*` | Metrics, alerts, health checks |
| **N8N Workflows** | `/n8n/*` | Workflow automation and triggers |

## Rate Limiting

- **Authenticated requests**: 1000 requests/hour
- **Webhook endpoints**: 60 requests/minute
- **Public endpoints**: 100 requests/hour

Rate limit headers are included in all responses:
- `X-RateLimit-Limit`: Your rate limit
- `X-RateLimit-Remaining`: Remaining requests
- `X-RateLimit-Reset`: Unix timestamp when limit resets

## Code Examples

### JavaScript (Fetch API)

```javascript
const response = await fetch('https://api.agl.com/api/infrastructure/status', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});

const data = await response.json();
console.log(data);
```

### Python (requests)

```python
import requests

headers = {'Authorization': f'Bearer {token}'}
response = requests.get(
    'https://api.agl.com/api/infrastructure/status',
    headers=headers
)
data = response.json()
```

### PHP (Guzzle)

```php
use GuzzleHttp\Client;

$client = new Client([
    'base_uri' => 'https://api.agl.com/api',
]);

$response = $client->get('/infrastructure/status', [
    'headers' => [
        'Authorization' => "Bearer $token"
    ]
]);

$data = json_decode($response->getBody(), true);
```

## Error Handling

The API returns standard HTTP status codes:

| Code | Description |
|------|-------------|
| 200 | Success |
| 201 | Resource created |
| 400 | Bad request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not found |
| 422 | Validation error |
| 429 | Rate limit exceeded |
| 500 | Internal server error |

Error response format:

```json
{
  "message": "Error description",
  "code": "ERROR_CODE",
  "errors": {
    "field_name": ["Validation error message"]
  }
}
```

## Webhooks

Configure webhook URLs to receive real-time notifications:

1. Navigate to **Deployments** > **Webhooks** in the dashboard
2. Add your webhook endpoint URL
3. Select events to subscribe to
4. Webhooks will be sent as POST requests with JSON payload

## SDK Libraries

Official SDKs are available:

- **JavaScript**: `npm install @agl/hostman-js`
- **Python**: `pip install agl-hostman`
- **PHP**: `composer require agl/hostman-php`

## Support

- **Documentation**: https://docs.aglhostman.local
- **GitHub Issues**: https://github.com/aglhostman/agl-hostman/issues
- **Email Support**: api@agl.com

## License

MIT License - See LICENSE file for details

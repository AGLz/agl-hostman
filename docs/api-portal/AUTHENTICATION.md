# API Authentication Guide

## Overview

The AGL Infrastructure API supports multiple authentication methods to accommodate different use cases:

- **Bearer Token (JWT)**: Recommended for user accounts and interactive applications
- **API Key**: Ideal for service accounts and automated integrations
- **OAuth 2.0 (WorkOS)**: For enterprise SSO integration

## Bearer Token Authentication

### Overview

JWT (JSON Web Token) authentication is the primary method for user authentication. Tokens are issued after successful login and must be included in the `Authorization` header.

### Getting a Token

**Endpoint:** `POST /api/auth/login`

**Request:**
```json
{
  "email": "admin@agl.com",
  "password": "your-secure-password",
  "remember": true
}
```

**Response:**
```json
{
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJhZ2wtYXBpIiw...",
  "token_type": "bearer",
  "expires_in": 3600,
  "user": {
    "id": 1,
    "name": "Admin User",
    "email": "admin@agl.com",
    "roles": ["admin"],
    "permissions": ["infrastructure.view", "infrastructure.manage"]
  }
}
```

### Using the Token

Include the token in the `Authorization` header with the `Bearer` prefix:

```bash
curl -X GET https://api.agl.com/api/infrastructure/status \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

### Token Expiration

- **Default TTL**: 3600 seconds (1 hour)
- **Refresh**: Use the `/auth/refresh` endpoint to get a new token
- **Revocation**: Tokens are automatically revoked on logout

### JavaScript/TypeScript Example

```typescript
const token = localStorage.getItem('agl_api_token');

const response = await fetch('https://api.agl.com/api/infrastructure/status', {
  headers: {
    'Authorization': `Bearer ${token}`,
    'Content-Type': 'application/json'
  }
});

const data = await response.json();
```

### Python Example

```python
import requests

token = 'your-jwt-token'
headers = {
    'Authorization': f'Bearer {token}',
    'Content-Type': 'application/json'
}

response = requests.get(
    'https://api.agl.com/api/infrastructure/status',
    headers=headers
)

data = response.json()
```

### PHP Example

```php
$token = 'your-jwt-token';

$client = new GuzzleHttp\Client();
$response = $client->get('https://api.agl.com/api/infrastructure/status', [
    'headers' => [
        'Authorization' => 'Bearer ' . $token,
        'Content-Type' => 'application/json'
    ]
]);

$data = json_decode($response->getBody(), true);
```

## API Key Authentication

### Overview

API keys are recommended for service accounts, automated scripts, and server-to-server communication. Keys are generated in the admin panel and associated with specific permissions.

### Creating an API Key

1. Navigate to Settings > API Keys
2. Click "Generate New Key"
3. Set permissions and expiration
4. Copy the key (it won't be shown again)

### Using the API Key

Include the key in the `X-API-Key` header:

```bash
curl -X GET https://api.agl.com/api/infrastructure/status \
  -H "X-API-Key: your-api-key-here" \
  -H "Content-Type: application/json"
```

### Security Best Practices

- **Never** commit API keys to version control
- Use environment variables to store keys
- Rotate keys regularly (recommended: every 90 days)
- Set appropriate permissions (principle of least privilege)
- Monitor usage in the API keys dashboard

### Environment Variables Example

```bash
# .env file
AGL_API_KEY=sk_live_51MzZ2...
AGL_API_URL=https://api.agl.com/api
```

### Using with dotenv (Node.js)

```javascript
require('dotenv').config();

const response = await fetch(`${process.env.AGL_API_URL}/infrastructure/status`, {
  headers: {
    'X-API-Key': process.env.AGL_API_KEY,
    'Content-Type': 'application/json'
  }
});
```

### Using with python-dotenv

```python
from dotenv import load_dotenv
import os
import requests

load_dotenv()

api_key = os.getenv('AGL_API_KEY')
headers = {
    'X-API-Key': api_key,
    'Content-Type': 'application/json'
}

response = requests.get(
    'https://api.agl.com/api/infrastructure/status',
    headers=headers
)
```

## OAuth 2.0 Authentication

### Overview

For enterprise SSO integration, we support OAuth 2.0 via WorkOS. This allows your organization to use existing identity providers.

### OAuth Flow

1. **Redirect to WorkOS**: User is redirected to WorkOS authentication
2. **Authentication**: User logs in with their SSO provider
3. **Callback**: User is redirected back with authorization code
4. **Token Exchange**: Authorization code is exchanged for JWT token

### Endpoints

**Authorization URL:**
```
GET /api/auth/workos/redirect
```

**Callback URL:**
```
GET /api/auth/workos/callback
```

**Logout:**
```
POST /api/auth/workos/logout
```

### Configuration

Set these environment variables:

```bash
WORKOS_API_KEY=sk_test_xxxx
WORKOS_CLIENT_ID=client_xxxx
WORKOS_REDIRECT_URI=https://your-app.com/auth/callback
```

### Supported Providers

- Okta
- Azure Active Directory
- Google Workspace
- OneLogin
- Ping Identity
- Custom SAML 2.0 providers

## Error Handling

### Authentication Errors

**401 Unauthorized**
```json
{
  "message": "Unauthenticated",
  "code": 401
}
```

Causes:
- Invalid or expired token
- Missing authentication header
- Malformed token

**403 Forbidden**
```json
{
  "message": "This action is unauthorized",
  "code": 403
}
```

Causes:
- Insufficient permissions
- IP restrictions
- Account suspended

### Token Refresh

When your token is about to expire, refresh it:

```bash
curl -X POST https://api.agl.com/api/auth/refresh \
  -H "Authorization: Bearer YOUR_CURRENT_TOKEN" \
  -H "Content-Type: application/json"
```

## Session Management

### Logout

Revoke the current token:

```bash
curl -X POST https://api.agl.com/api/auth/logout \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

### Get Current User

Retrieve authenticated user details:

```bash
curl -X GET https://api.agl.com/api/auth/me \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json"
```

## Rate Limiting

Authentication is subject to rate limiting:

- **Login attempts**: 5 attempts per 15 minutes per IP
- **Token refresh**: 10 requests per minute per token
- **API key usage**: 1000 requests per hour per key

Rate limit headers are included in responses:

```
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1704067200
```

## Security Best Practices

1. **Always use HTTPS** in production environments
2. **Never log tokens** or include them in error messages
3. **Implement token refresh** logic in your application
4. **Use environment variables** for credentials
5. **Monitor API usage** for unusual patterns
6. **Rotate credentials** regularly
7. **Implement proper logout** to revoke tokens
8. **Validate token expiration** before making requests

## Troubleshooting

### Common Issues

**Issue: "Token has expired"**
- Solution: Implement token refresh logic or re-authenticate

**Issue: "Invalid API key"**
- Solution: Verify the key is correct and not expired

**Issue: "Insufficient permissions"**
- Solution: Check user roles and permissions in the admin panel

**Issue: "Too many attempts"**
- Solution: Wait for the rate limit window to reset

### Debug Mode

For development, you can enable debug mode to see detailed error messages:

```bash
# Add to .env
APP_DEBUG=true
```

**Warning:** Never enable debug mode in production.

## Support

For authentication issues:
- Documentation: https://docs.agl.com
- Email: api@agl.com
- Status Page: https://status.agl.com

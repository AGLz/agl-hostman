# Authentication Guide for AGL Hostman API

## Overview

The AGL Hostman API uses JWT (JSON Web Token) authentication via WorkOS for secure access to protected endpoints. This guide explains how to authenticate and interact with the API.

## Authentication Flow

### 1. Authentication via WorkOS

The API uses WorkOS as the primary identity provider for authentication.

#### Step 1: Redirect to WorkOS
```http
GET /auth/workos/redirect
```

This endpoint returns a redirect URL to WorkOS for OAuth authentication.

#### Step 2: WorkOS Callback
After successful authentication with WorkOS, the user is redirected back to:
```http
GET /auth/workos/callback?code=AUTHORIZATION_CODE
```

The server processes this code and returns:
- JWT access token
- User profile information

#### Step 3: Use Access Token
Include the JWT in the Authorization header for all protected API requests:

```http
Authorization: Bearer YOUR_JWT_TOKEN
```

## Endpoint Security Classification

### Protected Endpoints
Most API endpoints require authentication using the BearerAuth scheme:
```yaml
security:
  - BearerAuth: []
```

### Public Webhook Endpoints
Some endpoints are publicly accessible and don't require authentication:
- `/n8n/webhook/{workflow}`
- `/webhooks/github`
- `/webhooks/harbor`
- `/webhooks/pagerduty`
- `/webhooks/deployment`
- `/webhooks/pr`
- `/build/metrics/record`

These endpoints are secured by:
- IP whitelisting
- Webhook secret validation
- Rate limiting

## JWT Token Structure

A JWT token contains the following claims:

```json
{
  "sub": "user_id",
  "name": "John Doe",
  "email": "john@example.com",
  "roles": ["admin", "developer"],
  "permissions": ["users.view", "infrastructure.manage"],
  "iat": 1645824000,
  "exp": 1645910400
}
```

## Rate Limiting

Different endpoints have different rate limits:

### Authentication
- WorkOS redirects: No rate limit
- WorkOS callbacks: 10 requests per minute

### Protected Endpoints
- General API: 100 requests per minute
- Resource-intensive operations (deployments, backups): 10 requests per minute

### Public Webhooks
- All webhook endpoints: 60 requests per minute

## Error Responses

### 401 Unauthorized
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Authentication required",
  "code": "UNAUTHORIZED"
}
```

### 403 Forbidden
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "Insufficient permissions",
  "code": "FORBIDDEN"
}
```

## Role-Based Access Control (RBAC)

Users are assigned roles and permissions through WorkOS integration:

### Default Roles
- **Super Admin**: Full system access
- **Admin**: System management and user management
- **Developer**: Development and deployment access
- **Operator**: Infrastructure operations access
- **Viewer**: Read-only access

### Common Permissions
- `users.view`: View user information
- `users.manage`: Manage users and roles
- `infrastructure.view`: View infrastructure
- `infrastructure.manage`: Manage infrastructure
- `deployments.create`: Create deployments
- `deployments.view`: View deployments

## SDK Authentication Examples

### JavaScript (fetch)
```javascript
// Get JWT token
const response = await fetch('/auth/workos/callback', {
  method: 'GET',
  credentials: 'include'
});
const data = await response.json();
const token = data.access_token;

// Use token for API requests
const apiResponse = await fetch('/api/user', {
  headers: {
    'Authorization': `Bearer ${token}`
  }
});
```

### Python (requests)
```python
# Get JWT token
response = requests.get('/auth/workos/callback', cookies={'session': session})
data = response.json()
token = data['access_token']

# Use token for API requests
headers = {'Authorization': f'Bearer {token}'}
api_response = requests.get('/api/user', headers=headers)
```

### cURL
```bash
# Get JWT token (browser or after login)
curl -i http://localhost:8000/api/auth/workos/redirect

# Use token for API requests
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     http://localhost:8000/api/user
```

## Security Best Practices

1. **Token Storage**: Store JWT tokens securely, preferably in HttpOnly cookies
2. **Token Refresh**: Implement token refresh logic before expiration
3. **HTTPS**: Always use HTTPS in production
4. **CORS**: Configure CORS policies appropriately
5. **Logout**: Use `/auth/workos/logout` to properly log out

## Authentication Troubleshooting

### Common Issues

1. **Invalid Token**
   - Verify the JWT format
   - Check token expiration
   - Ensure proper token storage

2. **Permission Denied**
   - Verify user roles and permissions
   - Check RBAC configuration
   - Ensure WorkOS mapping is correct

3. **Session Issues**
   - Clear browser cache and cookies
   - Re-authenticate with WorkOS
   - Verify session configuration

### Debug Information

To debug authentication issues, you can:

1. Check the current user:
```http
GET /api/user
```

2. Test WorkOS connection:
```http
GET /api/n8n/test-connection
```

3. View logs:
```bash
tail -f /var/log/nginx/error.log
tail -f /var/log/laravel.log
```
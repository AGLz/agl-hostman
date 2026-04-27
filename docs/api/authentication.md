# API Authentication Documentation

## Overview

The AGL Hostman API uses token-based authentication for secure access. All endpoints require authentication unless explicitly marked as public.

## Authentication Methods

### 1. JWT Token Authentication

Recommended for user-based authentication.

#### Flow

1. **Obtain JWT Token** via login endpoint
2. **Include token** in Authorization header
3. **Refresh token** before expiry

#### Login Endpoint

```http
POST /auth/login
Content-Type: application/json

{
  "email": "user@example.com",
  "password": "your-password"
}
```

#### Response

```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "Bearer",
  "expires_in": 7200,
  "refresh_token": "eyJ0eXAiOiJKV1QiLCJhbGc..."
}
```

#### Using JWT Token

```http
GET /api/containers
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc...
```

#### Code Examples

**PHP (Guzzle):**
```php
$client = new GuzzleHttp\Client(['base_uri' => 'https://api.agl-hostman.com/api']);

$response = $client->post('/auth/login', [
    'json' => [
        'email' => 'user@example.com',
        'password' => 'your-password'
    ]
]);

$data = json_decode($response->getBody(), true);
$token = $data['token'];

// Use token for subsequent requests
$response = $client->get('/containers', [
    'headers' => [
        'Authorization' => 'Bearer ' . $token
    ]
]);
```

**JavaScript (Fetch):**
```javascript
// Login
const loginResponse = await fetch('https://api.agl-hostman.com/api/auth/login', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json'
    },
    body: JSON.stringify({
        email: 'user@example.com',
        password: 'your-password'
    })
});

const { token } = await loginResponse.json();

// Use token for subsequent requests
const containersResponse = await fetch('https://api.agl-hostman.com/api/containers', {
    headers: {
        'Authorization': `Bearer ${token}`
    }
});

const containers = await containersResponse.json();
```

**Python (Requests):**
```python
import requests

# Login
login_response = requests.post(
    'https://api.agl-hostman.com/api/auth/login',
    json={
        'email': 'user@example.com',
        'password': 'your-password'
    }
)

token = login_response.json()['token']

# Use token for subsequent requests
headers = {
    'Authorization': f'Bearer {token}'
}

containers_response = requests.get(
    'https://api.agl-hostman.com/api/containers',
    headers=headers
)

containers = containers_response.json()
```

**cURL:**
```bash
# Login
TOKEN=$(curl -s -X POST https://api.agl-hostman.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"your-password"}' \
  | jq -r '.token')

# Use token
curl https://api.agl-hostman.com/api/containers \
  -H "Authorization: Bearer $TOKEN"
```

### 2. API Key Authentication

Recommended for service-to-service authentication.

#### Creating API Keys

```http
POST /api/api-keys
Authorization: Bearer <jwt-token>
Content-Type: application/json

{
  "name": "Production Monitoring",
  "abilities": ["read:containers", "read:metrics"],
  "expires_at": "2025-12-31T23:59:59Z"
}
```

#### Response

```json
{
  "id": "ak_1234567890abcdef",
  "name": "Production Monitoring",
  "key": "agl_prod_abc123xyz789...",
  "abilities": ["read:containers", "read:metrics"],
  "created_at": "2025-01-15T10:30:00Z",
  "expires_at": "2025-12-31T23:59:59Z"
}
```

**IMPORTANT:** Save the API key securely. It won't be shown again.

#### Using API Key

```http
GET /api/containers
Authorization: Bearer agl_prod_abc123xyz789...
```

#### Code Examples

**PHP (Guzzle):**
```php
$client = new GuzzleHttp\Client(['base_uri' => 'https://api.agl-hostman.com/api']);

$response = $client->get('/containers', [
    'headers' => [
        'Authorization' => 'Bearer agl_prod_abc123xyz789...'
    ]
]);
```

**JavaScript (Axios):**
```javascript
const axios = require('axios');

const client = axios.create({
    baseURL: 'https://api.agl-hostman.com/api',
    headers: {
        'Authorization': 'Bearer agl_prod_abc123xyz789...'
    }
});

const { data } = await client.get('/containers');
```

**Python (Requests):**
```python
import requests

headers = {
    'Authorization': 'Bearer agl_prod_abc123xyz789...'
}

response = requests.get(
    'https://api.agl-hostman.com/api/containers',
    headers=headers
)

containers = response.json()
```

### 3. WorkOS SSO Integration

For enterprise single sign-on.

#### Setup

1. Configure WorkOS in your environment variables:
```env
WORKOS_API_KEY=your_api_key
WORKOS_CLIENT_ID=your_client_id
WORKOS_REDIRECT_URI=https://your-app.com/auth/callback
```

2. Redirect users to WorkOS login:
```http
GET /auth/workos/redirect
```

3. Handle callback:
```http
GET /auth/workos/callback?code=auth_code_here
```

4. Receive JWT token

#### Code Example

**PHP:**
```php
use WorkOS\WorkOS;

$workos = new WorkOS(env('WORKOS_API_KEY'));

// Generate authorization URL
$authorizationUrl = $workos->getAuthorizationUrl(
    env('WORKOS_CLIENT_ID'),
    env('WORKOS_REDIRECT_URI'),
    ['profile', 'email']
);

header('Location: ' . $authorizationUrl);
exit;

// Handle callback
$code = $request->input('code');
$accessToken = $workos->getAccessToken($code);
$user = $workos->getUser($accessToken);
```

## Token Management

### Token Expiry

- **JWT Tokens:** 2 hours (7200 seconds)
- **API Keys:** Configurable, typically 1 year
- **Refresh Tokens:** 30 days

### Refreshing Tokens

```http
POST /auth/refresh
Authorization: Bearer <refresh_token>
```

#### Response

```json
{
  "token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "token_type": "Bearer",
  "expires_in": 7200
}
```

### Revoking Tokens

```http
POST /auth/logout
Authorization: Bearer <token>
```

```http
DELETE /api/api-keys/{id}
Authorization: Bearer <token>
```

## Permissions & Scopes

### User Roles

- **Admin:** Full access to all resources
- **Advanced:** Read/write access to containers and deployments
- **Common:** Read-only access to infrastructure

### API Key Abilities

Available abilities for API keys:

- `read:containers` - List and view containers
- `write:containers` - Create, modify, delete containers
- `read:deployments` - List and view deployments
- `write:deployments` - Create and manage deployments
- `read:metrics` - Access infrastructure metrics
- `read:alerts` - View monitoring alerts
- `write:alerts` - Create and manage alert rules
- `admin:*` - Full administrative access

#### Example API Key with Limited Scope

```json
{
  "name": "Read-Only Monitoring",
  "abilities": ["read:containers", "read:metrics", "read:alerts"],
  "ip_whitelist": ["192.168.1.100", "10.0.0.50"]
}
```

## Error Responses

### 401 Unauthorized

```json
{
  "error": "Unauthorized",
  "message": "Authentication required",
  "code": "UNAUTHORIZED"
}
```

**Solutions:**
- Verify token is included in Authorization header
- Check token hasn't expired
- Ensure token is valid (not revoked)

### 403 Forbidden

```json
{
  "error": "Forbidden",
  "message": "You don't have permission to access this resource",
  "code": "FORBIDDEN"
}
```

**Solutions:**
- Verify user has required role
- Check API key has required abilities
- Ensure resource belongs to user (if applicable)

## Security Best Practices

### 1. Token Storage

**✅ DO:**
- Store tokens in secure storage (localStorage, cookies with HttpOnly)
- Use environment variables for server-side tokens
- Implement token encryption in database

**❌ DON'T:**
- Store tokens in plain text
- Log tokens
- Include tokens in URLs
- Hardcode tokens in source code

### 2. Token Transmission

**✅ DO:**
- Always use HTTPS
- Include token in Authorization header
- Implement token rotation

**❌ DON'T:**
- Send tokens in query parameters
- Send tokens in request body
- Use HTTP (non-secure)

### 3. Token Validation

**✅ DO:**
- Validate token signature
- Check token expiration
- Verify token issuer
- Implement token revocation

**❌ DON'T:**
- Accept tokens without validation
- Ignore token expiry
- Skip revocation checks

### 4. Rate Limiting

- **Standard users:** 100 requests/minute
- **API keys:** 1000 requests/minute
- **Exceeded:** 429 Too Many Requests response

**Implement exponential backoff:**

```javascript
async function fetchWithRetry(url, options, retries = 3) {
    for (let i = 0; i < retries; i++) {
        const response = await fetch(url, options);

        if (response.status !== 429) return response;

        const waitTime = Math.pow(2, i) * 1000; // 1s, 2s, 4s
        await new Promise(resolve => setTimeout(resolve, waitTime));
    }

    throw new Error('Max retries exceeded');
}
```

## Troubleshooting

### Common Issues

#### 1. "Token has expired"

**Cause:** Token validity period exceeded

**Solution:** Refresh token using refresh endpoint
```http
POST /auth/refresh
Authorization: Bearer <refresh_token>
```

#### 2. "Invalid token"

**Cause:** Token malformed or signature invalid

**Solution:** Verify token format and ensure it's not modified
```javascript
// JWT token should have 3 parts separated by dots
const tokenParts = token.split('.');
if (tokenParts.length !== 3) {
    throw new Error('Invalid token format');
}
```

#### 3. "Insufficient permissions"

**Cause:** User role or API key lacks required ability

**Solution:** Contact administrator to grant required permissions or use API key with broader scope

#### 4. "API key not found"

**Cause:** API key deleted or never created

**Solution:** Generate new API key from dashboard or API
```http
POST /api/api-keys
```

## Testing Authentication

### Test with cURL

```bash
# 1. Login and get token
TOKEN=$(curl -s -X POST https://api.agl-hostman.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password"}' \
  | jq -r '.token')

# 2. Test authenticated endpoint
curl https://api.agl-hostman.com/api/containers \
  -H "Authorization: Bearer $TOKEN"

# 3. Test refresh
curl -X POST https://api.agl-hostman.com/api/auth/refresh \
  -H "Authorization: Bearer $REFRESH_TOKEN"
```

### Test with Postman

1. **Create new request**
2. **Go to Authorization tab**
3. **Select "Bearer Token"**
4. **Enter token** in Token field
5. **Send request**

## Additional Resources

- [JWT.io](https://jwt.io/) - JWT debugger and documentation
- [OWASP Authentication Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)
- [WorkOS Documentation](https://workos.com/docs)

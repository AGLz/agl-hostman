# API Error Codes Reference

## Overview

This document provides a comprehensive reference for all error codes returned by the AGL Hostman API.

## Error Response Format

All error responses follow this format:

```json
{
  "error": "Error type",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "Additional context"
  }
}
```

## HTTP Status Codes

| Status | Description | Example Errors |
|--------|-------------|----------------|
| 200 | Success | Request completed successfully |
| 201 | Created | Resource created successfully |
| 400 | Bad Request | Invalid parameters, validation errors |
| 401 | Unauthorized | Missing or invalid authentication |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource does not exist |
| 409 | Conflict | Resource already exists, state conflict |
| 422 | Unprocessable Entity | Validation failed |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service temporarily unavailable |

## Error Codes by Category

### Authentication Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `UNAUTHORIZED` | 401 | Authentication required | Include valid Bearer token |
| `INVALID_TOKEN` | 401 | Token is invalid or malformed | Verify token format |
| `TOKEN_EXPIRED` | 401 | Token has expired | Refresh token |
| `REVOKED_TOKEN` | 401 | Token has been revoked | Obtain new token |
| `INVALID_API_KEY` | 401 | API key not found or invalid | Verify API key |
| `EXPIRED_API_KEY` | 401 | API key has expired | Generate new API key |
| `REVOKED_API_KEY` | 401 | API key has been revoked | Contact administrator |

**Example:**
```json
{
  "error": "Unauthorized",
  "message": "Token expired",
  "code": "TOKEN_EXPIRED"
}
```

### Authorization Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `FORBIDDEN` | 403 | Insufficient permissions | Verify user role/API key abilities |
| `ROLE_REQUIRED` | 403 | Specific role required | Upgrade user role |
| `ABILITY_REQUIRED` | 403 | Specific ability required | Add ability to API key |
| `RESOURCE_ACCESS_DENIED` | 403 | Access to resource denied | Verify resource ownership |
| `OPERATION_NOT_ALLOWED` | 403 | Operation not permitted | Check if operation is allowed for current state |

**Example:**
```json
{
  "error": "Forbidden",
  "message": "You need 'admin' role to perform this action",
  "code": "ROLE_REQUIRED",
  "details": {
    "required_role": "admin",
    "current_role": "common"
  }
}
```

### Validation Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `VALIDATION_ERROR` | 422 | General validation failed | Check request parameters |
| `REQUIRED_FIELD` | 422 | Required field missing | Include required field |
| `INVALID_FORMAT` | 422 | Field format invalid | Correct field format |
| `INVALID_TYPE` | 422 | Field type incorrect | Use correct data type |
| `OUT_OF_RANGE` | 422 | Value outside allowed range | Use value within range |
| `INVALID_ENUM` | 422 | Invalid enum value | Use valid enum value |
| `DUPLICATE_ENTRY` | 409 | Resource already exists | Use different identifier |

**Example:**
```json
{
  "error": "Validation Error",
  "message": "The given data was invalid.",
  "code": "VALIDATION_ERROR",
  "details": {
    "hostname": [
      "The hostname field is required.",
      "The hostname format is invalid."
    ],
    "vmid": [
      "The vmid must be between 100 and 999999."
    ]
  }
}
```

### Container Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `CONTAINER_NOT_FOUND` | 404 | Container does not exist | Verify VMID |
| `CONTAINER_ALREADY_RUNNING` | 409 | Container is already running | Stop before starting again |
| `CONTAINER_ALREADY_STOPPED` | 409 | Container is already stopped | Start before stopping again |
| `CONTAINER_OPERATION_FAILED` | 500 | Container operation failed | Check container logs |
| `INSUFFICIENT_RESOURCES` | 503 | Not enough resources to create container | Free up resources or use different node |
| `TEMPLATE_NOT_FOUND` | 404 | OS template not found | Verify template path |
| `CONTAINER_LOCKED` | 409 | Container is locked | Wait for lock to release |
| `MAX_CONTAINERS_REACHED` | 503 | Maximum container limit reached | Delete unused containers |

**Example:**
```json
{
  "error": "Container Not Found",
  "message": "Container with VMID 999 does not exist",
  "code": "CONTAINER_NOT_FOUND",
  "details": {
    "vmid": 999,
    "node": "pve1"
  }
}
```

### Deployment Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `DEPLOYMENT_NOT_FOUND` | 404 | Deployment does not exist | Verify deployment ID |
| `INVALID_ENVIRONMENT` | 400 | Invalid environment specified | Use valid environment (dev/qa/uat/production) |
| `PROMOTION_NOT_ALLOWED` | 403 | Cannot promote to target environment | Check promotion eligibility |
| `DEPLOYMENT_FAILED` | 500 | Deployment operation failed | Check deployment logs |
| `HEALTH_CHECK_FAILED` | 503 | Post-deployment health check failed | Fix application issues |
| `ROLLBACK_FAILED` | 500 | Rollback operation failed | Manual intervention required |
| `BUILD_IN_PROGRESS` | 409 | Build already in progress | Wait for current build to complete |
| `INVALID_VERSION` | 400 | Invalid version format | Use semantic versioning (v1.2.3) |

**Example:**
```json
{
  "error": "Promotion Not Allowed",
  "message": "Cannot promote deployment with failed tests",
  "code": "PROMOTION_NOT_ALLOWED",
  "details": {
    "deployment_id": "550e8400-e29b-41d4-a716-446655440000",
    "current_environment": "qa",
    "target_environment": "production",
    "reason": "Automated tests failed"
  }
}
```

### Infrastructure Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `SERVER_NOT_FOUND` | 404 | Server does not exist | Verify server name |
| `SERVER_OFFLINE` | 503 | Server is offline | Start server or wait for recovery |
| `SERVER_DEGRADED` | 503 | Server is in degraded state | Check server health |
| `CONNECTION_FAILED` | 503 | Cannot connect to server | Verify network connectivity |
| `TIMEOUT` | 504 | Operation timed out | Retry operation or increase timeout |
| `PROXMOX_API_ERROR` | 500 | Proxmox API error | Check Proxmox logs |
| `PROXMOX_AUTH_FAILED` | 503 | Proxmox authentication failed | Verify Proxmox credentials |

**Example:**
```json
{
  "error": "Server Offline",
  "message": "Server 'AGLSRV1' is currently offline",
  "code": "SERVER_OFFLINE",
  "details": {
    "server": "AGLSRV1",
    "last_seen": "2025-01-15T10:15:00Z",
    "status": "offline"
  }
}
```

### Backup Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `BACKUP_NOT_FOUND` | 404 | Backup does not exist | Verify backup ID |
| `BACKUP_IN_PROGRESS` | 409 | Backup already in progress | Wait for current backup to complete |
| `RESTORE_FAILED` | 500 | Restore operation failed | Check backup integrity |
| `INSUFFICIENT_STORAGE` | 503 | Not enough storage for backup | Free up storage space |
| `BACKUP_STORAGE_ERROR` | 500 | Backup storage error | Verify storage configuration |
| `CORRUPTED_BACKUP` | 500 | Backup file is corrupted | Use different backup |

**Example:**
```json
{
  "error": "Backup Not Found",
  "message": "Backup with ID 'backup_123' not found",
  "code": "BACKUP_NOT_FOUND",
  "details": {
    "backup_id": "backup_123",
    "vmid": 105
  }
}
```

### Rate Limiting Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `RATE_LIMIT_EXCEEDED` | 429 | Too many requests | Wait and retry with exponential backoff |

**Example:**
```json
{
  "error": "Rate Limit Exceeded",
  "message": "Too many requests. Maximum 100 requests per minute.",
  "code": "RATE_LIMIT_EXCEEDED",
  "details": {
    "limit": 100,
    "remaining": 0,
    "reset_at": "2025-01-15T11:00:00Z"
  }
}
```

### Monitoring & Alert Errors

| Code | HTTP | Description | Solution |
|------|------|-------------|----------|
| `ALERT_RULE_NOT_FOUND` | 404 | Alert rule does not exist | Verify alert rule ID |
| `INVALID_METRIC` | 400 | Invalid metric specified | Use valid metric name |
| `INVALID_CONDITION` | 400 | Invalid alert condition | Use valid condition operator |
| `THRESHOLD_OUT_OF_RANGE` | 400 | Threshold value out of range | Use appropriate threshold |
| `METRICS_UNAVAILABLE` | 503 | Metrics temporarily unavailable | Retry later |

**Example:**
```json
{
  "error": "Invalid Metric",
  "message": "Metric 'invalid_metric' does not exist",
  "code": "INVALID_METRIC",
  "details": {
    "provided_metric": "invalid_metric",
    "available_metrics": ["cpu", "memory", "disk", "network"]
  }
}
```

## Common Error Patterns

### 1. Validation Error Pattern

```json
{
  "error": "Validation Error",
  "message": "The given data was invalid.",
  "code": "VALIDATION_ERROR",
  "details": {
    "field_name": [
      "Error message 1",
      "Error message 2"
    ]
  }
}
```

### 2. Not Found Pattern

```json
{
  "error": "Resource Not Found",
  "message": "Resource 'X' not found",
  "code": "RESOURCE_NOT_FOUND",
  "details": {
    "resource_type": "container",
    "resource_id": "999"
  }
}
```

### 3. Conflict Pattern

```json
{
  "error": "Resource Conflict",
  "message": "Resource already exists or operation conflicts with current state",
  "code": "RESOURCE_CONFLICT",
  "details": {
    "conflict_reason": "Container with VMID 105 already exists",
    "existing_resource_id": "105"
  }
}
```

## Handling Errors in Code

### PHP

```php
try {
    $response = $client->get('/containers/999');
} catch (GuzzleHttp\Exception\ClientException $e) {
    $error = json_decode($e->getResponse()->getBody(), true);

    switch ($error['code']) {
        case 'CONTAINER_NOT_FOUND':
            echo "Container not found";
            break;
        case 'UNAUTHORIZED':
            echo "Authentication failed";
            break;
        default:
            echo "Error: " . $error['message'];
    }
}
```

### JavaScript

```javascript
try {
    const response = await fetch('/api/containers/999');

    if (!response.ok) {
        const error = await response.json();

        switch (error.code) {
            case 'CONTAINER_NOT_FOUND':
                console.error('Container not found');
                break;
            case 'UNAUTHORIZED':
                console.error('Authentication failed');
                break;
            default:
                console.error('Error:', error.message);
        }
    }
} catch (error) {
    console.error('Network error:', error);
}
```

### Python

```python
import requests

try:
    response = requests.get('/api/containers/999')
    response.raise_for_status()
except requests.exceptions.HTTPError as e:
    error = e.response.json()

    if error['code'] == 'CONTAINER_NOT_FOUND':
        print('Container not found')
    elif error['code'] == 'UNAUTHORIZED':
        print('Authentication failed')
    else:
        print(f'Error: {error["message"]}')
except requests.exceptions.RequestException as e:
    print(f'Network error: {e}')
```

## Error Recovery Strategies

### 1. Retry with Exponential Backoff

For transient errors (5xx, timeouts, rate limits):

```python
import time
import random

def fetch_with_retry(url, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = requests.get(url)
            response.raise_for_status()
            return response
        except requests.exceptions.HTTPError as e:
            if e.response.status_code in [500, 502, 503, 504, 429]:
                if attempt < max_retries - 1:
                    wait_time = (2 ** attempt) + random.random()
                    time.sleep(wait_time)
                    continue
            raise
```

### 2. Token Refresh

For authentication errors:

```javascript
async function fetchWithAuthRefresh(url, options) {
    let response = await fetch(url, options);

    if (response.status === 401) {
        // Refresh token
        const newToken = await refreshAccessToken();

        // Retry with new token
        options.headers.Authorization = `Bearer ${newToken}`;
        response = await fetch(url, options);
    }

    return response;
}
```

### 3. Graceful Degradation

For service unavailable errors:

```javascript
async function getContainerMetrics(vmid) {
    try {
        const response = await fetch(`/api/containers/${vmid}/metrics`);
        return await response.json();
    } catch (error) {
        if (error.code === 'METRICS_UNAVAILABLE') {
            // Return cached metrics or default values
            return getCachedMetrics(vmid);
        }
        throw error;
    }
}
```

## Testing Error Handling

### cURL Examples

```bash
# Test 404 Not Found
curl https://api.agl-hostman.com/api/containers/999

# Test 401 Unauthorized
curl https://api.agl-hostman.com/api/containers

# Test 429 Rate Limit
for i in {1..150}; do
    curl https://api.agl-hostman.com/api/containers
done

# Test Validation Error
curl -X POST https://api.agl-hostman.com/api/containers/create \
  -H "Content-Type: application/json" \
  -d '{"vmid": "invalid"}'
```

## Monitoring Errors

### Log Analysis

Monitor error rates and patterns:

```javascript
// Example error tracking
function trackError(error) {
    analytics.track('api_error', {
        code: error.code,
        status: error.status,
        endpoint: error.endpoint,
        user_id: getUserId(),
        timestamp: Date.now()
    });
}
```

### Alerting

Set up alerts for critical errors:

- `UNAUTHORIZED` > 10% of requests
- `RATE_LIMIT_EXCEEDED` > 5% of requests
- 5xx errors > 1% of requests
- Any error code > 10% of requests

## Additional Resources

- [HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status)
- [REST API Error Handling Best Practices](https://restfulapi.net/http-status-codes/)
- [OWASP Error Handling](https://cheatsheetseries.owasp.org/cheatsheets/Error_Handling_Cheat_Sheet.html)

# AGL Hostman API Error Codes Reference

This document provides a comprehensive reference for all error codes that may be returned by the AGL Hostman API.

## Error Response Format

All API errors follow this consistent format:

```json
{
  "success": false,
  "error": "ERROR_TYPE",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {
    "field": "Specific field if validation error",
    "constraint": "Validation constraint"
  }
}
```

## Authentication Errors

### 401 Unauthorized
**Code**: `UNAUTHORIZED`

Returned when authentication is required but not provided or invalid.

**Details**: None

**Example**:
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Authentication required",
  "code": "UNAUTHORIZED"
}
```

### 401 Token Expired
**Code**: `TOKEN_EXPIRED`

Returned when the JWT token has expired.

**Details**: None

**Example**:
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Token has expired",
  "code": "TOKEN_EXPIRED"
}
```

### 403 Forbidden
**Code**: `FORBIDDEN`

Returned when authentication is valid but insufficient permissions for the requested action.

**Details**:
- `required_permission`: The permission required for this action
- `user_permissions`: Array of permissions the user actually has

**Example**:
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "Insufficient permissions",
  "code": "FORBIDDEN",
  "details": {
    "required_permission": "infrastructure.manage",
    "user_permissions": ["infrastructure.view"]
  }
}
```

### 429 Rate Limit Exceeded
**Code**: `RATE_LIMIT_EXCEEDED`

Returned when too many requests are made within the time window.

**Details**:
- `limit`: The rate limit that was exceeded
- `window`: Time window (in seconds)
- `retry_after`: Seconds until the limit resets

**Example**:
```json
{
  "success": false,
  "error": "Too Many Requests",
  "message": "Rate limit exceeded",
  "code": "RATE_LIMIT_EXCEEDED",
  "details": {
    "limit": 100,
    "window": 60,
    "retry_after": 30
  }
}
```

## Validation Errors

### 400 Bad Request - Validation Error
**Code**: `VALIDATION_ERROR`

Returned when request data fails validation.

**Details**:
- `errors`: Array of validation errors with field messages

**Example**:
```json
{
  "success": false,
  "error": "Bad Request",
  "message": "The given data was invalid",
  "code": "VALIDATION_ERROR",
  "details": {
    "errors": {
      "name": ["The name field is required"],
      "email": ["The email must be a valid email address"]
    }
  }
}
```

### 422 Unprocessable Entity
**Code**: `UNPROCESSABLE_ENTITY`

Returned for more complex validation failures.

**Details**:
- `type`: Type of validation error
- `field`: Specific field that failed
- `value`: Invalid value provided
- `constraint`: Specific constraint that failed

**Example**:
```json
{
  "success": false,
  "error": "Unprocessable Entity",
  "message": "Validation failed",
  "code": "UNPROCESSABLE_ENTITY",
  "details": {
    "type": "invalid_enum_value",
    "field": "status",
    "value": "invalid_status",
    "constraint": "Must be one of: todo, in_progress, done"
  }
}
```

## Resource Not Found Errors

### 404 Not Found
**Code**: `NOT_FOUND`

Returned when the requested resource doesn't exist.

**Details**:
- `resource_type`: Type of resource (e.g., "workflow", "container")
- `resource_id`: ID of the requested resource

**Example**:
```json
{
  "success": false,
  "error": "Not Found",
  "message": "Resource not found",
  "code": "NOT_FOUND",
  "details": {
    "resource_type": "workflow",
    "resource_id": "non-existent-workflow"
  }
}
```

### 404 Parent Resource Not Found
**Code**: `PARENT_RESOURCE_NOT_FOUND`

Returned when a parent resource in a nested route doesn't exist.

**Details**:
- `parent_type`: Type of parent resource
- `parent_id`: ID of parent resource

**Example**:
```json
{
  "success": false,
  "error": "Not Found",
  "message": "Parent resource not found",
  "code": "PARENT_RESOURCE_NOT_FOUND",
  "details": {
    "parent_type": "project",
    "parent_id": "non-existent-project"
  }
}
```

## Business Logic Errors

### 409 Conflict
**Code**: `CONFLICT`

Returned when there's a conflict with the current state of the resource.

**Details**:
- `conflict_type`: Type of conflict
- `message`: Detailed explanation of the conflict

**Example**:
```json
{
  "success": false,
  "error": "Conflict",
  "message": "Resource already exists",
  "code": "CONFLICT",
  "details": {
    "conflict_type": "resource_exists",
    "message": "A container with this name already exists"
  }
}
```

### 400 Invalid State
**Code**: `INVALID_STATE`

Returned when an operation is performed on a resource in an invalid state.

**Details**:
- `current_state`: Current state of the resource
- `required_state`: Required state for the operation
- `operation`: Operation being attempted

**Example**:
```json
{
  "success": false,
  "error": "Bad Request",
  "message": "Cannot perform operation in current state",
  "code": "INVALID_STATE",
  "details": {
    "current_state": "stopped",
    "required_state": "running",
    "operation": "backup"
  }
}
```

### 400 Insufficient Resources
**Code**: `INSUFFICIENT_RESOURCES`

Returned when there aren't enough resources to complete the operation.

**Details**:
- `required`: Required resources
- `available`: Available resources
- `resource_type`: Type of resource (CPU, memory, disk, etc.)

**Example**:
```json
{
  "success": false,
  "error": "Bad Request",
  "message": "Insufficient resources",
  "code": "INSUFFICIENT_RESOURCES",
  "details": {
    "required": {
      "cpu": 4,
      "memory": 8192
    },
    "available": {
      "cpu": 2,
      "memory": 4096
    },
    "resource_type": "compute"
  }
}
```

## System Errors

### 500 Internal Server Error
**Code**: `INTERNAL_SERVER_ERROR`

Returned for unexpected server errors.

**Details**:
- `error_id`: Unique identifier for the error
- `error_class`: Exception class name (if available)
- `timestamp`: When the error occurred

**Example**:
```json
{
  "success": false,
  "error": "Internal Server Error",
  "message": "An unexpected error occurred",
  "code": "INTERNAL_SERVER_ERROR",
  "details": {
    "error_id": "ERR-123456",
    "error_class": "App\\Exceptions\\InfrastructureException",
    "timestamp": "2024-02-11T10:30:00Z"
  }
}
```

### 503 Service Unavailable
**Code**: `SERVICE_UNAVAILABLE`

Returned when a dependent service is unavailable.

**Details**:
- `service_name`: Name of the unavailable service
- `retry_after`: Recommended time to retry (seconds)

**Example**:
```json
{
  "success": false,
  "error": "Service Unavailable",
  "message": "Dependency service unavailable",
  "code": "SERVICE_UNAVAILABLE",
  "details": {
    "service_name": "Harbor Registry",
    "retry_after": 300
  }
}
```

### 502 Bad Gateway
**Code**: `BAD_GATEWAY`

Returned when a proxy request to an external service fails.

**Details**:
- `target_service`: Service that failed
- `http_status`: HTTP status code from the target service
- `response_body`: Partial response from target service (if available)

**Example**:
```json
{
  "success": false,
  "error": "Bad Gateway",
  "message": "External service request failed",
  "code": "BAD_GATEWAY",
  "details": {
    "target_service": "WorkOS",
    "http_status": 503,
    "response_body": "Service Temporarily Unavailable"
  }
}
```

## Integration Errors

### 504 Gateway Timeout
**Code**: `GATEWAY_TIMEOUT`

Returned when an external service takes too long to respond.

**Details**:
- `service`: Name of the timed-out service
- `timeout_seconds`: Request timeout value

**Example**:
```json
{
  "success": false,
  "error": "Gateway Timeout",
  "message": "Request timeout",
  "code": "GATEWAY_TIMEOUT",
  "details": {
    "service": "N8N API",
    "timeout_seconds": 30
  }
}
```

### 400 External Service Error
**Code**: `EXTERNAL_SERVICE_ERROR`

Returned when an external service returns an error.

**Details**:
- `service_name`: Name of the external service
- `service_error`: Error from the external service
- `service_code`: Error code from the external service

**Example**:
```json
{
  "success": false,
  "error": "External Service Error",
  "message": "Harbor API returned an error",
  "code": "EXTERNAL_SERVICE_ERROR",
  "details": {
    "service_name": "Harbor Registry",
    "service_error": "Project name already exists",
    "service_code": "409"
  }
}
```

## Database Errors

### 500 Database Connection Error
**Code**: `DATABASE_CONNECTION_ERROR`

Returned when unable to connect to the database.

**Details**:
- `connection_string`: Connection string (sanitized)
- `error_message`: Database error message

**Example**:
```json
{
  "success": false,
  "error": "Internal Server Error",
  "message": "Database connection failed",
  "code": "DATABASE_CONNECTION_ERROR",
  "details": {
    "connection_string": "mysql://***:***@localhost:3306/hostman",
    "error_message": "Connection refused"
  }
}
```

### 500 Database Query Error
**Code**: `DATABASE_QUERY_ERROR`

Returned when a database query fails.

**Details**:
- `query_type`: Type of query (select, insert, update, delete)
- `table_name**: Table involved in the query
- `error_message**: Database error message

**Example**:
```json
{
  "success": false,
  "error": "Internal Server Error",
  "message": "Database query failed",
  "code": "DATABASE_QUERY_ERROR",
  "details": {
    "query_type": "insert",
    "table_name": "n8n_workflows",
    "error_message": "Duplicate entry 'workflow-1' for key 'slug'"
  }
}
```

## Webhook Error Codes

### 400 Invalid Webhook Signature
**Code**: `INVALID_WEBHOOK_SIGNATURE`

Returned when webhook signature validation fails.

**Details**:
- `signature_header`: The signature header received
- `expected_signature`: The expected signature

**Example**:
```json
{
  "success": false,
  "error": "Bad Request",
  "message": "Invalid webhook signature",
  "code": "INVALID_WEBHOOK_SIGNATURE",
  "details": {
    "signature_header": "sha256=abc123",
    "expected_signature": "sha256=def456"
  }
}
```

### 400 Invalid Webhook Payload
**Code**: `INVALID_WEBHOOK_PAYLOAD`

Returned when webhook payload is invalid or malformed.

**Details**:
- `error_type`: Type of error (e.g., "json_parse_error")
- `details`: Additional error details

**Example**:
```json
{
  "success": false,
  "error": "Bad Request",
  "message": "Invalid webhook payload",
  "code": "INVALID_WEBHOOK_PAYLOAD",
  "details": {
    "error_type": "json_parse_error",
    "details": "Syntax error"
  }
}
```

### 415 Unsupported Media Type
**Code**: `UNSUPPORTED_MEDIA_TYPE`

Returned when webhook sends unsupported content type.

**Details**:
- `content_type`: Received content type
- `supported_types`: List of supported content types

**Example**:
```json
{
  "success": false,
  "error": "Unsupported Media Type",
  "message": "Unsupported content type",
  "code": "UNSUPPORTED_MEDIA_TYPE",
  "details": {
    "content_type": "text/plain",
    "supported_types": ["application/json"]
  }
}
```

## Error Handling Best Practices

### 1. Always Check for Errors
```bash
# Check HTTP status code
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "test"}')

if [ "$response" -eq 201 ]; then
  echo "Container created successfully"
else
  echo "Request failed with status $response"
fi
```

### 2. Parse Error Responses
```bash
# Get error details
error_response=$(curl -s -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"invalid": "data"}')

echo "Error response: $error_response"
```

### 3. Retry on Rate Limit
```bash
# Retry with exponential backoff
retry_count=0
max_retries=3
retry_delay=1

while [ $retry_count -lt $max_retries ]; do
  response=$(curl -s -X POST "https://api.agl.hostman/api/deployment/qa/deploy" \
    -H "Authorization: Bearer $TOKEN" \
    -d '{"branch": "main"}')

  if echo "$response" | jq -e '.success' >/dev/null; then
    echo "Deployment successful"
    break
  else
    error_code=$(echo "$response" | jq -r '.code')
    if [ "$error_code" = "RATE_LIMIT_EXCEEDED" ]; then
      retry_after=$(echo "$response" | jq -r '.details.retry_after // 1')
      echo "Rate limited. Retrying in $retry_after seconds..."
      sleep $retry_after
      retry_count=$((retry_count + 1))
    else
      echo "Non-retryable error: $error_code"
      break
    fi
  fi
done
```

### 4. Log Errors for Debugging
```bash
# Log errors with timestamp
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
error_response=$(curl -s -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "test"}')

echo "[$timestamp] Error response: $error_response" >> /var/log/agl-hostman-api-errors.log
```

## Error Codes Quick Reference

| Status Code | Error Code | Description |
|------------|------------|-------------|
| 400 | VALIDATION_ERROR | Request data validation failed |
| 400 | INVALID_STATE | Resource in invalid state for operation |
| 400 | INSUFFICIENT_RESOURCES | Not enough resources available |
| 401 | UNAUTHORIZED | Authentication required |
| 401 | TOKEN_EXPIRED | JWT token has expired |
| 403 | FORBIDDEN | Insufficient permissions |
| 404 | NOT_FOUND | Resource not found |
| 409 | CONFLICT | Resource conflict |
| 413 | PAYLOAD_TOO_LARGE | Request payload too large |
| 422 | UNPROCESSABLE_ENTITY | Complex validation failure |
| 429 | RATE_LIMIT_EXCEEDED | Rate limit exceeded |
| 500 | INTERNAL_SERVER_ERROR | Unexpected server error |
| 502 | BAD_GATEWAY | External service error |
| 503 | SERVICE_UNAVAILABLE | Service temporarily unavailable |
| 504 | GATEWAY_TIMEOUT | External service timeout |

For more information about error handling and best practices, see the main API documentation.
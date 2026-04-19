# AGL Hostman API Quick Start Guide

## Introduction

The AGL Hostman API provides programmatic access to all infrastructure management capabilities including container lifecycle management, deployment pipelines, monitoring, and more.

This guide will help you get up and running quickly with the API.

## Quick Authentication

### 1. Get Access Token

```bash
# Redirect to WorkOS for authentication
curl -I https://api.agl.hostman/api/auth/workos/redirect

# Handle callback to get token (after WorkOS authentication)
curl "https://api.agl.hostman/api/auth/workos/callback?code=YOUR_AUTH_CODE"
```

### 2. Save Your Token

Save the returned access token for future requests:
```bash
export API_TOKEN="your_jwt_token_here"
```

## Basic API Usage

### Create Your First Container

```bash
curl -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{
    "name": "my-app",
    "template": "ubuntu-22.04",
    "config": {
      "cpu": 2,
      "memory": 4096,
      "disk": 50
    }
  }'
```

### List Your Infrastructure

```bash
curl -X GET "https://api.agl.hostman/api/infrastructure/locations" \
  -H "Authorization: Bearer $API_TOKEN"
```

### Deploy to QA Environment

```bash
curl -X POST "https://api.agl.hostman/api/deployment/qa/deploy" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{
    "branch": "main",
    "environment": {
      "variables": {
        "NODE_ENV": "production"
      }
    }
  }'
```

## API Explorer

### Interactive Documentation

The OpenAPI specification is available for interactive exploration:

1. **Swagger UI**: `https://api.agl.hostman/api-docs`
2. **ReDoc**: `https://api.agl.hostman/redoc`

### Common Operations

#### N8N Workflows
```bash
# List all workflows
curl -X GET "https://api.agl.hostman/api/n8n/workflows" \
  -H "Authorization: Bearer $API_TOKEN"

# Trigger a workflow
curl -X POST "https://api.agl.hostman/api/n8n/trigger/my-workflow" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"payload": {"action": "deploy"}}'
```

#### Container Management
```bash
# Create container
curl -X POST "https://api.agl.hostman/api/containers/create" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"name": "web-server", "template": "nginx"}'

# Backup container
curl -X POST "https://api.agl.hostman/api/containers/123/backup" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -d '{"description": "Pre-deployment backup"}'
```

#### Monitoring
```bash
# Get system health
curl -X GET "https://api.agl.hostman/api/monitoring/health" \
  -H "Authorization: Bearer $API_TOKEN"

# View alerts
curl -X GET "https://api.agl.hostman/api/monitoring/alerts" \
  -H "Authorization: Bearer $API_TOKEN"
```

## Sample Application

Here's a simple Node.js example to get you started:

```javascript
const axios = require('axios');

const API_BASE_URL = 'https://api.agl.hostman/api';
const API_TOKEN = process.env.API_TOKEN;

// Create axios instance with auth
const api = axios.create({
  baseURL: API_BASE_URL,
  headers: {
    'Authorization': `Bearer ${API_TOKEN}`,
    'Content-Type': 'application/json'
  }
});

// Get user profile
async function getUserProfile() {
  try {
    const response = await api.get('/user');
    console.log('User profile:', response.data);
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

// Deploy to QA
async function deployToQA(branch = 'main') {
  try {
    const response = await api.post('/deployment/qa/deploy', {
      branch,
      environment: {
        variables: {
          NODE_ENV: 'production',
          DEBUG: 'false'
        }
      }
    });
    console.log('Deployment initiated:', response.data);
    return response.data.deployment_id;
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

// Get deployment status
async function getDeploymentStatus(deploymentId) {
  try {
    const response = await api.get(`/deployment/qa/logs?deployment_id=${deploymentId}`);
    console.log('Deployment logs:', response.data);
  } catch (error) {
    console.error('Error:', error.response?.data || error.message);
  }
}

// Example usage
async function main() {
  await getUserProfile();
  const deploymentId = await deployToQA('feature/new-feature');
  if (deploymentId) {
    await getDeploymentStatus(deploymentId);
  }
}

main();
```

## Environment Variables

Set these environment variables for your API client:

```bash
# Required
export API_HOST=https://api.agl.hostman
export API_TOKEN=your_jwt_token

# Optional
export API_VERSION=v3.0
export TIMEOUT=30000  # milliseconds
export RETRY_COUNT=3
```

## Rate Limiting

The API implements rate limiting to ensure fair usage:

- **General API**: 100 requests/minute
- **Deployments**: 10 requests/minute
- **Webhooks**: 60 requests/minute

Handle rate limiting with exponential backoff:

```javascript
async function apiCallWithRetry(apiCall, retries = 3) {
  for (let i = 0; i < retries; i++) {
    try {
      return await apiCall();
    } catch (error) {
      if (error.response?.status === 429 && i < retries - 1) {
        const delay = Math.pow(2, i) * 1000;
        await new Promise(resolve => setTimeout(resolve, delay));
        continue;
      }
      throw error;
    }
  }
}
```

## Error Handling

### Common Error Codes

- `400 Bad Request`: Invalid request format
- `401 Unauthorized`: Authentication required
- `403 Forbidden`: Insufficient permissions
- `404 Not Found`: Resource not found
- `429 Too Many Requests`: Rate limit exceeded
- `500 Internal Server Error`: Server error

### Error Response Format

```json
{
  "success": false,
  "error": "Error type",
  "message": "Human-readable error message",
  "code": "ERROR_CODE",
  "details": {}
}
```

## Webhooks

### Receiving Webhooks

```javascript
const express = require('express');
const app = express();

// Webhook endpoint
app.post('/webhooks/github', express.json(), (req, res) => {
  console.log('GitHub webhook received:', req.body);
  res.status(200).send('OK');
});

app.listen(3000, () => {
  console.log('Webhook server listening on port 3000');
});
```

### Sending Webhooks

Use the public endpoints to send notifications:

```bash
# Send deployment webhook
curl -X POST "https://api.agl.hostman/api/webhooks/deployment" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "deployment_completed",
    "deployment_id": "123",
    "status": "success",
    "timestamp": "2024-02-11T10:30:00Z"
  }'
```

## Getting Help

- **Documentation**: https://docs.agl.hostman
- **API Explorer**: https://api.agl.hostman/api-docs
- **Support**: support@agl.hostman
- **Issues**: https://github.com/agl/hostman/issues

## Next Steps

1. Explore the full API documentation
2. Set up monitoring for your applications
3. Configure alert rules for critical events
4. Integrate with your CI/CD pipeline
5. Set up automated scaling policies
# API Usage Examples

This document provides practical code examples in multiple programming languages for common API operations.

## Table of Contents

1. [Authentication](#authentication)
2. [Container Operations](#container-operations)
3. [Deployment Management](#deployment-management)
4. [Infrastructure Monitoring](#infrastructure-monitoring)
5. [Error Handling](#error-handling)

## Authentication

### PHP

**Login and Get Token:**
```php
<?php

use GuzzleHttp\Client;
use GuzzleHttp\Exception\RequestException;

class HostmanClient
{
    private Client $client;
    private string $baseUrl;
    private ?string $token = null;

    public function __construct(string $baseUrl = 'https://api.agl-hostman.com/api')
    {
        $this->baseUrl = $baseUrl;
        $this->client = new Client(['base_uri' => $baseUrl]);
    }

    public function login(string $email, string $password): array
    {
        $response = $this->client->post('/auth/login', [
            'json' => [
                'email' => $email,
                'password' => $password
            ]
        ]);

        $data = json_decode($response->getBody(), true);
        $this->token = $data['token'];

        return $data;
    }

    public function get(string $endpoint, array $params = []): array
    {
        $response = $this->client->get($endpoint, [
            'headers' => $this->getAuthHeaders(),
            'query' => $params
        ]);

        return json_decode($response->getBody(), true);
    }

    public function post(string $endpoint, array $data = []): array
    {
        $response = $this->client->post($endpoint, [
            'headers' => $this->getAuthHeaders(),
            'json' => $data
        ]);

        return json_decode($response->getBody(), true);
    }

    private function getAuthHeaders(): array
    {
        return [
            'Authorization' => 'Bearer ' . $this->token,
            'Content-Type' => 'application/json'
        ];
    }
}

// Usage
$client = new HostmanClient();
$client->login('user@example.com', 'password');

$containers = $client->get('/containers');
print_r($containers);
```

### JavaScript (Node.js)

**Using Axios:**
```javascript
const axios = require('axios');

class HostmanClient {
    constructor(baseUrl = 'https://api.agl-hostman.com/api') {
        this.baseUrl = baseUrl;
        this.token = null;
        this.client = axios.create({
            baseURL: baseUrl
        });
    }

    async login(email, password) {
        const response = await this.client.post('/auth/login', {
            email,
            password
        });

        this.token = response.data.token;
        return response.data;
    }

    async get(endpoint, params = {}) {
        const response = await this.client.get(endpoint, {
            params,
            headers: this.getAuthHeaders()
        });

        return response.data;
    }

    async post(endpoint, data = {}) {
        const response = await this.client.post(endpoint, data, {
            headers: this.getAuthHeaders()
        });

        return response.data;
    }

    getAuthHeaders() {
        return {
            'Authorization': `Bearer ${this.token}`,
            'Content-Type': 'application/json'
        };
    }
}

// Usage
(async () => {
    const client = new HostmanClient();
    await client.login('user@example.com', 'password');

    const containers = await client.get('/containers');
    console.log(containers);
})();
```

### Python

**Using Requests:**
```python
import requests
from typing import Optional, Dict, Any

class HostmanClient:
    def __init__(self, base_url: str = 'https://api.agl-hostman.com/api'):
        self.base_url = base_url
        self.token: Optional[str] = None
        self.session = requests.Session()

    def login(self, email: str, password: str) -> Dict[str, Any]:
        response = self.session.post(f'{self.base_url}/auth/login', json={
            'email': email,
            'password': password
        })

        response.raise_for_status()
        data = response.json()
        self.token = data['token']

        return data

    def get(self, endpoint: str, params: Optional[Dict] = None) -> Dict[str, Any]:
        response = self.session.get(
            f'{self.base_url}{endpoint}',
            params=params,
            headers=self._get_auth_headers()
        )

        response.raise_for_status()
        return response.json()

    def post(self, endpoint: str, data: Optional[Dict] = None) -> Dict[str, Any]:
        response = self.session.post(
            f'{self.base_url}{endpoint}',
            json=data,
            headers=self._get_auth_headers()
        )

        response.raise_for_status()
        return response.json()

    def _get_auth_headers(self) -> Dict[str, str]:
        return {
            'Authorization': f'Bearer {self.token}',
            'Content-Type': 'application/json'
        }

# Usage
client = HostmanClient()
client.login('user@example.com', 'password')

containers = client.get('/containers')
print(containers)
```

### Go

**Using net/http:**
```go
package main

import (
    "bytes"
    "encoding/json"
    "fmt"
    "io"
    "net/http"
)

type HostmanClient struct {
    BaseURL string
    Token   string
    Client  *http.Client
}

type LoginResponse struct {
    Token string `json:"token"`
}

func NewClient(baseURL string) *HostmanClient {
    return &HostmanClient{
        BaseURL: baseURL,
        Client:  &http.Client{},
    }
}

func (c *HostmanClient) Login(email, password string) (*LoginResponse, error) {
    payload := map[string]string{
        "email":    email,
        "password": password,
    }

    body, _ := json.Marshal(payload)
    req, _ := http.NewRequest("POST", c.BaseURL+"/auth/login", bytes.NewBuffer(body))
    req.Header.Set("Content-Type", "application/json")

    resp, err := c.Client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    var loginResp LoginResponse
    if err := json.NewDecoder(resp.Body).Decode(&loginResp); err != nil {
        return nil, err
    }

    c.Token = loginResp.Token
    return &loginResp, nil
}

func (c *HostmanClient) Get(endpoint string) (map[string]interface{}, error) {
    req, _ := http.NewRequest("GET", c.BaseURL+endpoint, nil)
    req.Header.Set("Authorization", "Bearer "+c.Token)

    resp, err := c.Client.Do(req)
    if err != nil {
        return nil, err
    }
    defer resp.Body.Close()

    var result map[string]interface{}
    if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
        return nil, err
    }

    return result, nil
}

func main() {
    client := NewClient("https://api.agl-hostman.com/api")
    client.Login("user@example.com", "password")

    containers, _ := client.Get("/containers")
    fmt.Println(containers)
}
```

## Container Operations

### List Containers

**PHP:**
```php
// Get all containers
$containers = $client->get('/containers');

// Filter by status
$runningContainers = $client->get('/containers', [
    'status' => 'running',
    'limit' => 10
]);

// Filter by server
$serverContainers = $client->get('/containers', [
    'server' => 'fgsrv6',
    'limit' => 50
]);
```

**JavaScript:**
```javascript
// Get all containers
const containers = await client.get('/containers');

// Filter by status
const runningContainers = await client.get('/containers', {
    status: 'running',
    limit: 10
});

// Filter by server
const serverContainers = await client.get('/containers', {
    server: 'fgsrv6',
    limit: 50
});
```

**Python:**
```python
# Get all containers
containers = client.get('/containers')

# Filter by status
running_containers = client.get('/containers', params={
    'status': 'running',
    'limit': 10
})

# Filter by server
server_containers = client.get('/containers', params={
    'server': 'fgsrv6',
    'limit': 50
})
```

### Create Container

**PHP:**
```php
$newContainer = $client->post('/containers/create', [
    'node' => 'pve1',
    'vmid' => 105,
    'hostname' => 'app-container',
    'ostemplate' => 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
    'cores' => 2,
    'memory' => 2048,
    'rootfs' => 'local-zfs:32',
    'net0' => 'name=eth0,bridge=vmbr0,ip=dhcp',
    'unprivileged' => true,
    'start' => true
]);

print_r($newContainer);
```

**JavaScript:**
```javascript
const newContainer = await client.post('/containers/create', {
    node: 'pve1',
    vmid: 105,
    hostname: 'app-container',
    ostemplate: 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
    cores: 2,
    memory: 2048,
    rootfs: 'local-zfs:32',
    net0: 'name=eth0,bridge=vmbr0,ip=dhcp',
    unprivileged: true,
    start: true
});

console.log(newContainer);
```

**Python:**
```python
new_container = client.post('/containers/create', {
    'node': 'pve1',
    'vmid': 105,
    'hostname': 'app-container',
    'ostemplate': 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst',
    'cores': 2,
    'memory': 2048,
    'rootfs': 'local-zfs:32',
    'net0': 'name=eth0,bridge=vmbr0,ip=dhcp',
    'unprivileged': True,
    'start': True
})

print(new_container)
```

### Start/Stop Container

**PHP:**
```php
// Start container
$result = $client->post("/containers/{$vmid}/start", [
    'force' => false
]);

// Stop container
$result = $client->post("/containers/{$vmid}/stop", [
    'force' => false
]);

// Restart container
$result = $client->post("/containers/{$vmid}/restart");
```

**JavaScript:**
```javascript
// Start container
const result = await client.post(`/containers/${vmid}/start`, {
    force: false
});

// Stop container
const result = await client.post(`/containers/${vmid}/stop`, {
    force: false
});

// Restart container
const result = await client.post(`/containers/${vmid}/restart`);
```

**Python:**
```python
# Start container
result = client.post(f'/containers/{vmid}/start', {
    'force': False
})

# Stop container
result = client.post(f'/containers/{vmid}/stop', {
    'force': False
})

# Restart container
result = client.post(f'/containers/{vmid}/restart')
```

### Get Container Metrics

**PHP:**
```php
$metrics = $client->get("/containers/{$vmid}/metrics");

print_r($metrics);
// Output:
// [
//     'vmid' => 105,
//     'cpu' => ['usage_percent' => 15.5, 'cores' => 2],
//     'memory' => ['used_mb' => 1024, 'total_mb' => 2048, 'usage_percent' => 50.0],
//     'disk' => ['used_gb' => 16, 'total_gb' => 32, 'usage_percent' => 50.0],
//     'network' => ['in_mb' => 1024, 'out_mb' => 2048],
//     'processes' => 42
// ]
```

**JavaScript:**
```javascript
const metrics = await client.get(`/containers/${vmid}/metrics`);

console.log(metrics);
// Output:
// {
//     vmid: 105,
//     cpu: { usage_percent: 15.5, cores: 2 },
//     memory: { used_mb: 1024, total_mb: 2048, usage_percent: 50.0 },
//     disk: { used_gb: 16, total_gb: 32, usage_percent: 50.0 },
//     network: { in_mb: 1024, out_mb: 2048 },
//     processes: 42
// }
```

**Python:**
```python
metrics = client.get(f'/containers/{vmid}/metrics')

print(metrics)
# Output:
# {
#     'vmid': 105,
#     'cpu': {'usage_percent': 15.5, 'cores': 2},
#     'memory': {'used_mb': 1024, 'total_mb': 2048, 'usage_percent': 50.0},
#     'disk': {'used_gb': 16, 'total_gb': 32, 'usage_percent': 50.0},
#     'network': {'in_mb': 1024, 'out_mb': 2048},
#     'processes': 42
# }
```

## Deployment Management

### List Deployments

**PHP:**
```php
$deployments = $client->get('/deployments');

// Filter by environment
$prodDeployments = $client->get('/deployments', [
    'environment' => 'production'
]);

// Filter by status
$failedDeployments = $client->get('/deployments', [
    'status' => 'failed'
]);
```

**JavaScript:**
```javascript
const deployments = await client.get('/deployments');

// Filter by environment
const prodDeployments = await client.get('/deployments', {
    environment: 'production'
});

// Filter by status
const failedDeployments = await client.get('/deployments', {
    status: 'failed'
});
```

### Promote Deployment

**PHP:**
```php
$promotion = $client->post("/deployments/{$deploymentId}/promote", [
    'environment' => 'production',
    'auto_approve' => false
]);

print_r($promotion);
```

**JavaScript:**
```javascript
const promotion = await client.post(`/deployments/${deploymentId}/promote`, {
    environment: 'production',
    auto_approve: false
});

console.log(promotion);
```

**Python:**
```python
promotion = client.post(f'/deployments/{deployment_id}/promote', {
    'environment': 'production',
    'auto_approve': False
})

print(promotion)
```

## Infrastructure Monitoring

### Get Infrastructure Status

**PHP:**
```php
$status = $client->get('/infrastructure/status');

print_r($status);
// Output:
// [
//     'servers' => [
//         ['name' => 'AGLSRV1', 'status' => 'online', 'cpu_usage' => 45.2, ...],
//         ['name' => 'AGLSRV2', 'status' => 'online', 'cpu_usage' => 32.1, ...]
//     ],
//     'summary' => [
//         'total_servers' => 6,
//         'online_servers' => 5,
//         'health_score' => 92.5
//     ]
// ]
```

**JavaScript:**
```javascript
const status = await client.get('/infrastructure/status');

console.log(status);
// Output:
// {
//     servers: [
//         {name: 'AGLSRV1', status: 'online', cpu_usage: 45.2, ...},
//         {name: 'AGLSRV2', status: 'online', cpu_usage: 32.1, ...}
//     ],
//     summary: {
//         total_servers: 6,
//         online_servers: 5,
//         health_score: 92.5
//     }
// }
```

### Get System Metrics

**PHP:**
```php
$metrics = $client->get('/infrastructure/metrics', [
    'server' => 'AGLSRV1',
    'period' => '1h',
    'metric' => 'cpu'
]);

print_r($metrics);
```

**JavaScript:**
```javascript
const metrics = await client.get('/infrastructure/metrics', {
    server: 'AGLSRV1',
    period: '1h',
    metric: 'cpu'
});

console.log(metrics);
```

### List Alerts

**PHP:**
```php
// Get all alerts
$alerts = $client->get('/monitoring/alerts');

// Filter by severity
$criticalAlerts = $client->get('/monitoring/alerts', [
    'severity' => 'critical',
    'status' => 'active'
]);

print_r($criticalAlerts);
```

**JavaScript:**
```javascript
// Get all alerts
const alerts = await client.get('/monitoring/alerts');

// Filter by severity
const criticalAlerts = await client.get('/monitoring/alerts', {
    severity: 'critical',
    status: 'active'
});

console.log(criticalAlerts);
```

### Create Alert Rule

**PHP:**
```php
$rule = $client->post('/monitoring/alerts', [
    'name' => 'High CPU Alert',
    'metric' => 'cpu_usage',
    'condition' => 'greater_than',
    'threshold' => 90.0,
    'severity' => 'critical',
    'duration' => 300
]);

print_r($rule);
```

**JavaScript:**
```javascript
const rule = await client.post('/monitoring/alerts', {
    name: 'High CPU Alert',
    metric: 'cpu_usage',
    condition: 'greater_than',
    threshold: 90.0,
    severity: 'critical',
    duration: 300
});

console.log(rule);
```

**Python:**
```python
rule = client.post('/monitoring/alerts', {
    'name': 'High CPU Alert',
    'metric': 'cpu_usage',
    'condition': 'greater_than',
    'threshold': 90.0,
    'severity': 'critical',
    'duration': 300
})

print(rule)
```

## Error Handling

### PHP

```php
try {
    $container = $client->get("/containers/{$vmid}");
} catch (RequestException $e) {
    $statusCode = $e->getResponse()->getStatusCode();
    $error = json_decode($e->getResponse()->getBody(), true);

    switch ($error['code']) {
        case 'CONTAINER_NOT_FOUND':
            echo "Container not found\n";
            break;
        case 'UNAUTHORIZED':
            echo "Authentication failed\n";
            break;
        case 'RATE_LIMIT_EXCEEDED':
            echo "Rate limit exceeded, waiting...\n";
            sleep(60);
            break;
        default:
            echo "Error: {$error['message']}\n";
    }
}
```

### JavaScript

```javascript
try {
    const container = await client.get(`/containers/${vmid}`);
} catch (error) {
    if (error.response) {
        const statusCode = error.response.status;
        const errorCode = error.response.data.code;

        switch (errorCode) {
            case 'CONTAINER_NOT_FOUND':
                console.log('Container not found');
                break;
            case 'UNAUTHORIZED':
                console.log('Authentication failed');
                break;
            case 'RATE_LIMIT_EXCEEDED':
                console.log('Rate limit exceeded, waiting...');
                await new Promise(resolve => setTimeout(resolve, 60000));
                break;
            default:
                console.log(`Error: ${error.response.data.message}`);
        }
    }
}
```

### Python

```python
try:
    container = client.get(f'/containers/{vmid}')
except requests.exceptions.HTTPError as e:
    error = e.response.json()

    match error['code']:
        case 'CONTAINER_NOT_FOUND':
            print('Container not found')
        case 'UNAUTHORIZED':
            print('Authentication failed')
        case 'RATE_LIMIT_EXCEEDED':
            print('Rate limit exceeded, waiting...')
            time.sleep(60)
        case _:
            print(f"Error: {error['message']}")
```

## Complete Examples

### Example 1: Automated Container Health Check

**PHP:**
```php
<?php

function checkContainerHealth(HostmanClient $client, array $vmids): array
{
    $results = [];

    foreach ($vmids as $vmid) {
        try {
            $container = $client->get("/containers/{$vmid}");
            $metrics = $client->get("/containers/{$vmid}/metrics");

            $healthy = (
                $container['status'] === 'running' &&
                $metrics['cpu']['usage_percent'] < 90 &&
                $metrics['memory']['usage_percent'] < 90
            );

            $results[$vmid] = [
                'healthy' => $healthy,
                'status' => $container['status'],
                'cpu' => $metrics['cpu']['usage_percent'],
                'memory' => $metrics['memory']['usage_percent']
            ];
        } catch (Exception $e) {
            $results[$vmid] = [
                'healthy' => false,
                'error' => $e->getMessage()
            ];
        }
    }

    return $results;
}

// Usage
$client = new HostmanClient();
$client->login('user@example.com', 'password');

$vmids = [105, 106, 107, 108];
$healthResults = checkContainerHealth($client, $vmids);

print_r($healthResults);
```

### Example 2: Deployment Pipeline

**JavaScript:**
```javascript
async function deployToProduction(client, deploymentId) {
    try {
        // 1. Check deployment status
        const deployment = await client.get(`/deployments/${deploymentId}`);

        if (deployment.status !== 'success') {
            throw new Error('Deployment must succeed before promoting to production');
        }

        // 2. Promote to production
        console.log('Promoting to production...');
        const promotion = await client.post(`/deployments/${deploymentId}/promote`, {
            environment: 'production'
        });

        // 3. Wait for deployment to complete
        while (true) {
            const status = await client.get(`/deployments/${deploymentId}/status`);

            if (status.status === 'success') {
                console.log('✅ Deployment successful!');
                break;
            } else if (status.status === 'failed') {
                console.log('❌ Deployment failed!');
                throw new Error('Deployment failed');
            }

            console.log(`⏳ Deployment in progress: ${status.progress}%`);
            await new Promise(resolve => setTimeout(resolve, 5000));
        }

        return promotion;
    } catch (error) {
        console.error('Deployment error:', error.message);
        throw error;
    }
}

// Usage
const client = new HostmanClient();
await client.login('user@example.com', 'password');

await deployToProduction(client, 'deployment-123');
```

### Example 3: Monitoring Alerts Dashboard

**Python:**
```python
import asyncio
from datetime import datetime, timedelta

class MonitoringDashboard:
    def __init__(self, client):
        self.client = client

    async def get_critical_alerts(self):
        """Get all active critical alerts from the last hour"""
        since = (datetime.now() - timedelta(hours=1)).isoformat()

        alerts = self.client.get('/monitoring/alerts', params={
            'severity': 'critical',
            'status': 'active'
        })

        # Filter alerts from the last hour
        recent_alerts = [
            alert for alert in alerts['data']
            if datetime.fromisoformat(alert['created_at']) > datetime.fromisoformat(since)
        ]

        return recent_alerts

    async def get_infrastructure_health(self):
        """Get overall infrastructure health score"""
        status = self.client.get('/infrastructure/status')
        return status['summary']['health_score']

    async def generate_report(self):
        """Generate monitoring report"""
        critical_alerts = await self.get_critical_alerts()
        health_score = await self.get_infrastructure_health()

        report = {
            'timestamp': datetime.now().isoformat(),
            'health_score': health_score,
            'critical_alerts_count': len(critical_alerts),
            'critical_alerts': critical_alerts,
            'status': 'healthy' if health_score > 80 else 'degraded'
        }

        return report

# Usage
import asyncio

client = HostmanClient()
client.login('user@example.com', 'password')

dashboard = MonitoringDashboard(client)
report = asyncio.run(dashboard.generate_report())

print(f"Health Score: {report['health_score']}")
print(f"Critical Alerts: {report['critical_alerts_count']}")
print(f"Status: {report['status']}")
```

## Testing Examples

### Unit Tests (PHP with Pest)

```php
<?php

use Tests\TestCase;

class HostmanClientTest extends TestCase
{
    private HostmanClient $client;

    protected function setUp(): void
    {
        parent::setUp();
        $this->client = new HostmanClient('https://api.agl-hostman.com/api');
        $this->client->login('test@example.com', 'password');
    }

    public function test_get_containers()
    {
        $containers = $this->client->get('/containers');

        expect($containers)->toBeArray();
        expect($containers['data'])->toBeArray();
    }

    public function test_get_container_by_id()
    {
        $container = $this->client->get('/containers/105');

        expect($container['vmid'])->toBe(105);
        expect($container)->toHaveKey('status');
    }

    public function test_container_not_found()
    {
        $this->expectException(RequestException::class);

        $this->client->get('/containers/999');
    }
}
```

### Unit Tests (Python with pytest)

```python
import pytest
import requests

class TestHostmanClient:
    @pytest.fixture
    def client(self):
        client = HostmanClient()
        client.login('test@example.com', 'password')
        return client

    def test_get_containers(self, client):
        containers = client.get('/containers')

        assert isinstance(containers, dict)
        assert 'data' in containers

    def test_get_container_by_id(self, client):
        container = client.get('/containers/105')

        assert container['vmid'] == 105
        assert 'status' in container

    def test_container_not_found(self, client):
        with pytest.raises(requests.exceptions.HTTPError) as exc:
            client.get('/containers/999')

        assert exc.value.response.status_code == 404
```

## cURL Examples

```bash
# Login
curl -X POST https://api.agl-hostman.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'

# List containers
curl https://api.agl-hostman.com/api/containers \
  -H "Authorization: Bearer YOUR_TOKEN"

# Get container details
curl https://api.agl-hostman.com/api/containers/105 \
  -H "Authorization: Bearer YOUR_TOKEN"

# Start container
curl -X POST https://api.agl-hostman.com/api/containers/105/start \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"force":false}'

# Create container
curl -X POST https://api.agl-hostman.com/api/containers/create \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "node":"pve1",
    "vmid":105,
    "hostname":"app-container",
    "cores":2,
    "memory":2048
  }'
```

## Additional Resources

- [OpenAPI Specification](/docs/api/openapi.yaml)
- [Authentication Guide](/docs/api/authentication.md)
- [Error Codes](/docs/api/error-codes.md)
- [Rate Limiting](/docs/api/rate-limiting.md)

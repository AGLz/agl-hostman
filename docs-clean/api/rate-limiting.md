# API Rate Limiting Documentation

## Overview

The AGL Hostman API implements rate limiting to ensure fair usage and system stability for all users.

## Rate Limits

### By Authentication Type

| Auth Type | Rate Limit | Window |
|-----------|------------|--------|
| Standard User (JWT) | 100 requests | per minute |
| API Key | 1,000 requests | per minute |
| Enterprise | 10,000 requests | per minute |

### By Endpoint Category

| Category | Standard | API Key |
|----------|----------|---------|
| **Read Operations** | | |
| GET /containers | 100/min | 1,000/min |
| GET /infrastructure/* | 100/min | 1,000/min |
| GET /monitoring/* | 100/min | 1,000/min |
| **Write Operations** | | |
| POST /containers/* | 50/min | 500/min |
| POST /deployments/* | 30/min | 300/min |
| DELETE /* | 20/min | 200/min |

## Rate Limit Headers

All API responses include rate limit information in headers:

```http
HTTP/1.1 200 OK
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 87
X-RateLimit-Reset: 1642294560
```

### Header Descriptions

| Header | Description | Example |
|--------|-------------|---------|
| `X-RateLimit-Limit` | Maximum requests per window | `100` |
| `X-RateLimit-Remaining` | Remaining requests in current window | `87` |
| `X-RateLimit-Reset` | Unix timestamp when window resets | `1642294560` |

## Rate Limit Exceeded Response

When rate limit is exceeded:

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 45
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 0
X-RateLimit-Reset: 1642294560

{
  "error": "Rate Limit Exceeded",
  "message": "Too many requests. Maximum 100 requests per minute.",
  "code": "RATE_LIMIT_EXCEEDED",
  "details": {
    "limit": 100,
    "remaining": 0,
    "reset_at": "2025-01-15T11:00:00Z",
    "retry_after": 45
  }
}
```

## Best Practices

### 1. Implement Exponential Backoff

When receiving 429 responses, implement exponential backoff:

**JavaScript:**
```javascript
async function fetchWithBackoff(url, options, maxRetries = 3) {
    for (let attempt = 0; attempt < maxRetries; attempt++) {
        const response = await fetch(url, options);

        if (response.status !== 429) {
            return response;
        }

        // Extract retry-after from headers or use exponential backoff
        const retryAfter = parseInt(response.headers.get('Retry-After')) ||
                          Math.pow(2, attempt);

        await new Promise(resolve => setTimeout(resolve, retryAfter * 1000));
    }

    throw new Error('Max retries exceeded due to rate limiting');
}

// Usage
const response = await fetchWithBackoff('https://api.agl-hostman.com/api/containers');
```

**Python:**
```python
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

def create_session_with_retries():
    session = requests.Session()

    # Configure retry strategy
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,  # Sleep 1, 2, 4 seconds between retries
        status_forcelist=[429],
        allowed_methods=["GET", "POST", "PUT", "DELETE"]
    )

    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("https://", adapter)
    session.mount("http://", adapter)

    return session

# Usage
session = create_session_with_retries()
response = session.get('https://api.agl-hostman.com/api/containers')
```

**PHP:**
```php
use GuzzleHttp\Client;
use GuzzleHttp\Exception\RequestException;
use GuzzleHttp\HandlerStack;
use GuzzleHttp\Middleware;

function createClientWithRetry(): Client {
    $stack = HandlerStack::create();

    $stack->push(Middleware::retry(
        function ($retries, $request, $response, $exception) {
            // Retry on 429 status codes
            return $response && $response->getStatusCode() === 429 && $retries < 3;
        },
        function ($retries) {
            // Exponential backoff: 1s, 2s, 4s
            return 1000 * pow(2, $retries);
        }
    ));

    return new Client(['handler' => $stack]);
}

// Usage
$client = createClientWithRetry();
$response = $client->get('https://api.agl-hostman.com/api/containers');
```

### 2. Monitor Rate Limits

Track rate limits to avoid hitting them:

**JavaScript:**
```javascript
class RateLimitAwareClient {
    constructor(baseURL, apiKey) {
        this.baseURL = baseURL;
        this.apiKey = apiKey;
        this.rateLimits = {
            limit: 100,
            remaining: 100,
            reset: null
        };
    }

    async request(endpoint, options = {}) {
        // Check if we're close to rate limit
        if (this.rateLimits.remaining < 10) {
            const waitTime = this.rateLimits.reset * 1000 - Date.now();
            if (waitTime > 0) {
                console.log(`Rate limit imminent, waiting ${waitTime}ms`);
                await new Promise(resolve => setTimeout(resolve, waitTime));
            }
        }

        const response = await fetch(`${this.baseURL}${endpoint}`, {
            ...options,
            headers: {
                ...options.headers,
                'Authorization': `Bearer ${this.apiKey}`
            }
        });

        // Update rate limit info from headers
        this.updateRateLimits(response.headers);

        return response;
    }

    updateRateLimits(headers) {
        this.rateLimits = {
            limit: parseInt(headers.get('X-RateLimit-Limit')) || this.rateLimits.limit,
            remaining: parseInt(headers.get('X-RateLimit-Remaining')) || this.rateLimits.remaining,
            reset: parseInt(headers.get('X-RateLimit-Reset')) || this.rateLimits.reset
        };
    }

    getRemainingRequests() {
        return this.rateLimits.remaining;
    }

    getTimeUntilReset() {
        if (!this.rateLimits.reset) return null;
        const resetTime = this.rateLimits.reset * 1000;
        return Math.max(0, resetTime - Date.now());
    }
}

// Usage
const client = new RateLimitAwareClient('https://api.agl-hostman.com/api', 'your-api-key');

console.log(`Remaining: ${client.getRemainingRequests()}`);
console.log(`Reset in: ${client.getTimeUntilReset()}ms`);

const response = await client.request('/containers');
```

**Python:**
```python
import time
import requests
from datetime import datetime

class RateLimitAwareClient:
    def __init__(self, base_url, api_key):
        self.base_url = base_url
        self.api_key = api_key
        self.rate_limits = {
            'limit': 100,
            'remaining': 100,
            'reset': None
        }
        self.session = requests.Session()
        self.session.headers.update({'Authorization': f'Bearer {api_key}'})

    def request(self, endpoint, **kwargs):
        # Check rate limits
        if self.rate_limits['remaining'] < 10:
            wait_time = self._get_time_until_reset()
            if wait_time > 0:
                print(f"Rate limit imminent, waiting {wait_time}s")
                time.sleep(wait_time)

        response = self.session.get(f"{self.base_url}{endpoint}", **kwargs)
        self._update_rate_limits(response.headers)

        return response

    def _update_rate_limits(self, headers):
        self.rate_limits = {
            'limit': int(headers.get('X-RateLimit-Limit', self.rate_limits['limit'])),
            'remaining': int(headers.get('X-RateLimit-Remaining', self.rate_limits['remaining'])),
            'reset': int(headers.get('X-RateLimit-Reset', self.rate_limits['reset']))
        }

    def _get_time_until_reset(self):
        if not self.rate_limits['reset']:
            return 0
        reset_time = datetime.fromtimestamp(self.rate_limits['reset'])
        return max(0, (reset_time - datetime.now()).total_seconds())

    def get_remaining_requests(self):
        return self.rate_limits['remaining']

    def get_time_until_reset(self):
        return self._get_time_until_reset()

# Usage
client = RateLimitAwareClient('https://api.agl-hostman.com/api', 'your-api-key')

print(f"Remaining: {client.get_remaining_requests()}")
print(f"Reset in: {client.get_time_until_reset()}s")

response = client.request('/containers')
```

### 3. Request Batching

Group multiple requests into batches to reduce rate limit impact:

```javascript
async function batchRequest(items, batchSize, delay) {
    const results = [];

    for (let i = 0; i < items.length; i += batchSize) {
        const batch = items.slice(i, i + batchSize);

        // Process batch concurrently
        const batchResults = await Promise.all(
            batch.map(item => fetch(item.url, item.options))
        );

        results.push(...batchResults);

        // Wait before next batch
        if (i + batchSize < items.length) {
            await new Promise(resolve => setTimeout(resolve, delay));
        }
    }

    return results;
}

// Usage: Process 100 container IDs in batches of 10
const containerIds = Array.from({length: 100}, (_, i) => 100 + i);

const batches = containerIds.map(vmid => ({
    url: `https://api.agl-hostman.com/api/containers/${vmid}`,
    options: { headers: { 'Authorization': 'Bearer token' } }
}));

const results = await batchRequest(batches, 10, 1000); // 10 requests, 1s delay
```

### 4. Caching

Implement caching to reduce API calls:

```javascript
class CachedAPIClient {
    constructor(apiKey, ttl = 60000) { // 60 second cache
        this.cache = new Map();
        this.ttl = ttl;
        this.apiKey = apiKey;
    }

    async get(endpoint) {
        const cacheKey = endpoint;
        const cached = this.cache.get(cacheKey);

        // Return cached result if still valid
        if (cached && Date.now() - cached.timestamp < this.ttl) {
            console.log(`Cache HIT: ${endpoint}`);
            return cached.data;
        }

        console.log(`Cache MISS: ${endpoint}`);

        // Make API request
        const response = await fetch(`https://api.agl-hostman.com${endpoint}`, {
            headers: { 'Authorization': `Bearer ${this.apiKey}` }
        });

        const data = await response.json();

        // Cache result
        this.cache.set(cacheKey, {
            data,
            timestamp: Date.now()
        });

        return data;
    }

    clear() {
        this.cache.clear();
    }
}

// Usage
const client = new CachedAPIClient('your-api-key');

// First call - API request
const data1 = await client.get('/containers');

// Second call within 60s - from cache
const data2 = await client.get('/containers');
```

## Rate Limit Strategies by Use Case

### Web Applications

**Strategy:** Implement client-side rate limiting

```javascript
class RateLimitedQueue {
    constructor(ratePerMinute) {
        this.queue = [];
        this.ratePerMinute = ratePerMinute;
        this.processing = false;
    }

    async add(fn) {
        return new Promise((resolve, reject) => {
            this.queue.push({ fn, resolve, reject });
            this.process();
        });
    }

    async process() {
        if (this.processing || this.queue.length === 0) return;

        this.processing = true;

        while (this.queue.length > 0) {
            const { fn, resolve, reject } = this.queue.shift();

            try {
                const result = await fn();
                resolve(result);
            } catch (error) {
                reject(error);
            }

            // Wait to maintain rate limit
            const delay = 60000 / this.ratePerMinute;
            await new Promise(r => setTimeout(r, delay));
        }

        this.processing = false;
    }
}

// Usage
const queue = new RateLimitedQueue(100); // 100 requests per minute

for (let i = 0; i < 150; i++) {
    queue.add(() => fetch('/api/containers'))
        .then(response => console.log(`Request ${i} completed`));
}
```

### Background Jobs

**Strategy:** Implement throttling with pauses

```python
import time
import requests
from ratelimit import limits, sleep_and_retry

class APIClient:
    def __init__(self, api_key):
        self.api_key = api_key
        self.session = requests.Session()
        self.session.headers.update({'Authorization': f'Bearer {api_key}'})

    @sleep_and_retry
    @limits(calls=100, period=60)  # 100 calls per 60 seconds
    def get(self, endpoint):
        response = self.session.get(f'https://api.agl-hostman.com{endpoint}')
        response.raise_for_status()
        return response.json()

# Usage
client = APIClient('your-api-key')

for vmid in range(100, 200):
    try:
        container = client.get(f'/api/containers/{vmid}')
        print(f"Container {vmid}: {container['status']}")
    except requests.exceptions.HTTPError as e:
        if e.response.status_code == 429:
            print("Rate limit exceeded, waiting...")
            time.sleep(60)
        else:
            raise
```

### Data Sync

**Strategy:** Batch processing with progress tracking

```python
import time
import requests
from tqdm import tqdm

def sync_containers(api_key, container_ids, batch_size=10):
    """Sync containers in batches with rate limiting"""

    session = requests.Session()
    session.headers.update({'Authorization': f'Bearer {api_key}'})

    results = []

    for i in tqdm(range(0, len(container_ids), batch_size), desc="Syncing containers"):
        batch = container_ids[i:i + batch_size]

        # Process batch
        for vmid in batch:
            try:
                response = session.get(f'https://api.agl-hostman.com/api/containers/{vmid}')
                results.append(response.json())
            except requests.exceptions.HTTPError as e:
                if e.response.status_code == 429:
                    print("Rate limit hit, pausing...")
                    time.sleep(60)
                else:
                    raise

        # Wait between batches
        time.sleep(5)

    return results

# Usage
container_ids = list(range(100, 200))
results = sync_containers('your-api-key', container_ids, batch_size=10)
```

## Testing Rate Limiting

### Load Testing

**Artillery.js:**
```yaml
# config.yml
config:
  target: "https://api.agl-hostman.com"
  phases:
    - duration: 60
      arrivalRate: 2  # 2 requests per second = 120/min (will hit limit)
      name: "Sustained load"
scenarios:
  - flow:
      - get:
          url: "/api/containers"
          headers:
            Authorization: "Bearer your-token"
```

**k6:**
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
    stages: [
        { duration: '1m', target: 2 },   // Ramp up to 2 requests/sec
        { duration: '2m', target: 2 },   // Stay at 2 requests/sec
        { duration: '1m', target: 0 },   // Ramp down
    ],
};

export default function() {
    let headers = {
        'Authorization': 'Bearer your-token'
    };

    let response = http.get('https://api.agl-hostman.com/api/containers', { headers });

    check(response, {
        'status is 200': (r) => r.status === 200,
        'has rate limit headers': (r) => r.headers.hasOwnProperty('X-RateLimit-Limit'),
    });

    sleep(1);
}
```

## Monitoring Rate Limits

### Dashboard Metrics

Track these metrics:

1. **Rate Limit Hit Rate**
   ```
   (429 responses / total requests) * 100
   ```
   - Target: < 1%
   - Warning: > 5%
   - Critical: > 10%

2. **Average Requests Per Minute**
   - Monitor trends
   - Predict when limits will be hit

3. **Peak Usage Times**
   - Identify patterns
   - Schedule heavy operations accordingly

### Alerts

Set up alerts for:

- Rate limit hit rate > 5%
- Remaining requests < 10 for > 1 minute
- Sustained 429 errors

**Example Alert (Prometheus):**
```yaml
groups:
  - name: api_rate_limits
    rules:
      - alert: HighRateLimitHits
        expr: |
          (rate(http_requests_total{status="429"}[5m]) /
           rate(http_requests_total[5m])) > 0.05
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High rate limit hit rate"
          description: "Rate limit hit rate is {{ $value | humanizePercentage }}"
```

## Troubleshooting

### Issue: Frequent 429 Errors

**Diagnosis:**
```bash
# Check current rate limit status
curl -I https://api.agl-hostman.com/api/containers \
  -H "Authorization: Bearer your-token"
```

**Solutions:**
1. Reduce request frequency
2. Implement caching
3. Use batch processing
4. Upgrade to API key (higher limits)

### Issue: Inconsistent Rate Limits

**Diagnosis:**
- Check authentication type (JWT vs API key)
- Verify endpoint-specific limits
- Review current usage

**Solutions:**
- Use API key for higher limits
- Implement request queuing
- Distribute load across time

### Issue: Headers Not Present

**Diagnosis:**
```bash
curl -v https://api.agl-hostman.com/api/containers \
  -H "Authorization: Bearer your-token" 2>&1 | grep -i rate
```

**Solutions:**
- Verify authentication
- Check proxy configuration
- Ensure correct API endpoint

## Rate Limit Increase Requests

For higher rate limits:

1. **Contact support** at support@agl-hostman.com
2. **Provide information:**
   - Use case description
   - Current usage patterns
   - Expected request volume
   - Timeframe

3. **Enterprise plans** available:
   - 10,000 requests/minute
   - Dedicated rate limits
   - Priority support

## Best Practices Summary

✅ **DO:**
- Implement exponential backoff
- Monitor rate limit headers
- Use caching where appropriate
- Batch requests when possible
- Queue requests during high-volume periods
- Use API keys for higher limits

❌ **DON'T:**
- Ignore 429 responses
- Poll at high frequency
- Make redundant requests
- Remove authentication headers
- Exceed limits consistently

## Additional Resources

- [Rate Limiting Best Practices](https://docs.github.com/en/rest/overview/resources-in-the-rest-api#rate-limiting)
- [Exponential Backoff Algorithm](https://cloud.google.com/iot/docs/how-tos/exponential-backoff)
- [HTTP Caching](https://developer.mozilla.org/en-US/docs/Web/HTTP/Caching)

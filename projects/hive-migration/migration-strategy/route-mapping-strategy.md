# Route Mapping Strategy: API1 → API8

## Overview
Strategy for mapping and migrating all endpoints from API1 to API8 while maintaining backward compatibility.

## Migration Approaches

### Approach 1: Strangler Pattern (RECOMMENDED)
Gradually replace endpoints while maintaining old API functionality.

```
┌─────────────────┐
│   Nginx Proxy   │
│  api.falg.com.br │
└────────┬────────┘
         │
    ┌────┴─────┐
    ▼          ▼
┌──────┐   ┌──────┐
│ API1 │   │ API8 │
│ PHP74│   │ PHP81│
└──────┘   └──────┘
```

**Implementation:**
- Route mapping table in Nginx/HAProxy
- Gradual endpoint migration
- Fallback to API1 if API8 fails
- Session persistence during migration

**Advantages:**
- Low risk - incremental rollout
- Easy rollback per endpoint
- Can test in production with real traffic
- Time to fix issues

**Disadvantages:**
- Complex routing logic
- Longer migration timeline
- Requires careful coordination

### Approach 2: Shadow Traffic Pattern
Run both APIs in parallel, validate responses, but only serve from one.

```
                  ┌─────────────┐
                  │ Load Balancer│
                  └──────┬──────┘
                         │
        ┌────────────────┼────────────────┐
        │ Primary        │ Shadow         │
        ▼                ▼                │
    ┌──────┐         ┌──────┐            │
    │ API1 │         │ API8 │            │
    │ PHP74│         │ PHP81│            │
    └───┬──┘         └───┬──┘            │
        │                │                │
        │ Serve          │ Compare only   │
        ▼                ▼                │
    Response         Validation           │
```

**Implementation:**
- Duplicate traffic to API8
- Compare responses (checksums, structure)
- Log discrepancies
- Switch when confidence is high

**Advantages:**
- Real traffic validation
- No user impact during testing
- Comprehensive compatibility check
- Data-driven confidence

**Disadvantages:**
- 2x resource usage
- Complex comparison logic
- Delayed cutover

### Approach 3: Feature Flag Pattern
Single codebase with conditional execution.

```php
if (Config::get('use_php81_handler')) {
    return PHP81Handler::process($request);
} else {
    return PHP74Handler::process($request);
}
```

**Implementation:**
- Environment-based flags
- Per-user/session/percentage rollout
- A/B testing capability
- Quick rollback

**Advantages:**
- Fine-grained control
- Gradual user rollout
- Easy emergency rollback
- Good for testing

**Disadvantages:**
- Code duplication
- Increased complexity
- Harder to maintain
- Technical debt

### Approach 4: Blue-Green Deployment
Complete environment swap.

```
            ┌──────────────┐
            │DNS/Load Bal  │
            └──────┬───────┘
                   │
        ┌──────────┼──────────┐
        │ Switch   │           │
        ▼          ▼           │
    [BLUE]     [GREEN]         │
     API1       API8          │
    Active    Standby         │
                              │
    Cutover: Switch pointer   │
```

**Implementation:**
- API1 = Blue (current)
- API8 = Green (new)
- DNS/LB switch
- Instant rollback

**Advantages:**
- Clean cutover
- Easy rollback
- No complex routing
- Clear state

**Disadvantages:**
- Big bang risk
- All-or-nothing
- Requires duplicate resources
- One shot testing in prod

## Recommended Strategy: Hybrid Strangler + Shadow

### Phase 1: Shadow Traffic (Weeks 1-2)
- Deploy API8 in shadow mode
- Replicate 100% of API1 traffic to API8
- Compare responses and log differences
- Fix issues without user impact
- Build confidence metrics

### Phase 2: Strangler Migration (Weeks 3-6)
- Start with lowest-risk endpoints (GET, read-only)
- Route selection:
  - Migrate health checks and status endpoints first
  - Then read-only data endpoints
  - Then write endpoints (POST, PUT, DELETE)
  - Critical endpoints last
- Use feature flags per endpoint
- Monitor error rates and performance
- Rollback individual endpoints if needed

### Phase 3: Complete Cutover (Week 7)
- When all endpoints migrated and stable
- Switch default to API8
- Keep API1 as fallback for 2 weeks
- Monitor closely

### Phase 4: Decommission (Week 9+)
- Remove API1 from rotation
- Archive API1 codebase
- Update documentation

## Route Mapping Table Structure

```json
{
  "routes": [
    {
      "pattern": "/api/v1/users",
      "method": "GET",
      "api1_handler": "\\App\\Controllers\\UserController@index",
      "api8_handler": "\\App\\Http\\Controllers\\Api\\V1\\UserController@index",
      "status": "migrated|pending|in-progress|failed",
      "priority": "critical|high|medium|low",
      "dependencies": ["database.users", "cache.redis"],
      "backward_compatible": true,
      "migration_date": "2025-10-20",
      "rollback_trigger": "error_rate > 5%",
      "notes": "Uses legacy user format, needs transformation"
    }
  ]
}
```

## Nginx Configuration Strategy

### During Migration (Strangler Pattern)
```nginx
# /etc/nginx/sites-available/api.falg.com.br

upstream api1_backend {
    server 127.0.0.1:9074;  # PHP 7.4-FPM
}

upstream api8_backend {
    server 127.0.0.1:9081;  # PHP 8.1-FPM
}

# Route mapping based on migration status
map $request_uri $backend {
    default api1_backend;

    # Migrated endpoints go to API8
    ~^/api/v1/health api8_backend;
    ~^/api/v1/status api8_backend;
    ~^/api/v1/users/(?<id>\d+)$ api8_backend;

    # Add more as endpoints migrate...
}

server {
    listen 443 ssl http2;
    server_name api.falg.com.br;

    ssl_certificate /etc/ssl/certs/api.falg.com.br.crt;
    ssl_certificate_key /etc/ssl/private/api.falg.com.br.key;

    location / {
        proxy_pass http://$backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # Add migration tracking header
        add_header X-API-Backend $backend always;

        # Failover to API1 if API8 fails
        proxy_next_upstream error timeout http_500 http_502 http_503;
    }

    # Health check endpoints
    location /health {
        access_log off;
        proxy_pass http://api8_backend/health;
    }
}
```

### Post-Migration (API8 Only)
```nginx
upstream api8_backend {
    server 127.0.0.1:9081;
    keepalive 32;
}

server {
    listen 443 ssl http2;
    server_name api.falg.com.br;

    location / {
        proxy_pass http://api8_backend;
        # ... headers ...
    }
}

# Redirect to new endpoint if needed
server {
    listen 443 ssl http2;
    server_name api8.falg.com.br;

    return 301 https://api.falg.com.br$request_uri;
}
```

## Backward Compatibility Layer

### Response Format Compatibility
```php
namespace App\Compatibility;

class ResponseTransformer
{
    /**
     * Transform API8 response to API1 format if needed
     */
    public static function transformForV1(array $data, string $endpoint): array
    {
        return match($endpoint) {
            'users.index' => self::transformUsers($data),
            'orders.show' => self::transformOrder($data),
            default => $data
        };
    }

    private static function transformUsers(array $data): array
    {
        // API1 expects 'id' as string, API8 returns int
        return array_map(function($user) {
            return [
                'id' => (string) $user['id'],
                'name' => $user['name'],
                'email' => $user['email'],
                // Map new fields to old structure
                'created' => $user['created_at'] ?? null,
            ];
        }, $data);
    }
}
```

### Request Format Compatibility
```php
namespace App\Compatibility;

class RequestTransformer
{
    /**
     * Transform API1 request to API8 format
     */
    public static function transformFromV1(array $data, string $endpoint): array
    {
        return match($endpoint) {
            'users.store' => self::transformUserCreate($data),
            default => $data
        };
    }

    private static function transformUserCreate(array $data): array
    {
        return [
            'name' => $data['name'] ?? '',
            'email' => $data['email'] ?? '',
            'password' => $data['pwd'] ?? '',  // API1 uses 'pwd'
            'role' => $data['user_type'] ?? 'user',  // Field rename
        ];
    }
}
```

## Monitoring & Metrics

### Key Metrics to Track
1. **Error Rate**: Errors per endpoint (target: <1%)
2. **Response Time**: P50, P95, P99 latency
3. **Throughput**: Requests per second
4. **Success Rate**: 2xx responses percentage
5. **Backend Distribution**: % traffic to API1 vs API8

### Alerting Thresholds
```yaml
alerts:
  - name: high_error_rate
    condition: error_rate > 5%
    action: rollback_endpoint

  - name: slow_response
    condition: p95_latency > 2000ms
    action: alert_team

  - name: backend_failure
    condition: api8_5xx_rate > 10%
    action: fallback_to_api1
```

## Rollback Procedures

### Automatic Rollback
```nginx
# Circuit breaker pattern
location /api/v1/users {
    proxy_pass http://api8_backend;

    # Automatic fallback
    proxy_next_upstream error timeout http_500 http_502 http_503 http_504;
    proxy_next_upstream_tries 2;

    # If API8 fails, try API1
    error_page 500 502 503 504 = @fallback_api1;
}

location @fallback_api1 {
    proxy_pass http://api1_backend;
    add_header X-Fallback-Used "true" always;
}
```

### Manual Rollback
```bash
#!/bin/bash
# rollback-endpoint.sh

ENDPOINT=$1
REASON=$2

# Update Nginx route mapping
sed -i "s|~^${ENDPOINT} api8_backend;|# ROLLED BACK: ~^${ENDPOINT} api1_backend; # ${REASON}|" \
    /etc/nginx/sites-available/api.falg.com.br

# Reload Nginx
nginx -t && systemctl reload nginx

# Log to hive mind
echo "Rolled back endpoint: ${ENDPOINT} - Reason: ${REASON}" | \
    logger -t "api-migration"
```

## Testing Strategy

### Pre-Migration Testing
1. Syntax validation on PHP 8.1
2. Unit tests on both PHP versions
3. Integration tests with test database
4. Load testing in staging

### During Migration Testing
1. Shadow traffic comparison
2. Canary deployments (1%, 5%, 10%, 50%, 100%)
3. Synthetic monitoring
4. Real user monitoring

### Post-Migration Testing
1. Smoke tests on all endpoints
2. Regression test suite
3. Performance benchmarking
4. User acceptance testing

## Documentation Requirements

1. **Endpoint Inventory**: Complete list of all API1 endpoints
2. **Migration Status**: Real-time tracking dashboard
3. **Rollback Runbook**: Step-by-step procedures
4. **Incident Response**: On-call procedures
5. **Post-Mortem Template**: For any issues

---
*Status*: STRATEGY FRAMEWORK COMPLETE
*Next*: Awaiting Researcher's endpoint inventory from API1
*Required*: Analyst's risk assessment for each endpoint category

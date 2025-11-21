# WebSocket Quick Reference - Laravel Reverb

> **Quick commands and examples for AGL-HOSTMAN real-time monitoring**

---

## Server Management

```bash
# Start Reverb
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php artisan reverb:start --port=6001

# Background start
php artisan reverb:start --port=6001 > /tmp/reverb.log 2>&1 &

# Stop Reverb
pkill -f "reverb:start"

# Check status
ps aux | grep "reverb:start" | grep -v grep
ss -tlnp | grep :6001

# View logs
tail -f /tmp/reverb.log
```

---

## Backend Broadcasting

### Server Metrics
```php
use App\Events\ServerMetricsUpdated;

broadcast(new ServerMetricsUpdated(
    serverCode: 'AGLSRV1',
    cpuUsage: 45.7,
    memoryUsage: 62.3,
    containerCount: 68,
    status: 'online'
));
```

### Container Status
```php
use App\Events\ContainerStatusChanged;

broadcast(new ContainerStatusChanged(
    vmid: '179',
    name: 'agldv03',
    status: 'running',
    previousStatus: 'stopped',
    serverCode: 'AGLSRV1'
));
```

### Alerts
```php
use App\Events\AlertTriggered;

broadcast(new AlertTriggered(
    severity: 'critical',
    title: 'High CPU',
    message: 'CPU usage exceeded 80%',
    resourceType: 'server',
    resourceId: 'AGLSRV1'
));
```

---

## Frontend Hooks

### Server Metrics
```javascript
import { useServerMetrics } from '@/hooks/useWebSocket';

const { metrics, lastUpdate } = useServerMetrics('AGLSRV1', (data) => {
    console.log('CPU:', data.cpu_usage);
});

// Access metrics
{metrics?.cpu_usage}%
```

### Container Status
```javascript
import { useContainerStatus } from '@/hooks/useWebSocket';

const { status } = useContainerStatus('179', (data) => {
    console.log('Status:', data.status);
});

// Access status
{status?.status}
```

### Alerts
```javascript
import { useInfrastructureAlerts } from '@/hooks/useWebSocket';

const { alerts, clearAlerts } = useInfrastructureAlerts('critical', (alert) => {
    toast.error(alert.title);
});

// Render alerts
{alerts.map(alert => <Alert key={alert.timestamp} {...alert} />)}
```

### Connection State
```javascript
import { useWebSocket } from '@/hooks/useWebSocket';

const { isConnected, connectionState } = useWebSocket();

// Show indicator
{isConnected ? '🟢 Connected' : '🔴 Disconnected'}
```

---

## Testing

```bash
# Run test script
cd /mnt/overpower/apps/dev/agl/agl-hostman/src
php test-broadcast.php

# Expected output:
# ✓ Broadcasted to: infrastructure.server.AGLSRV1
# ✓ Broadcasted to: infrastructure.container.179
# ✓ Broadcasted to: infrastructure.alerts
```

---

## Environment Variables

```env
BROADCAST_CONNECTION=reverb
REDIS_HOST=127.0.0.1

REVERB_APP_ID=994451
REVERB_APP_KEY=ary2cav3jotrtq6bsbzs
REVERB_APP_SECRET=vdtbvszxk095nawix9ns
REVERB_HOST=localhost
REVERB_PORT=6001
REVERB_SCHEME=http
```

---

## Channels

| Channel | Purpose | Authorization |
|---------|---------|---------------|
| `infrastructure.server.{code}` | Server metrics | All users |
| `infrastructure.container.{vmid}` | Container status | All users |
| `infrastructure.alerts` | All alerts | All users |
| `infrastructure.alerts.critical` | Critical only | Admin/Advanced |

---

## Troubleshooting

```bash
# Check if Reverb is running
ps aux | grep reverb

# Check port
ss -tlnp | grep :6001

# Check Redis
redis-cli ping

# Clear config
php artisan config:clear

# Test connection
curl http://localhost:6001
```

---

## Performance Targets

| Metric | Target | Actual |
|--------|--------|--------|
| Latency | <100ms | 15-30ms ✅ |
| Connection | <200ms | ~50ms ✅ |
| Success Rate | 100% | 100% ✅ |

---

## Files

- **Setup Guide**: `/docs/WEBSOCKET-SETUP.md`
- **Implementation Report**: `/docs/WEBSOCKET-IMPLEMENTATION-REPORT.md`
- **Test Script**: `/src/test-broadcast.php`
- **Hooks**: `/src/resources/js/hooks/useWebSocket.js`
- **Examples**: `/src/resources/js/components/examples/`

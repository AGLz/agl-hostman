# WebSocket Events Documentation

## Overview

AGL Hostman uses Laravel Reverb for real-time WebSocket communication. This document describes all available events, channels, and how to use them.

## Configuration

### Broadcasting Driver

The application uses **Laravel Reverb** as the broadcasting driver. Configuration is in `config/broadcasting.php`:

```php
'default' => env('BROADCAST_CONNECTION', 'reverb'),
```

### Environment Variables

Required environment variables for WebSocket:

```env
BROADCAST_CONNECTION=reverb
REVERB_APP_ID=your-app-id
REVERB_APP_KEY=your-app-key
REVERB_APP_SECRET=your-app-secret
REVERB_HOST=localhost
REVERB_PORT=443
REVERB_SCHEME=https
```

## Available Events

### 1. ContainerStatusChanged

Broadcasts when a container's status changes (start, stop, crash, etc.).

**Event Name:** `container.status.changed`

**Channels:**
- `infrastructure.container.{vmid}` - Container-specific updates
- `infrastructure.server.{serverCode}` - Server-wide updates

**Payload:**
```json
{
  "vmid": "105",
  "name": "app-container",
  "status": "running",
  "previous_status": "stopped",
  "server_code": "fgsrv6",
  "metrics": {
    "cpu": 45.5,
    "memory": 67.2
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Example Usage (PHP):**
```php
use App\Events\ContainerStatusChanged;

ContainerStatusChanged::dispatch(
    vmid: '105',
    name: 'app-container',
    status: 'running',
    previousStatus: 'stopped',
    serverCode: 'fgsrv6',
    metrics: ['cpu' => 45.5, 'memory' => 67.2]
);
```

**Example Usage (JavaScript/Frontend):**
```javascript
Echo.channel(`infrastructure.container.${vmid}`)
    .listen('.container.status.changed', (e) => {
        console.log(`Container ${e.name} is now ${e.status}`);
        updateContainerStatus(e);
    });
```

### 2. AlertTriggered

Broadcasts when infrastructure alerts are triggered (CPU high, memory exhausted, container down, etc.).

**Event Name:** `alert.triggered`

**Channels:**
- `infrastructure.alerts` - All alerts
- `infrastructure.alerts.{severity}` - Severity-specific (critical, warning, info)

**Payload:**
```json
{
  "severity": "critical",
  "title": "Container Down",
  "message": "Container 105 has stopped unexpectedly",
  "resource_type": "container",
  "resource_id": "105",
  "metadata": {
    "restart_count": 3
  },
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Example Usage (PHP):**
```php
use App\Events\AlertTriggered;

AlertTriggered::dispatch(
    severity: 'critical',
    title: 'Container Down',
    message: 'Container 105 has stopped unexpectedly',
    resourceType: 'container',
    resourceId: '105',
    metadata: ['restart_count' => 3]
);
```

**Example Usage (JavaScript/Frontend):**
```javascript
Echo.channel('infrastructure.alerts')
    .listen('.alert.triggered', (e) => {
        showToast(e.severity, e.title, e.message);
    });
```

### 3. DeploymentProgressUpdated

Broadcasts real-time deployment progress updates.

**Event Name:** `deployment.progress.updated`

**Channels:**
- `deployments.{deploymentId}` - Deployment-specific updates
- `deployments.environment.{environment}` - Environment-wide updates

**Payload:**
```json
{
  "deployment_id": "deploy-123",
  "environment": "production",
  "status": "deploying",
  "progress": 45,
  "current_step": "Building container image",
  "details": {
    "image": "app:v1.2.3"
  },
  "errors": null,
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Example Usage (PHP):**
```php
use App\Events\DeploymentProgressUpdated;

DeploymentProgressUpdated::dispatch(
    deploymentId: 'deploy-123',
    environment: 'production',
    status: 'deploying',
    progress: 45,
    currentStep: 'Building container image',
    details: ['image' => 'app:v1.2.3']
);
```

**Example Usage (JavaScript/Frontend):**
```javascript
Echo.channel(`deployments.${deploymentId}`)
    .listen('.deployment.progress.updated', (e) => {
        updateProgressBar(e.progress);
        updateStatusText(e.current_step);
    });
```

### 4. SystemMetricsUpdated

Broadcasts overall infrastructure metrics and health status.

**Event Name:** `system.metrics.updated`

**Channel:** `system.monitoring`

**Payload:**
```json
{
  "servers": [
    {
      "code": "fgsrv6",
      "status": "healthy",
      "cpu": 45.5
    }
  ],
  "total_containers": 50,
  "running_containers": 45,
  "stopped_containers": 3,
  "error_containers": 2,
  "average_cpu_usage": 38.8,
  "average_memory_usage": 65.4,
  "overall_status": "healthy",
  "alerts": [],
  "timestamp": "2025-01-15T10:30:00Z"
}
```

**Example Usage (PHP):**
```php
use App\Events\SystemMetricsUpdated;

SystemMetricsUpdated::dispatch(
    servers: [['code' => 'fgsrv6', 'status' => 'healthy', 'cpu' => 45.5]],
    totalContainers: 50,
    runningContainers: 45,
    stoppedContainers: 3,
    errorContainers: 2,
    averageCpuUsage: 38.8,
    averageMemoryUsage: 65.4,
    overallStatus: 'healthy'
);
```

**Example Usage (JavaScript/Frontend):**
```javascript
Echo.channel('system.monitoring')
    .listen('.system.metrics.updated', (e) => {
        updateDashboardMetrics(e);
        updateOverallHealthStatus(e.overall_status);
    });
```

## Channel Authorization

Channels are authorized based on user roles:

### Infrastructure Channels
- **infrastructure.server.{serverCode}** - admin, advanced, common
- **infrastructure.container.{vmid}** - admin, advanced, common
- **infrastructure.alerts** - admin, advanced, common
- **infrastructure.alerts.critical** - admin, advanced only

### Deployment Channels
- **deployments.{deploymentId}** - admin, advanced, common
- **deployments.environment.{environment}** - admin, advanced, common

### System Channels
- **system.monitoring** - admin, advanced only

### User Channels
- **users.{id}.notifications** - User themselves only (must have verified email)

## Frontend Integration

### Installation

Install required dependencies:

```bash
npm install laravel-echo pusher-js
```

### Configuration

Configure Laravel Echo in `resources/js/bootstrap.js`:

```javascript
import Echo from 'laravel-echo';
import Pusher from 'pusher-js';

window.Pusher = Pusher;

window.Echo = new Echo({
    broadcaster: 'reverb',
    key: import.meta.env.MIX_REVERB_APP_KEY,
    wsHost: import.meta.env.MIX_REVERB_HOST,
    wsPort: import.meta.env.MIX_REVERB_PORT,
    wssPort: import.meta.env.MIX_REVERB_PORT,
    forceTLS: false,
    enabledTransports: ['ws', 'wss'],
});
```

### Example Component

```javascript
import { useEffect, useState } from 'react';
import Echo from 'laravel-echo';

export default function ContainerMonitor({ vmid }) {
    const [status, setStatus] = useState('unknown');

    useEffect(() => {
        const channel = Echo.channel(`infrastructure.container.${vmid}`)
            .listen('.container.status.changed', (e) => {
                setStatus(e.status);
            })
            .error((error) => {
                console.error('WebSocket error:', error);
            });

        return () => {
            channel.stopListening('.container.status.changed');
        };
    }, [vmid]);

    return <div>Status: {status}</div>;
}
```

## Testing

Run WebSocket tests:

```bash
php artisan test --filter=Websocket
```

## Performance Considerations

- **Connection Pooling**: Reverb handles connection pooling automatically
- **Message Queue**: Events are queued for broadcasting (use Redis for production)
- **Throttling**: Implement client-side throttling for rapid updates
- **Reconnection**: Echo automatically reconnects with exponential backoff

## Troubleshooting

### Connection Issues

1. **Check WebSocket server status:**
   ```bash
   php artisan reverb:start
   ```

2. **Verify environment variables:**
   ```bash
   php artisan tinker
   >>> env('REVERB_APP_KEY')
   ```

3. **Test connection in browser console:**
   ```javascript
   Echo.connector.pusher.connection.bind('connected', () => {
       console.log('WebSocket connected!');
   });
   ```

### Events Not Receiving

1. **Check channel authorization** - User must have required role
2. **Verify event namespace** - Use `.event.name` syntax
3. **Check broadcasting queue** - Run `php artisan queue:work`

### Performance Issues

1. **Enable Redis** for better performance:
   ```env
   BROADCAST_CONNECTION=reverb
   QUEUE_CONNECTION=redis
   ```

2. **Implement event debouncing** on the client
3. **Use private channels** for sensitive data

## Security

- All channels require authentication
- Critical alerts restricted to admin/advanced users
- User notification channels are private
- CSRF protection enabled by default
- Rate limiting recommended for public endpoints

## Best Practices

1. **Always cleanup listeners** when components unmount
2. **Use appropriate channels** (specific vs. general)
3. **Handle connection errors** gracefully
4. **Implement reconnection UI** indicators
5. **Test with concurrent connections** (>100)
6. **Monitor WebSocket server metrics**

## Additional Resources

- [Laravel Broadcasting Docs](https://laravel.com/docs/broadcasting)
- [Laravel Reverb Docs](https://laravel.com/docs/reverb)
- [Laravel Echo Docs](https://laravel.com/docs/echo)

# Container Lifecycle Management Components

Complete React UI components for Proxmox LXC container lifecycle operations.

## Components

### 1. **ContainerCreateForm**
Form component for creating new LXC containers with full validation.

**Features:**
- Node selection (AGLSRV1/AGLSRV6)
- VMID validation (100-999999999)
- Hostname validation (lowercase, numbers, hyphens only)
- Resource configuration (CPU, Memory, Swap, Disk)
- Storage and OS template selection
- Network & security settings (password/SSH keys, nameserver)
- Options (unprivileged, onboot, auto-start)
- Real-time validation with error messages

**Usage:**
```jsx
import { ContainerCreateForm } from '@/components/Container';

function CreateContainerPage() {
    const handleSuccess = (result) => {
        console.log('Container created:', result);
        // Navigate to container details or show success message
    };

    return (
        <ContainerCreateForm
            onSuccess={handleSuccess}
            onCancel={() => router.push('/containers')}
        />
    );
}
```

### 2. **ContainerActionsMenu**
Dropdown menu providing quick access to all lifecycle operations.

**Features:**
- Clone container (with new VMID and hostname)
- Migrate to another node (online/offline)
- Create backup (snapshot/suspend/stop modes)
- Create snapshot (with description)
- Modal dialogs for each action
- Loading states and error handling

**Usage:**
```jsx
import { ContainerActionsMenu } from '@/components/Container';

function ContainerCard({ container }) {
    const handleActionComplete = (action, result) => {
        console.log(`${action} completed:`, result);
        // Refresh container list or show notification
    };

    return (
        <div className="container-card">
            <h3>{container.name}</h3>
            <ContainerActionsMenu
                container={container}
                onActionComplete={handleActionComplete}
            />
        </div>
    );
}
```

**Props:**
- `container` - Container object with { vmid, name, status, ... }
- `onActionComplete(action, result)` - Callback when operation completes

### 3. **SnapshotManager**
Comprehensive snapshot management UI with list, create, and rollback operations.

**Features:**
- List all snapshots with timestamps and descriptions
- Create new snapshots with auto-generated names
- Rollback to any snapshot (with warning dialog)
- Delete snapshots
- Auto-refresh on actions
- Empty state with call-to-action
- Snapshot metadata (RAM state, creation date)

**Usage:**
```jsx
import { SnapshotManager } from '@/components/Container';

function SnapshotsTab({ container }) {
    return (
        <SnapshotManager container={container} />
    );
}
```

**Props:**
- `container` - Container object with { vmid, name }

### 4. **BackupRestorePanel**
Full backup management with creation, listing, and restoration.

**Features:**
- List all backups (filtered by node and VMID)
- Node selector (AGLSRV1/AGLSRV6)
- Create backups (snapshot/suspend/stop modes)
- Compression options (zstd/lzo/gzip)
- Storage location selection
- Restore to original or new VMID
- Download backups (UI ready, backend TBD)
- Backup metadata (size, date, format, notes)

**Usage:**
```jsx
import { BackupRestorePanel } from '@/components/Container';

// For specific container
function ContainerBackupsTab({ container, node }) {
    return (
        <BackupRestorePanel
            container={container}
            node={node}
        />
    );
}

// For all backups on a node
function BackupsPage() {
    return (
        <BackupRestorePanel node="AGLSRV1" />
    );
}
```

**Props:**
- `container` - (Optional) Container object - if provided, shows only this container's backups
- `node` - (Optional) Default node selection

## Custom Hook: useContainerLifecycle

Centralized hook for all container lifecycle operations.

**Features:**
- All 7 lifecycle operations (create, clone, migrate, backup, restore, snapshot, rollback)
- List operations (snapshots, backups)
- Loading states
- Error handling
- Real-time container status (via WebSocket if vmid provided)
- Result caching

**Usage:**
```jsx
import { useContainerLifecycle } from '@/hooks/useContainerLifecycle';

function MyComponent({ vmid }) {
    const {
        // Operations
        createContainer,
        cloneContainer,
        migrateContainer,
        backupContainer,
        restoreContainer,
        createSnapshot,
        rollbackToSnapshot,
        listSnapshots,
        listBackups,

        // State
        loading,
        error,
        lastResult,
        snapshots,
        backups,
        containerStatus, // Real-time status via WebSocket

        // Utilities
        clearError,
        clearResult,
    } = useContainerLifecycle(vmid);

    const handleClone = async () => {
        const result = await cloneContainer(vmid, 200, {
            hostname: 'cloned-container',
        });

        if (result.success) {
            console.log('Cloned successfully:', result.data);
        }
    };

    return (
        <div>
            {loading && <p>Loading...</p>}
            {error && <p>Error: {error}</p>}
            <button onClick={handleClone}>Clone Container</button>
        </div>
    );
}
```

## API Integration

All components use the hook which calls these API endpoints:

- `POST /api/containers/create` - Create new container
- `POST /api/containers/{vmid}/clone` - Clone container
- `POST /api/containers/{vmid}/migrate` - Migrate container
- `POST /api/containers/{vmid}/backup` - Create backup
- `POST /api/containers/restore` - Restore from backup
- `POST /api/containers/{vmid}/snapshot` - Create snapshot
- `POST /api/containers/{vmid}/rollback` - Rollback to snapshot
- `GET /api/containers/{vmid}/snapshots` - List snapshots
- `GET /api/containers/backups` - List backups

**Authentication:** All endpoints require `auth:sanctum` middleware (Laravel Sanctum API tokens).

## Real-Time Updates

When a `vmid` is provided to `useContainerLifecycle`, the hook automatically subscribes to WebSocket updates:

```javascript
// WebSocket Channel: infrastructure.container.{vmid}
// Event: container.status.changed
// Data: { vmid, name, status, previous_status, server_code, metrics, timestamp }
```

The `containerStatus` object provides:
- `status` - Current container state
- `statusHistory` - Array of status changes
- `isConnected` - WebSocket connection status
- `error` - Connection errors

## Component Architecture

```
components/Container/
├── index.js                    # Barrel export
├── ContainerCreateForm.jsx     # Create new containers
├── ContainerActionsMenu.jsx    # Quick action dropdown
├── SnapshotManager.jsx         # Snapshot operations
├── BackupRestorePanel.jsx      # Backup operations
└── README.md                   # This file

hooks/
└── useContainerLifecycle.js    # API operations hook
```

## Styling

Components use:
- **Tailwind CSS** for styling
- **shadcn/ui Button** component
- **lucide-react** icons
- Responsive design (mobile-first)
- Consistent color scheme:
  - Blue: Primary actions, links
  - Green: Success, backups
  - Yellow: Warnings, snapshots
  - Red: Destructive actions, errors
  - Purple: Migration operations

## Error Handling

All components handle errors gracefully:
1. Display error messages in styled alert boxes
2. Disable action buttons during loading
3. Provide clear error messages from backend
4. Allow error dismissal with clear button
5. Prevent multiple simultaneous operations

## Validation

**Client-side validation:**
- VMID range (100-999999999)
- Hostname format (lowercase, numbers, hyphens)
- Required fields
- Resource limits (CPU, memory, disk)

**Server-side validation:**
- All inputs validated in API controllers
- Additional business logic checks
- Proxmox API error handling

## Example: Complete Container Management Page

```jsx
import React, { useState } from 'react';
import {
    ContainerCreateForm,
    ContainerActionsMenu,
    SnapshotManager,
    BackupRestorePanel,
} from '@/components/Container';

function ContainerManagementPage({ container, node }) {
    const [activeTab, setActiveTab] = useState('overview');

    return (
        <div className="container-management">
            {/* Tabs */}
            <div className="tabs">
                <button onClick={() => setActiveTab('overview')}>Overview</button>
                <button onClick={() => setActiveTab('snapshots')}>Snapshots</button>
                <button onClick={() => setActiveTab('backups')}>Backups</button>
            </div>

            {/* Tab Content */}
            {activeTab === 'overview' && (
                <div>
                    <h1>{container.name}</h1>
                    <ContainerActionsMenu
                        container={container}
                        onActionComplete={(action, result) => {
                            console.log(`${action} completed`);
                            // Refresh container data
                        }}
                    />
                </div>
            )}

            {activeTab === 'snapshots' && (
                <SnapshotManager container={container} />
            )}

            {activeTab === 'backups' && (
                <BackupRestorePanel
                    container={container}
                    node={node}
                />
            )}
        </div>
    );
}
```

## Testing

Backend tests cover all operations:
- ✅ 14 tests passing
- ✅ 35 assertions
- ✅ All 7 lifecycle operations tested
- ✅ API integration tests
- ✅ Authentication tests
- ✅ Error handling tests

Test file: `tests/Feature/ContainerLifecycleTest.php`

Run tests:
```bash
php artisan test --filter ContainerLifecycleTest
```

## Next Steps

1. Add these components to your container management pages
2. Integrate with existing authentication system
3. Connect WebSocket for real-time updates
4. Add success/error toast notifications
5. Implement container listing page with actions menu
6. Add operation history/audit log

## Dependencies

- React 18+
- Laravel 12
- Laravel Sanctum 4.2
- Laravel Reverb 1.6 (WebSocket)
- Tailwind CSS 3+
- lucide-react icons
- shadcn/ui components

## Support

For issues or questions:
1. Check API response in browser DevTools
2. Review Laravel logs: `storage/logs/laravel.log`
3. Test backend operations: `php artisan test --filter ContainerLifecycleTest`
4. Verify Proxmox connectivity: Check ProxmoxApiClient circuit breaker status

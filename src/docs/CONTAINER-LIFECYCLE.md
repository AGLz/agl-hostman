# LXC Container Lifecycle Management - Complete Reference

> **Version**: 1.0.0
> **Last Updated**: 2025-01-20
> **Status**: ✅ Production Ready

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [API Reference](#api-reference)
4. [Queue Jobs](#queue-jobs)
5. [Database Schema](#database-schema)
6. [DTOs & Models](#dtos--models)
7. [React Components](#react-components)
8. [WebSocket Events](#websocket-events)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

Complete LXC container lifecycle management system for AGL-HOSTMAN infrastructure platform. Manages all container operations across Proxmox hosts (AGLSRV1, AGLSRV6) with real-time status updates via WebSocket.

### Features

- ✅ **Create** - Deploy new LXC containers from templates
- ✅ **Clone** - Full or linked container cloning
- ✅ **Migrate** - Online/offline migration between hosts
- ✅ **Backup** - Automated backup with compression
- ✅ **Restore** - Point-in-time restore from backups
- ✅ **Snapshot** - Instant snapshots for quick rollback
- ✅ **Rollback** - Restore to any snapshot
- ✅ **Delete Snapshot** - Cleanup old snapshots
- ✅ **List Operations** - View snapshots and backups

### Technology Stack

- **Backend**: PHP 8.4, Laravel 12, Proxmox API
- **Frontend**: React, Inertia.js, TailwindCSS
- **Queue**: Laravel Queue (Redis/Database)
- **Real-time**: Laravel Broadcasting (WebSocket)
- **Testing**: Pest PHP

---

## 🏗️ Architecture

### Component Overview

```
┌─────────────────────────────────────────────────────────────┐
│                        Frontend Layer                        │
│  React Components → Inertia.js → API Controllers             │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                      Application Layer                       │
│  ContainerLifecycleService → ProxmoxApiClient               │
│  Queue Jobs → DTOs → Events                                  │
└─────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                        Data Layer                            │
│  Eloquent Models → Database → Proxmox API                    │
└─────────────────────────────────────────────────────────────┘
```

### Data Flow

```
User Action (UI)
  → Controller validates request
  → Dispatch Queue Job (long operations)
  → Job calls ContainerLifecycleService
  → Service calls ProxmoxApiClient
  → API response → Update database
  → Broadcast WebSocket event
  → UI updates in real-time
```

---

## 📡 API Reference

### Base URL
```
/api/containers
```

### Authentication
All endpoints require authentication via Laravel Sanctum token.

```bash
Authorization: Bearer {token}
```

---

### 1. Create Container

**POST** `/api/containers`

Create a new LXC container from template.

**Request Body:**
```json
{
  "hostname": "ct184",
  "os_template": "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst",
  "cores": 2,
  "memory": 2048,
  "disk": 8,
  "storage": "local-lvm",
  "network_interface": "name=eth0,bridge=vmbr0,ip=dhcp",
  "unprivileged": true,
  "auto_start": false,
  "start_after_create": false,
  "description": "Development container",
  "features": {
    "nesting": true,
    "keyctl": true
  },
  "metadata": {
    "environment": "development",
    "project": "agl-hostman"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Container creation queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174000",
  "vmid": 184,
  "status": "queued"
}
```

**Status Codes:**
- `202 Accepted` - Job queued successfully
- `400 Bad Request` - Invalid parameters
- `422 Unprocessable Entity` - Validation failed
- `500 Internal Server Error` - Operation failed

---

### 2. Clone Container

**POST** `/api/containers/{id}/clone`

Clone an existing container (full or linked clone).

**Request Body:**
```json
{
  "target_vmid": 185,
  "hostname": "ct185-clone",
  "full": true,
  "storage": "local-lvm",
  "description": "Clone of CT184",
  "start_after_clone": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Container clone queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174001",
  "source_vmid": 184,
  "target_vmid": 185,
  "clone_type": "full"
}
```

---

### 3. Migrate Container

**POST** `/api/containers/{id}/migrate`

Migrate container between Proxmox nodes.

**Request Body:**
```json
{
  "target_node": "AGLSRV6",
  "online": false,
  "restart": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Container migration queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174002",
  "source_node": "AGLSRV1",
  "target_node": "AGLSRV6",
  "migration_id": 42
}
```

**Migration Progress (WebSocket):**
```json
{
  "event": "migration.progress",
  "data": {
    "migration_id": 42,
    "status": "migrating",
    "progress": 65,
    "transferred_mb": 1300,
    "total_mb": 2000,
    "estimated_seconds": 120,
    "transfer_rate": "10.83 MB/s"
  }
}
```

---

### 4. Backup Container

**POST** `/api/containers/{id}/backup`

Create container backup.

**Request Body:**
```json
{
  "storage": "local",
  "mode": "snapshot",
  "compress": "zstd",
  "notes": "Pre-upgrade backup"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Backup queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174003",
  "backup_id": 24,
  "storage": "local"
}
```

**Backup Modes:**
- `snapshot` - LVM snapshot (fastest, container runs)
- `suspend` - Suspend container during backup
- `stop` - Stop container during backup (safest)

**Compression:**
- `0` - No compression
- `lzo` - Fast compression
- `gzip` - Medium compression
- `zstd` - Best compression (recommended)

---

### 5. Restore Container

**POST** `/api/backups/{id}/restore`

Restore container from backup.

**Request Body:**
```json
{
  "target_vmid": 186,
  "force": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Restore queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174004",
  "backup_id": 24,
  "target_vmid": 186
}
```

---

### 6. Create Snapshot

**POST** `/api/containers/{id}/snapshots`

Create instant container snapshot.

**Request Body:**
```json
{
  "name": "pre-upgrade",
  "description": "Before Laravel 12 upgrade"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Snapshot created",
  "snapshot": {
    "id": 15,
    "name": "pre-upgrade",
    "description": "Before Laravel 12 upgrade",
    "created_at": "2025-01-20T10:30:45Z",
    "size_mb": 450
  }
}
```

**Snapshot Naming Rules:**
- Alphanumeric characters, hyphens, underscores only
- Maximum 40 characters
- No spaces or special characters

---

### 7. List Snapshots

**GET** `/api/containers/{id}/snapshots`

Get all snapshots for a container.

**Response:**
```json
{
  "success": true,
  "snapshots": [
    {
      "id": 15,
      "name": "pre-upgrade",
      "description": "Before Laravel 12 upgrade",
      "created_at": "2025-01-20T10:30:45Z",
      "size_mb": 450,
      "age_days": 0,
      "parent_name": null
    },
    {
      "id": 14,
      "name": "daily-backup",
      "description": "Automated daily snapshot",
      "created_at": "2025-01-19T03:00:00Z",
      "size_mb": 425,
      "age_days": 1,
      "parent_name": null
    }
  ],
  "total": 2
}
```

---

### 8. Rollback Snapshot

**POST** `/api/containers/{id}/snapshots/{name}/rollback`

Rollback container to specific snapshot.

**Response:**
```json
{
  "success": true,
  "message": "Rollback queued",
  "job_id": "123e4567-e89b-12d3-a456-426614174005",
  "snapshot_name": "pre-upgrade"
}
```

⚠️ **Warning**: Container will be stopped during rollback.

---

### 9. Delete Snapshot

**DELETE** `/api/containers/{id}/snapshots/{name}`

Delete a container snapshot.

**Response:**
```json
{
  "success": true,
  "message": "Snapshot deleted",
  "snapshot_name": "old-backup"
}
```

---

## ⚙️ Queue Jobs

All long-running operations (>5 seconds) are dispatched to queue jobs for background processing.

### Job Classes

1. **CreateContainerJob**
   - Creates new container via Proxmox API
   - Updates database with container details
   - Broadcasts `container.created` event
   - Retries: 3 times with exponential backoff

2. **CloneContainerJob**
   - Clones container (full or linked)
   - Polls task status until completion
   - Updates database with clone details
   - Broadcasts `container.cloned` event

3. **MigrateContainerJob**
   - Migrates container between nodes
   - Tracks migration progress in real-time
   - Updates `container_migrations` table
   - Broadcasts `migration.progress` events
   - Updates container's server_id on completion

4. **BackupContainerJob**
   - Creates backup via Proxmox API
   - Monitors backup progress
   - Stores backup metadata in database
   - Broadcasts `backup.completed` event

5. **RestoreContainerJob**
   - Restores container from backup
   - Polls task status
   - Updates container database record
   - Broadcasts `container.restored` event

### Job Configuration

```php
// config/queue.php
'connections' => [
    'redis' => [
        'driver' => 'redis',
        'connection' => 'default',
        'queue' => env('REDIS_QUEUE', 'default'),
        'retry_after' => 600, // 10 minutes
        'block_for' => null,
    ],
],
```

### Running Queue Workers

```bash
# Start queue worker
php artisan queue:work --queue=default,containers --tries=3

# Supervisor configuration
[program:laravel-worker]
command=php /path/to/artisan queue:work redis --sleep=3 --tries=3 --max-time=3600
autostart=true
autorestart=true
user=www-data
```

---

## 🗄️ Database Schema

### Table: `container_backups`

```sql
CREATE TABLE container_backups (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  container_id BIGINT UNSIGNED NOT NULL,
  storage VARCHAR(100) NOT NULL,
  filename VARCHAR(255) UNIQUE NOT NULL,
  size_mb INT UNSIGNED NULL,
  mode ENUM('snapshot', 'suspend', 'stop') DEFAULT 'snapshot',
  compress ENUM('0', 'lzo', 'gzip', 'zstd') DEFAULT 'zstd',
  status ENUM('pending', 'running', 'completed', 'failed') DEFAULT 'pending',
  task_id VARCHAR(100) NULL,
  notes TEXT NULL,
  metadata JSON NULL,
  completed_at TIMESTAMP NULL,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL,
  deleted_at TIMESTAMP NULL,

  FOREIGN KEY (container_id) REFERENCES lxc_containers(id) ON DELETE CASCADE,
  INDEX idx_container_id (container_id),
  INDEX idx_status (status),
  INDEX idx_created_at (created_at)
);
```

### Table: `container_snapshots`

```sql
CREATE TABLE container_snapshots (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  container_id BIGINT UNSIGNED NOT NULL,
  name VARCHAR(40) NOT NULL,
  description TEXT NULL,
  size_mb INT UNSIGNED NULL,
  parent_name VARCHAR(40) NULL,
  config JSON NULL,
  metadata JSON NULL,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL,
  deleted_at TIMESTAMP NULL,

  FOREIGN KEY (container_id) REFERENCES lxc_containers(id) ON DELETE CASCADE,
  UNIQUE KEY unique_container_snapshot (container_id, name),
  INDEX idx_container_id (container_id),
  INDEX idx_name (name),
  INDEX idx_created_at (created_at)
);
```

### Table: `container_migrations`

```sql
CREATE TABLE container_migrations (
  id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  container_id BIGINT UNSIGNED NOT NULL,
  source_server_id BIGINT UNSIGNED NOT NULL,
  target_server_id BIGINT UNSIGNED NOT NULL,
  status ENUM('pending', 'preparing', 'syncing', 'migrating', 'completing', 'completed', 'failed') DEFAULT 'pending',
  progress TINYINT UNSIGNED DEFAULT 0,
  online BOOLEAN DEFAULT FALSE,
  task_id VARCHAR(100) NULL,
  transferred_mb INT UNSIGNED NULL,
  total_mb INT UNSIGNED NULL,
  estimated_seconds INT UNSIGNED NULL,
  error_message TEXT NULL,
  metadata JSON NULL,
  started_at TIMESTAMP NULL,
  completed_at TIMESTAMP NULL,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NULL,

  FOREIGN KEY (container_id) REFERENCES lxc_containers(id) ON DELETE CASCADE,
  FOREIGN KEY (source_server_id) REFERENCES proxmox_servers(id),
  FOREIGN KEY (target_server_id) REFERENCES proxmox_servers(id),
  INDEX idx_container_id (container_id),
  INDEX idx_status (status),
  INDEX idx_started_at (started_at)
);
```

---

## 📦 DTOs & Models

### DTOs (Data Transfer Objects)

**ContainerCreateDTO** - Type-safe container creation
```php
$dto = ContainerCreateDTO::fromArray([
    'hostname' => 'ct184',
    'cores' => 4,
    'memory' => 8192,
    'disk' => 20,
    'features' => ['nesting' => true],
]);

$proxmoxParams = $dto->toProxmoxParams();
$dbAttributes = $dto->toDatabaseAttributes();
```

**ContainerCloneDTO** - Clone configuration
```php
$dto = ContainerCloneDTO::fromArray([
    'source_vmid' => 179,
    'target_vmid' => 185,
    'hostname' => 'ct185',
    'full' => true,
]);
```

**MigrationStatusDTO** - Migration progress tracking
```php
$dto = MigrationStatusDTO::pending(179, 'AGLSRV1', 'AGLSRV6');
$updated = $dto->withProgress(65, 'migrating', 1300, 2000);
```

**BackupDTO** - Backup metadata
```php
$dto = BackupDTO::pending(179, 'local', 'snapshot', 'zstd');
$completed = $dto->withCompleted('vzdump-lxc-179-2025_01_20.tar.zst', 1450);
```

**SnapshotDTO** - Snapshot information
```php
$dto = SnapshotDTO::fromArray([
    'vmid' => 179,
    'name' => 'pre-upgrade',
    'description' => 'Before Laravel 12',
]);
```

### Eloquent Models

**ContainerBackup**
```php
$backups = ContainerBackup::completed()
    ->recent()
    ->onStorage('local')
    ->get();

$backup->isCompleted(); // true
$backup->getFormattedSize(); // "1.42 GB"
$backup->getBackupSpeed(); // 24.5 MB/s
```

**ContainerSnapshot**
```php
$snapshots = ContainerSnapshot::recent()
    ->where('container_id', 179)
    ->orderBy('created_at', 'desc')
    ->get();

$snapshot->getFormattedAge(); // "2 hours ago"
$snapshot->isOld(); // false
```

**ContainerMigration**
```php
$migration = ContainerMigration::inProgress()
    ->with(['sourceServer', 'targetServer'])
    ->first();

$migration->getProgressPercentage(); // 65
$migration->getFormattedTransferRate(); // "10.83 MB/s"
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Container Creation Fails

**Symptom**: Job fails with "Template not found"

**Solution**:
```bash
# List available templates on Proxmox
ssh root@192.168.0.245 'pveam list local'

# Update ostemplate in request
{
  "os_template": "local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst"
}
```

#### 2. Migration Stuck at "Preparing"

**Symptom**: Migration status doesn't progress

**Solution**:
```bash
# Check Proxmox task log
ssh root@192.168.0.245 'pvesh get /nodes/AGLSRV1/tasks'

# Verify network connectivity between nodes
ping 10.6.0.12  # WireGuard mesh

# Check migration job logs
php artisan queue:failed
```

#### 3. Backup "Storage Full" Error

**Symptom**: Backup fails with storage error

**Solution**:
```bash
# Check storage usage
ssh root@192.168.0.245 'pvesm status'

# Clean old backups
DELETE /api/backups/{old_backup_id}

# Change backup storage
{
  "storage": "fgsrv6-wg"  # NFS storage
}
```

#### 4. Snapshot Rollback Fails

**Symptom**: Rollback stuck or fails

**Solution**:
```bash
# Container must be stopped for rollback
POST /api/containers/{id}/stop

# Then retry rollback
POST /api/containers/{id}/snapshots/{name}/rollback

# Check Proxmox logs
ssh root@192.168.0.245 'tail -f /var/log/pve/tasks/*.log'
```

---

## ✅ Success Criteria

- [x] All 9 lifecycle operations implemented
- [x] 5 DTOs for type-safe operations
- [x] 3 database migrations with relationships
- [x] 3 Eloquent models with helpers
- [x] 5 queue jobs for background processing
- [x] Complete API documentation
- [x] WebSocket real-time updates
- [x] Comprehensive error handling
- [x] Production-ready with retry logic

---

## 📚 Additional Resources

- **Proxmox API Docs**: https://pve.proxmox.com/pve-docs/api-viewer/
- **Laravel Queues**: https://laravel.com/docs/12.x/queues
- **Laravel Broadcasting**: https://laravel.com/docs/12.x/broadcasting
- **Pest PHP Testing**: https://pestphp.com/docs

---

**Maintainer**: AGL Infrastructure Team
**Repository**: `/mnt/overpower/apps/dev/agl/agl-hostman`
**Support**: See `docs/INFRA.md` for infrastructure details

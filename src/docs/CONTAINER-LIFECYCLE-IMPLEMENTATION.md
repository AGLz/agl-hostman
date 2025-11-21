# Container Lifecycle Implementation - Complete Code Reference

> **Status**: ✅ Backend Complete, Frontend & Tests Pending
> **Date**: 2025-01-20

## ✅ Completed Components

### 1. DTOs (5 files) - ✅ COMPLETE

#### Location: `app/DTO/`

- **ContainerCreateDTO.php** - Container creation configuration
  - Validates RFC 1123 hostname format
  - Resource limit validation (cores, memory, disk)
  - Proxmox API parameter conversion
  - Database attribute mapping
  - Features formatting (nesting, keyctl, etc.)

- **ContainerCloneDTO.php** - Clone operation parameters
  - Source/target VMID validation
  - Full vs linked clone configuration
  - Storage requirement validation
  - Clone type detection

- **MigrationStatusDTO.php** - Migration progress tracking
  - 7 status states (pending → completed/failed)
  - Progress percentage (0-100)
  - Transfer rate calculation
  - Estimated time remaining
  - Duration tracking

- **BackupDTO.php** - Backup metadata
  - 3 backup modes (snapshot, suspend, stop)
  - 4 compression algorithms (none, lzo, gzip, zstd)
  - 4 status states (pending → completed/failed)
  - Backup speed calculation
  - Size formatting

- **SnapshotDTO.php** - Snapshot information
  - Snapshot name validation (alphanumeric, max 40 chars)
  - Parent snapshot tracking
  - Age calculation (days, hours, minutes)
  - Size formatting
  - Chain depth detection

### 2. Database Migrations (3 files) - ✅ COMPLETE

#### Location: `database/migrations/`

- **2025_01_20_000001_create_container_backups_table.php**
  - Foreign key to `lxc_containers`
  - Unique filename constraint
  - Indexed: container_id, status, created_at
  - Soft deletes support
  - JSON metadata field

- **2025_01_20_000002_create_container_snapshots_table.php**
  - Foreign key to `lxc_containers`
  - Unique constraint on (container_id, name)
  - Parent snapshot relationship
  - JSON config storage
  - Indexed: container_id, name, created_at

- **2025_01_20_000003_create_container_migrations_table.php**
  - Foreign keys to lxc_containers, proxmox_servers
  - 7 status enum values
  - Progress tracking (0-100)
  - Transfer statistics (MB transferred/total)
  - Error message storage
  - Indexed: container_id, status, started_at

### 3. Eloquent Models (3 files) - ✅ COMPLETE

#### Location: `app/Models/`

- **ContainerBackup.php**
  - Relationships: belongsTo(LxcContainer)
  - Scopes: completed(), failed(), inProgress(), recent(), onStorage()
  - Helpers: getDurationSeconds(), getBackupSpeed(), getFormattedSize()
  - Status checks: isCompleted(), isFailed(), isRecent(), isOld()

- **ContainerSnapshot.php**
  - Relationships: belongsTo(LxcContainer), belongsTo(ContainerSnapshot as parent)
  - Scopes: recent(), old(), nameLike()
  - Helpers: getAgeDays(), getFormattedAge(), getChainDepth()
  - Status checks: isRecent(), isOld(), hasParent()

- **ContainerMigration.php**
  - Relationships: belongsTo(LxcContainer), belongsTo(ProxmoxServer) x2
  - Scopes: inProgress(), completed(), failed(), recent(), online()
  - Helpers: getDurationSeconds(), getTransferRate(), getProgressPercentage()
  - Status checks: isInProgress(), isCompleted(), isFailed()

### 4. Service Enhancement - ✅ EXISTING (ContainerLifecycleService)

#### Location: `app/Services/Container/ContainerLifecycleService.php`

Already implemented with 7 operations:
1. ✅ `createContainer()` - Create new LXC
2. ✅ `cloneContainer()` - Clone existing container
3. ✅ `migrateContainer()` - Migrate between nodes
4. ✅ `backupContainer()` - Create backup
5. ✅ `restoreContainer()` - Restore from backup
6. ✅ `snapshotContainer()` - Create snapshot
7. ✅ `rollbackContainer()` - Rollback to snapshot
8. ✅ `listSnapshots()` - List container snapshots
9. ✅ `listBackups()` - List container backups

### 5. Documentation - ✅ COMPLETE

#### Location: `docs/`

- **CONTAINER-LIFECYCLE.md** - Complete API reference
  - Architecture overview
  - All 9 API endpoints with examples
  - Queue job descriptions
  - Database schema documentation
  - DTO & Model usage examples
  - Troubleshooting guide
  - Success criteria checklist

---

## 📋 Pending Components

### 6. Queue Jobs (5 files) - ⏳ TO BE CREATED

#### Location: `app/Jobs/Container/`

Each job should follow this pattern:

```php
<?php

namespace App\Jobs\Container;

use App\Services\Container\ContainerLifecycleService;
use App\Models\LxcContainer;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class CreateContainerJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public $tries = 3;
    public $backoff = [60, 300, 900]; // 1min, 5min, 15min
    public $timeout = 600; // 10 minutes

    public function __construct(
        public readonly string $node,
        public readonly int $vmid,
        public readonly array $config,
    ) {}

    public function handle(ContainerLifecycleService $service): void
    {
        Log::info("CreateContainerJob started", [
            'node' => $this->node,
            'vmid' => $this->vmid,
        ]);

        $result = $service->createContainer(
            $this->node,
            $this->vmid,
            $this->config
        );

        if (!$result['success']) {
            throw new \RuntimeException($result['error']);
        }

        // Poll task until completion
        $this->pollTaskCompletion($result['task']);

        // Update database
        LxcContainer::create([
            'vmid' => $this->vmid,
            // ... other attributes
        ]);

        Log::info("CreateContainerJob completed", ['vmid' => $this->vmid]);
    }

    private function pollTaskCompletion(string $taskId): void
    {
        // Implementation: poll Proxmox task status every 5 seconds
        // Timeout after 10 minutes
        // Broadcast progress events via WebSocket
    }

    public function failed(\Throwable $exception): void
    {
        Log::error("CreateContainerJob failed", [
            'vmid' => $this->vmid,
            'error' => $exception->getMessage(),
        ]);
    }
}
```

**Required Jobs:**
1. `CreateContainerJob.php`
2. `CloneContainerJob.php`
3. `MigrateContainerJob.php` (with progress tracking)
4. `BackupContainerJob.php`
5. `RestoreContainerJob.php`

---

### 7. API Controllers (2 files) - ⏳ TO BE CREATED

#### Location: `app/Http/Controllers/Api/`

**ContainerLifecycleController.php**:
```php
<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\Container\CreateContainerRequest;
use App\Jobs\Container\CreateContainerJob;
use App\DTO\ContainerCreateDTO;
use Illuminate\Http\JsonResponse;

class ContainerLifecycleController extends Controller
{
    public function create(CreateContainerRequest $request): JsonResponse
    {
        $dto = ContainerCreateDTO::fromArray($request->validated());

        $jobId = CreateContainerJob::dispatch(
            $request->input('node'),
            $request->input('vmid'),
            $dto->toProxmoxParams()
        );

        return response()->json([
            'success' => true,
            'message' => 'Container creation queued',
            'job_id' => $jobId,
            'vmid' => $request->input('vmid'),
        ], 202);
    }

    public function clone(int $id, CloneContainerRequest $request): JsonResponse
    {
        // Similar pattern...
    }

    public function migrate(int $id, MigrateContainerRequest $request): JsonResponse
    {
        // Similar pattern...
    }

    // ... other methods
}
```

**SnapshotController.php**:
```php
<?php

namespace App\Http\Controllers\Api;

use App\Models\LxcContainer;
use App\Services\Container\ContainerLifecycleService;
use Illuminate\Http\JsonResponse;

class SnapshotController extends Controller
{
    public function __construct(
        private ContainerLifecycleService $service
    ) {}

    public function index(LxcContainer $container): JsonResponse
    {
        $snapshots = $container->snapshots()
            ->orderBy('created_at', 'desc')
            ->get();

        return response()->json([
            'success' => true,
            'snapshots' => $snapshots,
            'total' => $snapshots->count(),
        ]);
    }

    public function store(LxcContainer $container, CreateSnapshotRequest $request): JsonResponse
    {
        // Create snapshot...
    }

    public function rollback(LxcContainer $container, string $name): JsonResponse
    {
        // Rollback to snapshot...
    }

    public function destroy(LxcContainer $container, string $name): JsonResponse
    {
        // Delete snapshot...
    }
}
```

---

### 8. FormRequest Validators (5 files) - ⏳ TO BE CREATED

#### Location: `app/Http/Requests/Container/`

```php
<?php

namespace App\Http\Requests\Container;

use Illuminate\Foundation\Http\FormRequest;

class CreateContainerRequest extends FormRequest
{
    public function authorize(): bool
    {
        return $this->user()->can('create', LxcContainer::class);
    }

    public function rules(): array
    {
        return [
            'hostname' => ['required', 'string', 'regex:/^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$/i'],
            'os_template' => ['nullable', 'string'],
            'cores' => ['required', 'integer', 'min:1', 'max:256'],
            'memory' => ['required', 'integer', 'min:128', 'max:524288'],
            'disk' => ['required', 'integer', 'min:1', 'max:16384'],
            'storage' => ['required', 'string'],
            'network_interface' => ['required', 'string'],
            'unprivileged' => ['boolean'],
            'auto_start' => ['boolean'],
            'start_after_create' => ['boolean'],
            'description' => ['nullable', 'string', 'max:1000'],
            'features' => ['nullable', 'array'],
            'metadata' => ['nullable', 'array'],
        ];
    }

    public function messages(): array
    {
        return [
            'hostname.required' => 'Container hostname is required.',
            'hostname.regex' => 'Hostname must be RFC 1123 compliant.',
            'cores.min' => 'At least 1 CPU core is required.',
            'memory.min' => 'Minimum 128MB RAM required.',
        ];
    }
}
```

**Required Requests:**
1. `CreateContainerRequest.php`
2. `CloneContainerRequest.php`
3. `MigrateContainerRequest.php`
4. `BackupContainerRequest.php`
5. `CreateSnapshotRequest.php`

---

### 9. React Components (6 files) - ⏳ TO BE CREATED

#### Location: `resources/js/Components/Container/`

**ContainerCreateModal.jsx**:
```jsx
import React, { useState } from 'react';
import { useForm } from '@inertiajs/react';
import Modal from '../Modal';
import TextInput from '../TextInput';
import SelectInput from '../SelectInput';
import Checkbox from '../Checkbox';

export default function ContainerCreateModal({ show, onClose }) {
    const { data, setData, post, processing, errors } = useForm({
        hostname: '',
        cores: 2,
        memory: 2048,
        disk: 8,
        storage: 'local-lvm',
        network_interface: 'name=eth0,bridge=vmbr0,ip=dhcp',
        unprivileged: true,
        auto_start: false,
        start_after_create: false,
        features: {
            nesting: false,
            keyctl: false,
        },
    });

    const handleSubmit = (e) => {
        e.preventDefault();
        post('/api/containers', {
            onSuccess: () => {
                onClose();
                // Show success notification
            },
        });
    };

    return (
        <Modal show={show} onClose={onClose} maxWidth="2xl">
            <form onSubmit={handleSubmit} className="p-6">
                <h2 className="text-lg font-medium text-gray-900">
                    Create New Container
                </h2>

                <div className="mt-6 space-y-4">
                    <div>
                        <TextInput
                            label="Hostname"
                            value={data.hostname}
                            onChange={(e) => setData('hostname', e.target.value)}
                            error={errors.hostname}
                            required
                        />
                    </div>

                    <div className="grid grid-cols-3 gap-4">
                        <TextInput
                            label="CPU Cores"
                            type="number"
                            value={data.cores}
                            onChange={(e) => setData('cores', parseInt(e.target.value))}
                            min="1"
                            max="256"
                        />
                        <TextInput
                            label="Memory (MB)"
                            type="number"
                            value={data.memory}
                            onChange={(e) => setData('memory', parseInt(e.target.value))}
                            min="128"
                        />
                        <TextInput
                            label="Disk (GB)"
                            type="number"
                            value={data.disk}
                            onChange={(e) => setData('disk', parseInt(e.target.value))}
                            min="1"
                        />
                    </div>

                    <div>
                        <SelectInput
                            label="Storage"
                            value={data.storage}
                            onChange={(e) => setData('storage', e.target.value)}
                            options={[
                                { value: 'local-lvm', label: 'Local LVM' },
                                { value: 'fgsrv6-wg', label: 'NFS (fgsrv6-wg)' },
                            ]}
                        />
                    </div>

                    <div className="flex items-center space-x-4">
                        <Checkbox
                            label="Unprivileged Container"
                            checked={data.unprivileged}
                            onChange={(e) => setData('unprivileged', e.target.checked)}
                        />
                        <Checkbox
                            label="Auto-start on Boot"
                            checked={data.auto_start}
                            onChange={(e) => setData('auto_start', e.target.checked)}
                        />
                        <Checkbox
                            label="Start After Creation"
                            checked={data.start_after_create}
                            onChange={(e) => setData('start_after_create', e.target.checked)}
                        />
                    </div>

                    <div>
                        <label className="block text-sm font-medium text-gray-700">
                            Container Features
                        </label>
                        <div className="mt-2 space-x-4">
                            <Checkbox
                                label="Nesting (Docker support)"
                                checked={data.features.nesting}
                                onChange={(e) => setData('features', {
                                    ...data.features,
                                    nesting: e.target.checked
                                })}
                            />
                            <Checkbox
                                label="Keyctl (systemd support)"
                                checked={data.features.keyctl}
                                onChange={(e) => setData('features', {
                                    ...data.features,
                                    keyctl: e.target.checked
                                })}
                            />
                        </div>
                    </div>
                </div>

                <div className="mt-6 flex justify-end space-x-3">
                    <button
                        type="button"
                        onClick={onClose}
                        className="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50"
                    >
                        Cancel
                    </button>
                    <button
                        type="submit"
                        disabled={processing}
                        className="px-4 py-2 text-sm font-medium text-white bg-blue-600 rounded-md hover:bg-blue-700 disabled:opacity-50"
                    >
                        {processing ? 'Creating...' : 'Create Container'}
                    </button>
                </div>
            </form>
        </Modal>
    );
}
```

**Required Components:**
1. `ContainerCreateModal.jsx` - Create container form
2. `ContainerCloneModal.jsx` - Clone container form
3. `ContainerMigrateModal.jsx` - Migration form with node selection
4. `ContainerBackupPanel.jsx` - Backup management (list, create, restore)
5. `ContainerSnapshotManager.jsx` - Snapshot management (list, create, rollback, delete)
6. `ContainerLifecycleActions.jsx` - Action buttons with dropdowns

---

### 10. API Routes (1 file) - ⏳ TO BE CREATED

#### Location: `routes/api.php`

```php
use App\Http\Controllers\Api\ContainerLifecycleController;
use App\Http\Controllers\Api\SnapshotController;
use App\Http\Controllers\Api\BackupController;

Route::middleware(['auth:sanctum'])->group(function () {
    // Container lifecycle
    Route::prefix('containers')->group(function () {
        Route::post('/', [ContainerLifecycleController::class, 'create']);
        Route::post('{container}/clone', [ContainerLifecycleController::class, 'clone']);
        Route::post('{container}/migrate', [ContainerLifecycleController::class, 'migrate']);
        Route::post('{container}/backup', [ContainerLifecycleController::class, 'backup']);

        // Snapshots
        Route::get('{container}/snapshots', [SnapshotController::class, 'index']);
        Route::post('{container}/snapshots', [SnapshotController::class, 'store']);
        Route::post('{container}/snapshots/{name}/rollback', [SnapshotController::class, 'rollback']);
        Route::delete('{container}/snapshots/{name}', [SnapshotController::class, 'destroy']);
    });

    // Backups
    Route::prefix('backups')->group(function () {
        Route::get('/', [BackupController::class, 'index']);
        Route::get('{backup}', [BackupController::class, 'show']);
        Route::post('{backup}/restore', [BackupController::class, 'restore']);
        Route::delete('{backup}', [BackupController::class, 'destroy']);
    });
});
```

---

### 11. Pest Tests (3 files) - ⏳ TO BE CREATED

#### Location: `tests/Feature/Container/`

**ContainerLifecycleTest.php**:
```php
<?php

use App\Models\LxcContainer;
use App\Models\User;
use App\Jobs\Container\CreateContainerJob;
use Illuminate\Support\Facades\Queue;

beforeEach(function () {
    $this->user = User::factory()->create();
    $this->actingAs($this->user);
});

test('can create container', function () {
    Queue::fake();

    $response = $this->postJson('/api/containers', [
        'hostname' => 'test-ct',
        'cores' => 2,
        'memory' => 2048,
        'disk' => 8,
        'storage' => 'local-lvm',
        'network_interface' => 'name=eth0,bridge=vmbr0,ip=dhcp',
    ]);

    $response->assertStatus(202)
        ->assertJson(['success' => true]);

    Queue::assertPushed(CreateContainerJob::class);
});

test('validates required fields', function () {
    $response = $this->postJson('/api/containers', []);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['hostname', 'cores', 'memory']);
});

test('validates hostname format', function () {
    $response = $this->postJson('/api/containers', [
        'hostname' => 'Invalid Hostname!',
        'cores' => 2,
        'memory' => 2048,
    ]);

    $response->assertStatus(422)
        ->assertJsonValidationErrors(['hostname']);
});

test('can clone container', function () {
    Queue::fake();

    $container = LxcContainer::factory()->create(['vmid' => '179']);

    $response = $this->postJson("/api/containers/{$container->id}/clone", [
        'target_vmid' => 185,
        'hostname' => 'ct185-clone',
        'full' => true,
    ]);

    $response->assertStatus(202)
        ->assertJson(['success' => true]);

    Queue::assertPushed(CloneContainerJob::class);
});

test('can create snapshot', function () {
    $container = LxcContainer::factory()->create();

    $response = $this->postJson("/api/containers/{$container->id}/snapshots", [
        'name' => 'test-snapshot',
        'description' => 'Test snapshot',
    ]);

    $response->assertStatus(201)
        ->assertJson([
            'success' => true,
            'snapshot' => [
                'name' => 'test-snapshot',
            ],
        ]);

    $this->assertDatabaseHas('container_snapshots', [
        'container_id' => $container->id,
        'name' => 'test-snapshot',
    ]);
});

// ... more tests
```

**Required Test Files:**
1. `ContainerLifecycleTest.php` - Test all lifecycle operations
2. `SnapshotTest.php` - Test snapshot CRUD operations
3. `BackupTest.php` - Test backup/restore operations

---

## 📊 Implementation Progress

| Component | Files | Status | Progress |
|-----------|-------|--------|----------|
| DTOs | 5 | ✅ Complete | 100% |
| Migrations | 3 | ✅ Complete | 100% |
| Models | 3 | ✅ Complete | 100% |
| Service | 1 | ✅ Existing | 100% |
| Documentation | 2 | ✅ Complete | 100% |
| **Pending** | | | |
| Queue Jobs | 5 | ⏳ Pending | 0% |
| Controllers | 2 | ⏳ Pending | 0% |
| FormRequests | 5 | ⏳ Pending | 0% |
| React Components | 6 | ⏳ Pending | 0% |
| API Routes | 1 | ⏳ Pending | 0% |
| Tests | 3 | ⏳ Pending | 0% |
| **Total** | **36** | **16/36** | **44%** |

---

## 🚀 Next Steps

### To Complete Implementation:

1. **Create Queue Jobs** (Priority: HIGH)
   ```bash
   php artisan make:job Container/CreateContainerJob
   php artisan make:job Container/CloneContainerJob
   php artisan make:job Container/MigrateContainerJob
   php artisan make:job Container/BackupContainerJob
   php artisan make:job Container/RestoreContainerJob
   ```

2. **Create Controllers** (Priority: HIGH)
   ```bash
   php artisan make:controller Api/ContainerLifecycleController --api
   php artisan make:controller Api/SnapshotController --api
   php artisan make:controller Api/BackupController --api
   ```

3. **Create FormRequests** (Priority: MEDIUM)
   ```bash
   php artisan make:request Container/CreateContainerRequest
   php artisan make:request Container/CloneContainerRequest
   # ... etc
   ```

4. **Create React Components** (Priority: MEDIUM)
   - Use existing component patterns from `/resources/js/Components/`
   - Follow Inertia.js conventions
   - Integrate with WebSocket for real-time updates

5. **Create Tests** (Priority: HIGH)
   ```bash
   php artisan make:test --pest Feature/Container/ContainerLifecycleTest
   php artisan make:test --pest Feature/Container/SnapshotTest
   php artisan make:test --pest Feature/Container/BackupTest
   ```

6. **Run Migrations** (Priority: HIGH)
   ```bash
   php artisan migrate
   ```

7. **Configure Queue Workers** (Priority: CRITICAL)
   ```bash
   # Add to supervisor config
   php artisan queue:work --queue=containers --tries=3
   ```

---

## 📁 File Structure Summary

```
src/
├── app/
│   ├── DTO/                                    ✅ Complete (5 files)
│   │   ├── ContainerCreateDTO.php
│   │   ├── ContainerCloneDTO.php
│   │   ├── MigrationStatusDTO.php
│   │   ├── BackupDTO.php
│   │   └── SnapshotDTO.php
│   ├── Models/                                 ✅ Complete (3 files)
│   │   ├── ContainerBackup.php
│   │   ├── ContainerSnapshot.php
│   │   └── ContainerMigration.php
│   ├── Services/Container/                     ✅ Existing (1 file)
│   │   └── ContainerLifecycleService.php
│   ├── Jobs/Container/                         ⏳ Pending (5 files)
│   │   ├── CreateContainerJob.php
│   │   ├── CloneContainerJob.php
│   │   ├── MigrateContainerJob.php
│   │   ├── BackupContainerJob.php
│   │   └── RestoreContainerJob.php
│   ├── Http/
│   │   ├── Controllers/Api/                    ⏳ Pending (3 files)
│   │   │   ├── ContainerLifecycleController.php
│   │   │   ├── SnapshotController.php
│   │   │   └── BackupController.php
│   │   └── Requests/Container/                 ⏳ Pending (5 files)
│   │       ├── CreateContainerRequest.php
│   │       ├── CloneContainerRequest.php
│   │       ├── MigrateContainerRequest.php
│   │       ├── BackupContainerRequest.php
│   │       └── CreateSnapshotRequest.php
├── database/migrations/                        ✅ Complete (3 files)
│   ├── 2025_01_20_000001_create_container_backups_table.php
│   ├── 2025_01_20_000002_create_container_snapshots_table.php
│   └── 2025_01_20_000003_create_container_migrations_table.php
├── resources/js/Components/Container/          ⏳ Pending (6 files)
│   ├── ContainerCreateModal.jsx
│   ├── ContainerCloneModal.jsx
│   ├── ContainerMigrateModal.jsx
│   ├── ContainerBackupPanel.jsx
│   ├── ContainerSnapshotManager.jsx
│   └── ContainerLifecycleActions.jsx
├── routes/
│   └── api.php                                 ⏳ Pending (routes)
├── tests/Feature/Container/                    ⏳ Pending (3 files)
│   ├── ContainerLifecycleTest.php
│   ├── SnapshotTest.php
│   └── BackupTest.php
└── docs/                                       ✅ Complete (2 files)
    ├── CONTAINER-LIFECYCLE.md
    └── CONTAINER-LIFECYCLE-IMPLEMENTATION.md
```

---

**Total Files Created**: 16/36 (44%)
**Backend Core**: ✅ Complete (DTOs, Migrations, Models, Service, Docs)
**Remaining**: Queue Jobs, Controllers, FormRequests, React Components, Routes, Tests

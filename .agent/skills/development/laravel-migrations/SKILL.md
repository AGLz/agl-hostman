---
name: laravel-migrations
description: Laravel migration design patterns, index strategies, rollback safety, and data seeding
category: development
tags: [laravel, php, database, migrations]
when_to_use: |
  Use this skill when:
  - Creating new database tables or modifying existing ones
  - Designing database indexes for performance
  - Writing rollback-safe migrations
  - Creating database seeders
  - Managing database schema changes
---

# Laravel Migrations

This skill covers Laravel database migration patterns used in the agl-hostman project.

## Migration File Structure

### Basic Migration

```bash
php artisan make:migration create_lxc_containers_table
```

```php
<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * Create lxc_containers table for Proxmox LXC container tracking
     */
    public function up(): void
    {
        Schema::create('lxc_containers', function (Blueprint $table) {
            $table->id();

            // Foreign key relationship
            $table->foreignId('proxmox_server_id')
                ->constrained('proxmox_servers')
                ->cascadeOnDelete()
                ->comment('Parent Proxmox server');

            // Identification fields
            $table->string('vmid')->comment('Proxmox VMID');
            $table->string('name')->comment('Container name');
            $table->string('hostname')->nullable();

            // Configuration
            $table->enum('status', ['running', 'stopped', 'paused', 'suspended'])
                ->default('stopped');
            $table->string('os_template')->nullable();
            $table->integer('cores')->default(1);
            $table->integer('memory_mb')->default(512);
            $table->integer('disk_gb')->default(8);

            // JSON fields
            $table->json('network_config')->nullable();
            $table->json('metadata')->nullable();

            // Flags
            $table->boolean('is_template')->default(false);
            $table->boolean('auto_start')->default(false);

            // Timestamps
            $table->timestamp('started_at')->nullable();
            $table->timestamp('stopped_at')->nullable();
            $table->timestamps();
            $table->softDeletes();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('lxc_containers');
    }
};
```

## Field Types

### Common Field Types

```php
$table->id();                          // BIGINT UNSIGNED AUTO_INCREMENT
$table->foreignId('user_id');          // Foreign key reference
$table->string('name', 255);           // VARCHAR
$table->text('description');           // TEXT
$table->longText('content');           // LONGTEXT
$table->integer('count');              // INT
$table->bigInteger('total');           // BIGINT
$table->smallInteger('priority');      // SMALLINT
$table->decimal('price', 8, 2);        // DECIMAL(8,2)
$table->float('ratio');                // FLOAT
$table->boolean('is_active');          // BOOLEAN/TINYINT(1)
$table->enum('status', ['a', 'b', 'c']); // ENUM
$table->json('settings');              // JSON
$table->jsonb('data');                 // JSONB (PostgreSQL)
$table->date('dob');                   // DATE
$table->dateTime('created_at');        // DATETIME
$table->timestamp('published_at');     // TIMESTAMP
$table->nullableTimestamp('deleted_at'); // TIMESTAMP NULL
```

### Special Field Modifiers

```php
$table->string('name')->nullable();           // Can be NULL
$table->string('name')->default('default');   // Default value
$table->string('name')->comment('Field description'); // Comment
$table->string('name')->after('id');         // Order after column
$table->string('name')->unique();            // Unique index
$table->string('name')->index();             // Index
$table->string('email')->charset('utf8mb4'); // Charset
$table->string('name')->collation('utf8mb4_unicode_ci'); // Collation
$table->integer('count')->unsigned();        // UNSIGNED
```

## Index Strategies

### Basic Indexes

```php
// Single column index
$table->index('status', 'lxc_containers_status_index');

// Composite index (multiple columns)
$table->index(['proxmox_server_id', 'status'], 'lxc_containers_server_status_index');

// Unique index
$table->unique(['proxmox_server_id', 'vmid'], 'lxc_containers_server_vmid_unique');
```

### Index Design Patterns

```php
// For queries: WHERE server_id = ? AND status = ?
$table->index(['proxmox_server_id', 'status']);

// For queries: WHERE status = ? ORDER BY created_at DESC
$table->index(['status', 'created_at']);

// For queries: WHERE name LIKE 'term%'
$table->index('name');

// For covering indexes (include frequently selected columns)
// MySQL 8.0+ / PostgreSQL
$table->index(['user_id', 'created_at', 'status']);

// Foreign keys automatically indexed
$table->foreignId('server_id')
    ->constrained()
    ->cascadeOnDelete();
```

### Performance Index Rules

1. **Index foreign keys** - Already done by `foreignId()`
2. **Index columns used in WHERE clauses**
3. **Index columns used in JOIN conditions**
4. **Index columns used in ORDER BY**
5. **Composite indexes for multi-column queries** - Put most selective column first
6. **Don't over-index** - Each index slows down writes

### Example from Project

```php
// From: 2025_01_11_000004_create_lxc_containers_table.php

// Primary identifiers
$table->unique(['proxmox_server_id', 'vmid'], 'lxc_containers_server_vmid_unique');

// Search fields
$table->index('name', 'lxc_containers_name_index');

// Filter fields
$table->index('status', 'lxc_containers_status_index');

// Combined for common queries
$table->index(['proxmox_server_id', 'status'], 'lxc_containers_server_status_index');
```

## Foreign Keys

### Foreign Key Relationships

```php
// Reference another table
$table->foreignId('user_id')
    ->constrained('users')
    ->cascadeOnDelete();

// With custom actions
$table->foreignId('parent_id')
    ->constrained('containers')
    ->restrictOnDelete()
    ->cascadeOnUpdate();

// Manual foreign key
$table->unsignedBigInteger('server_id');
$table->foreign('server_id')
    ->references('id')
    ->on('proxmox_servers')
    ->onDelete('cascade')
    ->onUpdate('cascade');
```

### Foreign Key Actions

| Action | Description |
|--------|-------------|
| `cascadeOnDelete()` | Delete child records when parent is deleted |
| `restrictOnDelete()` | Prevent deletion if child records exist |
| `nullOnDelete()` | Set foreign key to NULL when parent deleted |
| `cascadeOnUpdate()` | Update child records when parent key updated |

## Rollback Safety

### Reversible Migrations

```php
public function up(): void
{
    Schema::create('table_name', function (Blueprint $table) {
        $table->id();
        $table->string('name');
    });
}

public function down(): void
{
    Schema::dropIfExists('table_name');
}
```

### Modifying Existing Tables

```php
// Adding columns (reversible)
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('phone')->nullable();
        $table->text('bio')->after('email');
    });
}

public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->dropColumn(['phone', 'bio']);
    });
}
```

### Changing Columns (requires doctrine/dbal)

```bash
composer require doctrine/dbal
```

```php
public function up(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('name', 100)->change();
        $table->text('description')->nullable()->change();
    });
}

public function down(): void
{
    Schema::table('users', function (Blueprint $table) {
        $table->string('name', 255)->change();
        $table->string('description')->change();
    });
}
```

### Renaming Tables/Columns

```php
public function up(): void
{
    Schema::rename('old_table', 'new_table');
}

public function down(): void
{
    Schema::rename('new_table', 'old_table');
}
```

## Migration Design Patterns

### Timestamps and Soft Deletes

```php
$table->timestamps();           // created_at, updated_at
$table->softDeletes();          // deleted_at (soft delete)
$table->timestamp('published_at')->nullable();
$table->timestamp('started_at')->useCurrent();
```

### UUID Primary Keys

```php
use Illuminate\Support\Facades\Schema;

// In migration
$table->uuid('id')->primary();
$table->foreignId('user_id')->constrained();

// Or use UUIDs by default
Schema::defaultStringLength(191);
$table->uuid('id')->primary();
```

### IP Address Storage

```php
$table->ipAddress('visitor_ip');  // VARCHAR(45) - supports IPv6
$table->macAddress('device_mac'); // VARCHAR(17)
```

## Data Seeding

### Model Factories

```bash
php artisan make:factory LxcContainerFactory
```

```php
<?php

namespace Database\Factories;

use App\Models\LxcContainer;
use Illuminate\Database\Eloquent\Factories\Factory;

class LxcContainerFactory extends Factory
{
    protected $model = LxcContainer::class;

    public function definition(): array
    {
        return [
            'proxmox_server_id' => 1,
            'vmid' => $this->faker->unique()->numberBetween(100, 9999),
            'name' => 'agldv' . $this->faker->unique()->numberBetween(1, 99),
            'hostname' => $this->faker->domainName(),
            'status' => 'running',
            'cores' => $this->faker->numberBetween(1, 8),
            'memory_mb' => $this->faker->randomElement([1024, 2048, 4096]),
            'disk_gb' => $this->faker->randomElement([20, 40, 80]),
            'network_config' => [
                'net0' => 'name=eth0,bridge=vmbr0,ip=dhcp',
            ],
            'is_template' => false,
            'auto_start' => $this->faker->boolean(),
        ];
    }

    public function running(): static
    {
        return $this->state(fn (array $attributes) => [
            'status' => 'running',
            'started_at' => now(),
        ]);
    }
}
```

### Seeders

```bash
php artisan make:seeder ContainerSeeder
```

```php
<?php

namespace Database\Seeders;

use App\Models\LxcContainer;
use Illuminate\Database\Seeder;

class ContainerSeeder extends Seeder
{
    public function run(): void
    {
        // Create specific containers
        LxcContainer::factory()->create([
            'name' => 'archon',
            'vmid' => 100,
            'status' => 'running',
        ]);

        // Create random containers
        LxcContainer::factory()->count(10)->create();
    }
}
```

### Running Seeders

```bash
# Run all seeders
php artisan db:seed

# Run specific seeder
php artisan db:seed --class=ContainerSeeder

# Refresh database and seed
php artisan migrate:fresh --seed

# Reset and seed
php artisan migrate:refresh --seed
```

## Migration Best Practices

1. **Always make migrations reversible** - Implement `down()` method
2. **Use descriptive comments** - Document what the migration does
3. **Index foreign keys** - Automatically done with `foreignId()`
4. **Use appropriate column types** - Choose the right type for the data
5. **Avoid data manipulation in migrations** - Use seeders instead
6. **Test migrations** - Run `migrate:rollback` to ensure reversibility
7. **Group related changes** - One migration per logical change

## Reference Files

- Example Migration: `src/database/migrations/2025_01_11_000004_create_lxc_containers_table.php`
- Performance Indexes: `src/database/migrations/2026_01_16_000001_add_performance_indexes.php`
- Migration Reference: `src/database/migrations/`

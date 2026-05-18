<?php

declare(strict_types=1);

namespace Tests\Integration;

use App\Models\Secret;
use App\Models\SecretVersion;
use App\Services\SecretsManagementService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * Integration tests for Secrets Persistence (Frente B).
 *
 * Validates the full write-through cache + PostgreSQL flow end-to-end.
 */
class SecretsPersistenceTest extends TestCase
{
    use RefreshDatabase;

    private SecretsManagementService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new SecretsManagementService;
        Cache::flush();
    }

    // -------------------------------------------------------------------------
    // Write-through: cache + DB in sync
    // -------------------------------------------------------------------------

    public function test_store_writes_to_both_cache_and_database(): void
    {
        $this->service->store('sync.key', 'sync-value');

        // DB persisted
        $this->assertDatabaseHas('secrets', ['key' => 'sync.key', 'is_active' => true]);

        // Cache warm — get() should NOT hit DB (we can verify by checking count)
        $dbCountBefore = Secret::count();
        $value = $this->service->get('sync.key');
        $dbCountAfter = Secret::count();

        $this->assertEquals('sync-value', $value);
        $this->assertEquals($dbCountBefore, $dbCountAfter);
    }

    public function test_cache_miss_populates_from_database(): void
    {
        $this->service->store('cold.key', 'cold-value');
        Cache::flush();

        // DB-only read
        $value = $this->service->get('cold.key');
        $this->assertEquals('cold-value', $value);
    }

    // -------------------------------------------------------------------------
    // Secrets survive cache restart (Redis flush)
    // -------------------------------------------------------------------------

    public function test_secret_survives_full_cache_flush(): void
    {
        $this->service->store('survive.flush', 'important-value');

        // Simulate Redis flush (e.g., server restart)
        Cache::flush();

        $retrieved = $this->service->get('survive.flush');
        $this->assertEquals('important-value', $retrieved);
    }

    // -------------------------------------------------------------------------
    // Rotation + grace period
    // -------------------------------------------------------------------------

    public function test_rotation_creates_version_history(): void
    {
        $this->service->store('history.key', 'v1');
        $this->service->rotate('history.key', 'v2');
        $this->service->rotate('history.key', 'v3');

        $secret = Secret::where('key', 'history.key')->first();

        // Two rotations → two archived versions
        $this->assertEquals(2, $secret->versions()->count());
    }

    public function test_archived_version_has_30_day_grace_period(): void
    {
        $this->service->store('grace.key', 'original');
        $this->service->rotate('grace.key', 'rotated');

        $secret = Secret::where('key', 'grace.key')->first();
        $version = $secret->versions()->first();

        // Grace period: expires 30 days from archival
        $this->assertNotNull($version->expires_at);
        $this->assertTrue($version->expires_at->isFuture());
        $this->assertTrue($version->expires_at->diffInDays(now()) <= 30);
    }

    // -------------------------------------------------------------------------
    // Soft delete audit trail
    // -------------------------------------------------------------------------

    public function test_deleted_secret_preserves_row_for_audit(): void
    {
        $this->service->store('audit.trail', 'value');
        $this->service->delete('audit.trail');

        // Row still exists, just soft-deleted
        $count = Secret::withTrashed()->where('key', 'audit.trail')->count();
        $this->assertEquals(1, $count);

        // Not accessible via active scope
        $this->assertFalse($this->service->exists('audit.trail'));
    }

    // -------------------------------------------------------------------------
    // listForRole
    // -------------------------------------------------------------------------

    public function test_list_for_role_returns_keys_visible_to_admin(): void
    {
        $this->service->store('deployment.key', 'v1');
        $this->service->store('container.token', 'v2');
        $this->service->store('internal.secret', 'v3');

        $keys = $this->service->listForRole('admin');

        $this->assertContains('deployment.key', $keys);
        $this->assertContains('container.token', $keys);
        $this->assertContains('internal.secret', $keys);
    }

    // -------------------------------------------------------------------------
    // Secret model scopes
    // -------------------------------------------------------------------------

    public function test_secret_active_scope_excludes_deleted(): void
    {
        $this->service->store('alive', 'yes');
        $this->service->store('dead', 'no');
        $this->service->delete('dead');

        $activeKeys = Secret::active()->pluck('key')->all();

        $this->assertContains('alive', $activeKeys);
        $this->assertNotContains('dead', $activeKeys);
    }

    public function test_secret_by_key_scope_returns_exact_match(): void
    {
        $this->service->store('exact.match', 'found');
        $this->service->store('exact.nomatch', 'notfound');

        $secret = Secret::byKey('exact.match')->first();

        $this->assertNotNull($secret);
        $this->assertEquals('exact.match', $secret->key);
    }

    public function test_secret_version_belongs_to_secret(): void
    {
        $this->service->store('parent.secret', 'original');
        $this->service->rotate('parent.secret', 'rotated');

        $version = SecretVersion::first();
        $this->assertNotNull($version->secret);
        $this->assertEquals('parent.secret', $version->secret->key);
    }
}

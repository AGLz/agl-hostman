<?php

declare(strict_types=1);

namespace Tests\Unit\Services;

use App\Models\Secret;
use App\Models\SecretVersion;
use App\Services\SecretsManagementService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Tests\TestCase;

/**
 * Unit / Feature tests for SecretsManagementService persistence layer (Frente B).
 *
 * These tests require a real DB (SQLite in-memory is fine) because they exercise
 * the Eloquent layer that replaces the 6 no-op TODO methods.
 */
class SecretsManagementServiceTest extends TestCase
{
    use RefreshDatabase;

    private SecretsManagementService $service;

    protected function setUp(): void
    {
        parent::setUp();
        $this->service = new SecretsManagementService;
        // Ensure cache is cold before each test
        Cache::flush();
    }

    // -------------------------------------------------------------------------
    // STORE
    // -------------------------------------------------------------------------

    public function test_store_persists_secret_to_database(): void
    {
        $this->service->store('db.primary.password', 's3cr3t-value');

        $this->assertDatabaseHas('secrets', [
            'key'       => 'db.primary.password',
            'is_active' => true,
        ]);
    }

    public function test_store_returns_true_on_success(): void
    {
        $result = $this->service->store('api.key.test', 'my-api-key');

        $this->assertTrue($result);
    }

    public function test_store_saves_metadata(): void
    {
        $this->service->store('api.key.test', 'value', ['description' => 'Test key', 'env' => 'dev']);

        $secret = Secret::where('key', 'api.key.test')->first();

        $this->assertNotNull($secret);
        $this->assertEquals('Test key', $secret->metadata['description']);
        $this->assertEquals('dev', $secret->metadata['env']);
    }

    public function test_store_encrypts_value_before_persisting(): void
    {
        $this->service->store('sensitive.key', 'plaintext-value');

        $secret = Secret::where('key', 'sensitive.key')->first();

        // The stored value must NOT be the plaintext
        $this->assertNotEquals('plaintext-value', $secret->encrypted_value);
        // It must be decryptable back to the original
        $this->assertEquals('plaintext-value', app('encrypter')->decrypt($secret->encrypted_value));
    }

    public function test_store_overwrites_existing_key_and_archives_old_value(): void
    {
        $this->service->store('rotate.me', 'original-value');
        $this->service->store('rotate.me', 'new-value');

        // Should still be 1 active record
        $this->assertEquals(1, Secret::where('key', 'rotate.me')->where('is_active', true)->count());

        // Old value should be in secret_versions with reason "manual"
        $secret = Secret::where('key', 'rotate.me')->first();
        $this->assertEquals(1, $secret->versions()->where('archived_reason', 'manual')->count());
    }

    // -------------------------------------------------------------------------
    // GET (read-through)
    // -------------------------------------------------------------------------

    public function test_get_returns_decrypted_value_from_cache(): void
    {
        $this->service->store('cache.key', 'from-cache');

        // Value should come from cache (no DB query needed)
        $value = $this->service->get('cache.key');

        $this->assertEquals('from-cache', $value);
    }

    public function test_get_falls_back_to_database_when_cache_is_cold(): void
    {
        $this->service->store('db.fallback', 'persisted-value');

        // Flush cache to simulate cold start / cache eviction
        Cache::flush();

        $value = $this->service->get('db.fallback');

        $this->assertEquals('persisted-value', $value);
    }

    public function test_get_returns_null_for_nonexistent_key(): void
    {
        $value = $this->service->get('nonexistent.key');

        $this->assertNull($value);
    }

    // -------------------------------------------------------------------------
    // EXISTS
    // -------------------------------------------------------------------------

    public function test_exists_returns_true_for_active_secret(): void
    {
        $this->service->store('exists.key', 'value');

        $this->assertTrue($this->service->exists('exists.key'));
    }

    public function test_exists_returns_false_for_unknown_key(): void
    {
        $this->assertFalse($this->service->exists('ghost.key'));
    }

    public function test_exists_returns_true_even_after_cache_flush(): void
    {
        $this->service->store('persistent.key', 'value');
        Cache::flush();

        $this->assertTrue($this->service->exists('persistent.key'));
    }

    // -------------------------------------------------------------------------
    // DELETE
    // -------------------------------------------------------------------------

    public function test_delete_soft_deletes_from_database(): void
    {
        $this->service->store('to.delete', 'some-value');
        $this->service->delete('to.delete');

        // Record is soft-deleted — row still in DB but deleted_at set
        $this->assertSoftDeleted('secrets', ['key' => 'to.delete']);
    }

    public function test_delete_removes_from_cache(): void
    {
        $this->service->store('cached.to.delete', 'value');
        $this->service->delete('cached.to.delete');

        $this->assertFalse($this->service->exists('cached.to.delete'));
    }

    public function test_delete_returns_true_on_success(): void
    {
        $this->service->store('del.me', 'value');

        $this->assertTrue($this->service->delete('del.me'));
    }

    // -------------------------------------------------------------------------
    // LIST KEYS
    // -------------------------------------------------------------------------

    public function test_get_all_keys_returns_active_keys(): void
    {
        $this->service->store('key.alpha', 'v1');
        $this->service->store('key.beta', 'v2');
        $this->service->store('key.gamma', 'v3');
        $this->service->delete('key.gamma');

        $keys = $this->service->getAllKeys();

        $this->assertContains('key.alpha', $keys);
        $this->assertContains('key.beta', $keys);
        $this->assertNotContains('key.gamma', $keys);
    }

    public function test_get_all_keys_returns_empty_when_no_secrets(): void
    {
        $keys = $this->service->getAllKeys();

        $this->assertIsArray($keys);
        $this->assertEmpty($keys);
    }

    // -------------------------------------------------------------------------
    // ROTATE (archive + new version)
    // -------------------------------------------------------------------------

    public function test_rotate_increments_version(): void
    {
        $this->service->store('rotatable', 'v1-value');
        $this->service->rotate('rotatable', 'v2-value');

        $secret = Secret::where('key', 'rotatable')->first();
        $this->assertEquals(2, $secret->version);
    }

    public function test_rotate_archives_old_value_with_rotation_reason(): void
    {
        $this->service->store('archiveable', 'old-secret');
        $this->service->rotate('archiveable', 'new-secret');

        $secret = Secret::where('key', 'archiveable')->first();
        $versions = $secret->versions()->where('archived_reason', 'rotation')->get();

        $this->assertCount(1, $versions);
        // The archived version should have an expiry date 30 days out
        $this->assertNotNull($versions->first()->expires_at);
        $this->assertTrue($versions->first()->expires_at->isFuture());
    }

    public function test_rotate_new_value_is_retrievable(): void
    {
        $this->service->store('rotateable2', 'first-value');
        Cache::flush();
        $this->service->rotate('rotateable2', 'second-value');
        Cache::flush();

        $retrieved = $this->service->get('rotateable2');
        $this->assertEquals('second-value', $retrieved);
    }

    // -------------------------------------------------------------------------
    // SECRET VERSION model helpers
    // -------------------------------------------------------------------------

    public function test_secret_version_is_expired_returns_false_for_future_expiry(): void
    {
        $this->service->store('ver.test', 'initial');
        $this->service->rotate('ver.test', 'updated');

        $secret = Secret::where('key', 'ver.test')->first();
        $version = $secret->versions()->first();

        $this->assertFalse($version->isExpired());
    }
}

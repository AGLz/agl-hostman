# Secrets Management — Usage Guide

> **Frente B — Phase 3** | Implemented: 2026-05-18 | Branch: `chore/phase3-frente-b-secrets`

This guide explains how to use `SecretsManagementService` to store, retrieve, rotate, and delete encrypted secrets backed by PostgreSQL.

---

## Architecture Overview

```
Application code
      │
      ▼
SecretsManagementService
      │
      ├── Write-through → Redis cache (TTL 1h, hot reads)
      │
      └── Persistent    → PostgreSQL: tables `secrets` + `secret_versions`
                           (encryption-at-rest via Laravel AES-256-CBC)
```

**Key properties:**
- Values are **always encrypted** before reaching the DB (Laravel `Encrypter`).
- Cache is a read-optimization layer, **not** the source of truth.
- Secrets survive Redis restarts / flushes — PostgreSQL is the durable store.
- Rotated values are archived with a 30-day grace period.
- Deleted secrets are soft-deleted (row preserved for audit trail).

---

## Database Schema

### `secrets`

| Column            | Type      | Description                                      |
|-------------------|-----------|--------------------------------------------------|
| `id`              | bigint PK | Auto-increment                                   |
| `key`             | string    | Unique identifier (e.g. `"database.primary.password"`) |
| `encrypted_value` | text      | AES-256-CBC encrypted value                      |
| `metadata`        | json      | Arbitrary metadata (description, tags, etc.)     |
| `version`         | integer   | Rotation counter (starts at 1)                   |
| `is_active`       | boolean   | `false` = logically deleted                      |
| `created_at`      | timestamp |                                                  |
| `updated_at`      | timestamp |                                                  |
| `deleted_at`      | timestamp | Soft-delete (null = active)                      |

### `secret_versions`

| Column            | Type      | Description                                      |
|-------------------|-----------|--------------------------------------------------|
| `id`              | bigint PK |                                                  |
| `secret_id`       | bigint FK | References `secrets.id` (cascade delete)         |
| `encrypted_value` | text      | Snapshot of old encrypted value                  |
| `version`         | integer   | Version number at archival time                  |
| `archived_reason` | string    | `"rotation"` or `"manual"`                       |
| `archived_at`     | timestamp | When it was archived                             |
| `expires_at`      | timestamp | Grace period end (default 30 days; null = none)  |

---

## Running Migrations

```bash
# From src/ directory
php artisan migrate
```

Both tables are created by:
- `2026_05_17_000001_create_secrets_table.php`
- `2026_05_17_000002_create_secret_versions_table.php`

Roll back with:
```bash
php artisan migrate:rollback --step=2
```

---

## API Reference

Inject `SecretsManagementService` via Laravel's container:

```php
use App\Services\SecretsManagementService;

class MyController extends Controller
{
    public function __construct(private SecretsManagementService $secrets) {}
}
```

### `store(key, value, metadata = [], archiveOnOverwrite = true): bool`

Creates or updates a secret. If the key already exists, the old value is archived automatically.

```php
// Simple store
$this->secrets->store('database.primary.password', 'MyS3cretPass!');

// With metadata
$this->secrets->store('api.openai.key', 'sk-...', [
    'description' => 'OpenAI API key for LLM gateway',
    'env'         => 'production',
    'owner'       => 'platform-team',
]);
```

### `get(key, role = null): ?string`

Returns the decrypted value, or `null` if not found / access denied.

```php
$password = $this->secrets->get('database.primary.password');

// With RBAC check
$apiKey = $this->secrets->get('api.openai.key', role: 'operator');
```

Reads from **cache first**, falls back to PostgreSQL, then re-warms the cache.

### `exists(key): bool`

Returns `true` if an active secret with the given key exists.

```php
if (!$this->secrets->exists('database.primary.password')) {
    throw new RuntimeException('Database password not configured');
}
```

### `delete(key): bool`

Soft-deletes the secret. The row stays in the DB for audit; `exists()` and `get()` will return `false`/`null`.

```php
$this->secrets->delete('deprecated.api.key');
```

### `rotate(key, newValue, revokeOld = true): bool`

Stores the new value (incrementing version), archives the old value with reason `"rotation"` and a 30-day grace period.

```php
$this->secrets->rotate('database.primary.password', 'NewP@ss2026!');
```

### `getAllKeys(): array`

Returns all active secret keys, sorted alphabetically.

```php
$keys = $this->secrets->getAllKeys();
// => ["api.openai.key", "database.primary.password", ...]
```

### `listForRole(role): array`

Returns keys visible to the given RBAC role (filtered by `config/rbac.yaml`).

```php
$keys = $this->secrets->listForRole('operator');
// => ["deployment.*", "container.*" matches only]
```

### `generate(length = 32, hex = false): string`

Generates a cryptographically secure random secret.

```php
$newApiKey = $this->secrets->generate(32);
$hexToken  = $this->secrets->generate(16, hex: true);
```

### `validate(secret, rules = []): array{valid: bool, errors: string[]}`

Validates a secret against complexity rules.

```php
$result = $this->secrets->validate($newPassword, ['require_special' => true]);
if (!$result['valid']) {
    return response()->json(['errors' => $result['errors']], 422);
}
```

---

## Artisan Commands

### Backfill cache secrets to PostgreSQL

Use this **once** after deploying Frente B if secrets were stored in cache before the PostgreSQL backend was available:

```bash
# Dry-run (shows what would be backfilled)
php artisan secrets:backfill-from-cache --dry-run

# Backfill specific keys
php artisan secrets:backfill-from-cache --keys=database.primary.password --keys=api.openai.key
```

> **Note:** Because cache keys are stored as `secrets:<md5(key)>`, the backfill command cannot enumerate them automatically. Always pass `--keys=` explicitly.

---

## Practical Recipes

### 1. Store a new secret on first deploy

```bash
php artisan tinker
>>> app(\App\Services\SecretsManagementService::class)->store('github.webhook.secret', env('GITHUB_WEBHOOK_SECRET'), ['description' => 'GitHub webhook HMAC secret']);
```

### 2. Read a secret from application code

```php
$webhookSecret = app(\App\Services\SecretsManagementService::class)->get('github.webhook.secret');
```

### 3. Rotate a secret without downtime

```bash
php artisan tinker
>>> app(\App\Services\SecretsManagementService::class)->rotate('database.primary.password', 'NewSecurePass2026!');
```

Old value stays in `secret_versions` for 30 days (grace period for dependent services).

### 4. List all active secrets

```bash
php artisan tinker
>>> app(\App\Services\SecretsManagementService::class)->getAllKeys();
```

### 5. Verify a secret round-trip

```bash
php artisan tinker
>>> $svc = app(\App\Services\SecretsManagementService::class);
>>> $svc->store('test.roundtrip', 'hello');
>>> $svc->get('test.roundtrip');
=> "hello"
>>> \Illuminate\Support\Facades\Cache::flush(); // simulate cold cache
>>> $svc->get('test.roundtrip'); // reads from DB
=> "hello"
>>> \App\Models\Secret::where('key', 'test.roundtrip')->first()->encrypted_value; // must NOT be "hello"
```

---

## Zero-Downtime Migration Plan (B.4.6)

If you're migrating from a purely cache-based deployment:

1. **Deploy code** (this branch) — migrations run, tables created.
   - Existing secrets in Redis cache remain accessible via TTL.
   - New `store()` calls write to cache + DB simultaneously.

2. **Backfill** (optional, within 1h cache TTL window):
   ```bash
   php artisan secrets:backfill-from-cache --keys=<known-key-1> --keys=<known-key-2>
   ```

3. **Verify** all critical secrets exist in the DB:
   ```bash
   php artisan tinker
   >>> \App\Models\Secret::active()->count(); // should match expected secret count
   ```

4. After TTL window: cache miss → read from DB → re-warm cache automatically.

---

## Monitoring

| Metric | Alert |
|--------|-------|
| `p99` secret read latency | > 100ms (indicates DB slow query) |
| Cache miss rate | > 50% consistently (cache eviction / Redis issue) |
| `secret_versions` table size | > 10,000 rows (run grace period cleanup job) |

### Cleanup expired versions

Archive the cleanup in a scheduled command (future work):

```php
// Remove versions past their grace period
\App\Models\SecretVersion::where('expires_at', '<', now())->delete();
```

---

## Security Notes

1. **Never log secret values.** `SecretsManagementService` sanitizes keys in all log calls.
2. **Never store plaintext.** All values go through `Encrypter::encrypt()` before touching DB or cache.
3. **`APP_KEY` rotation:** If you rotate `APP_KEY`, all existing secrets become undecryptable. Document this procedure before rotating.
4. **Soft deletes preserve audit trail.** Do not hard-delete secrets unless explicitly required for compliance purge.

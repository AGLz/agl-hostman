<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\SecretsManagementService;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;

/**
 * Backfill secrets from cache into PostgreSQL.
 *
 * Use this once after deploying Frente B to persist any secrets that were
 * written to cache before the PostgreSQL backend was available.
 *
 * Usage:
 *   php artisan secrets:backfill-from-cache
 *   php artisan secrets:backfill-from-cache --dry-run
 */
class SecretsBackfillFromCache extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'secrets:backfill-from-cache
                            {--dry-run : Show what would be backfilled without writing to DB}
                            {--keys=* : Specific keys to backfill (default: all in cache)}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Backfill secrets from Redis cache into PostgreSQL (one-time migration helper)';

    public function handle(SecretsManagementService $secrets): int
    {
        $isDryRun = (bool) $this->option('dry-run');
        $specificKeys = (array) $this->option('keys');

        if ($isDryRun) {
            $this->warn('[DRY RUN] No changes will be written to the database.');
        }

        $this->info('Scanning Redis cache for secrets...');

        // Fetch all tracked keys from the DB first (already persisted)
        $existingDbKeys = $secrets->getAllKeys();

        if (count($specificKeys) > 0) {
            $keysToCheck = $specificKeys;
        } else {
            // getAllKeys() now returns DB keys; cache keys need separate discovery.
            // For the backfill scenario, the operator passes --keys explicitly OR
            // the command iterates cache keys via SCAN (Redis-only feature).
            $keysToCheck = $this->scanCacheKeys();
        }

        if (empty($keysToCheck)) {
            $this->info('No cache keys found. Nothing to backfill.');
            return self::SUCCESS;
        }

        $this->info(sprintf('Found %d candidate cache key(s).', count($keysToCheck)));
        $this->newLine();

        $backfilledCount = 0;
        $skippedCount = 0;
        $errorCount = 0;

        foreach ($keysToCheck as $key) {
            $cacheKey = 'secrets:' . md5($key);
            $secretData = Cache::get($cacheKey);

            if ($secretData === null) {
                $this->line("  [SKIP] {$key} — not found in cache");
                $skippedCount++;
                continue;
            }

            if (in_array($key, $existingDbKeys, true)) {
                $this->line("  [SKIP] {$key} — already persisted in DB");
                $skippedCount++;
                continue;
            }

            if ($isDryRun) {
                $this->info("  [DRY-RUN] Would backfill: {$key} (version {$secretData['version']})");
                $backfilledCount++;
                continue;
            }

            try {
                // Re-persist by calling the internal method directly
                $secrets->persistCacheEntry($key, $secretData);
                $this->info("  [OK] Backfilled: {$key} (version {$secretData['version']})");
                $backfilledCount++;
            } catch (\Throwable $e) {
                $this->error("  [ERROR] {$key}: {$e->getMessage()}");
                $errorCount++;
            }
        }

        $this->newLine();
        $this->line(sprintf(
            'Done. Backfilled: %d | Skipped: %d | Errors: %d',
            $backfilledCount,
            $skippedCount,
            $errorCount
        ));

        return $errorCount > 0 ? self::FAILURE : self::SUCCESS;
    }

    /**
     * Discover cache keys that look like secrets (keys matching "secrets:*").
     * Works only when the cache driver is Redis.
     *
     * @return array<string>
     */
    private function scanCacheKeys(): array
    {
        try {
            /** @var \Illuminate\Redis\Connections\PhpRedisConnection|\Illuminate\Redis\Connections\PredisConnection $redis */
            $redis = Cache::getStore()->getRedis()->connection();

            $prefix  = config('cache.prefix', 'laravel_cache') . ':secrets:';
            $pattern = $prefix . '*';

            $rawKeys = [];

            // Use SCAN for non-blocking iteration
            if (method_exists($redis, 'scan')) {
                $cursor = null;
                do {
                    [$cursor, $batch] = $redis->scan($cursor ?? 0, ['match' => $pattern, 'count' => 100]);
                    $rawKeys = array_merge($rawKeys, $batch);
                } while ($cursor !== '0' && $cursor !== 0);
            } else {
                $rawKeys = $redis->keys($pattern);
            }

            // The cache key is "secrets:<md5(secretKey)>" — we cannot reverse the MD5.
            // Return empty; operator must use --keys= to specify them explicitly.
            $this->warn('Note: Cache key MD5 hashes cannot be reversed automatically.');
            $this->warn('Use --keys="key1 key2" to specify which secrets to backfill.');

            return [];
        } catch (\Throwable) {
            // Non-Redis driver or connection issue
            $this->warn('Could not scan Redis keys. Use --keys=<key> to specify secrets.');
            return [];
        }
    }
}

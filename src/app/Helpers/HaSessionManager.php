<?php

namespace App\Helpers;

use Exception;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Redis;

/**
 * HA Session Manager
 *
 * Handles session management in high-availability distributed environment
 * Provides failover, replication, and locking capabilities
 */
class HaSessionManager
{
    /**
     * Redis connection instance
     */
    protected $redis;

    /**
     * Configuration
     */
    protected $config;

    /**
     * Session prefix
     */
    protected $prefix = 'session:';

    /**
     * Constructor
     */
    public function __construct()
    {
        $this->config = config('session.haproxy', []);
        $this->redis = Redis::connection()->client();
    }

    /**
     * Get session with failover support
     *
     * @return mixed|null
     */
    public function getSession(string $sessionId)
    {
        $key = $this->prefix.$sessionId;

        try {
            // Try primary Redis
            $data = $this->redis->get($key);

            if ($data !== null) {
                return unserialize($data);
            }

            return null;
        } catch (Exception $e) {
            Log::warning('Primary Redis unavailable for session read', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);

            // Try backup nodes
            return $this->getSessionFromBackup($sessionId);
        }
    }

    /**
     * Get session from backup Redis instances
     *
     * @return mixed|null
     */
    protected function getSessionFromBackup(string $sessionId)
    {
        if (empty($this->config['backup_nodes'])) {
            return null;
        }

        $key = $this->prefix.$sessionId;

        foreach ($this->config['backup_nodes'] as $name => $host) {
            try {
                $backupRedis = new \Redis;
                $backupRedis->connect($host, 6379);
                $backupRedis->auth(config('database.redis.default.password'));

                $data = $backupRedis->get($key);

                if ($data !== null) {
                    Log::info('Retrieved session from backup node', [
                        'session_id' => $sessionId,
                        'backup_node' => $name,
                    ]);

                    return unserialize($data);
                }

                $backupRedis->close();
            } catch (Exception $e) {
                Log::warning('Backup Redis unavailable', [
                    'backup_node' => $name,
                    'error' => $e->getMessage(),
                ]);

                continue;
            }
        }

        return null;
    }

    /**
     * Save session with replication
     *
     * @param  mixed  $data
     * @param  int  $ttl  Time to live in seconds
     */
    public function saveSession(string $sessionId, $data, int $ttl = 3600): bool
    {
        $key = $this->prefix.$sessionId;
        $serialized = serialize($data);

        try {
            // Save to primary
            $this->redis->setex($key, $ttl, $serialized);

            // Replicate to backups if enabled
            if ($this->config['replication']['enabled'] ?? false) {
                $this->replicateToBackups($key, $serialized, $ttl);
            }

            return true;
        } catch (Exception $e) {
            Log::error('Failed to save session', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Replicate session to backup nodes
     */
    protected function replicateToBackups(string $key, string $data, int $ttl): void
    {
        if (empty($this->config['backup_nodes'])) {
            return;
        }

        $mode = $this->config['replication']['mode'] ?? 'async';

        foreach ($this->config['backup_nodes'] as $name => $host) {
            try {
                $backupRedis = new \Redis;
                $backupRedis->connect($host, 6379);
                $backupRedis->auth(config('database.redis.default.password'));

                if ($mode === 'sync') {
                    $backupRedis->setex($key, $ttl, $data);
                } else {
                    // Async replication using pipeline
                    $backupRedis->pipeline(function ($pipe) use ($key, $ttl, $data) {
                        $pipe->setex($key, $ttl, $data);
                    });
                }

                $backupRedis->close();
            } catch (Exception $e) {
                Log::warning('Failed to replicate session to backup', [
                    'backup_node' => $name,
                    'error' => $e->getMessage(),
                ]);
            }
        }
    }

    /**
     * Acquire distributed lock for session
     *
     * @param  int  $timeout  Lock timeout in seconds
     */
    public function acquireLock(string $sessionId, int $timeout = 10): bool
    {
        if (! ($this->config['locking']['enabled'] ?? true)) {
            return true; // Locking disabled
        }

        $lockKey = 'lock:'.$this->prefix.$sessionId;
        $lockValue = uniqid('', true);
        $expiry = microtime(true) + $timeout;

        $maxRetries = $this->config['locking']['max_retries'] ?? 10;
        $retryInterval = $this->config['locking']['retry_interval'] ?? 100;

        for ($i = 0; $i < $maxRetries; $i++) {
            try {
                $acquired = $this->redis->set($lockKey, $lockValue, ['NX', 'EX' => $timeout]);

                if ($acquired) {
                    return true;
                }
            } catch (Exception $e) {
                Log::warning('Failed to acquire session lock', [
                    'session_id' => $sessionId,
                    'attempt' => $i + 1,
                    'error' => $e->getMessage(),
                ]);
            }

            usleep($retryInterval * 1000);
        }

        Log::error('Failed to acquire session lock after retries', [
            'session_id' => $sessionId,
            'max_retries' => $maxRetries,
        ]);

        return false;
    }

    /**
     * Release session lock
     */
    public function releaseLock(string $sessionId): bool
    {
        if (! ($this->config['locking']['enabled'] ?? true)) {
            return true;
        }

        $lockKey = 'lock:'.$this->prefix.$sessionId;

        try {
            $this->redis->del($lockKey);

            return true;
        } catch (Exception $e) {
            Log::error('Failed to release session lock', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Check if session is locked
     */
    public function isLocked(string $sessionId): bool
    {
        $lockKey = 'lock:'.$this->prefix.$sessionId;

        try {
            return $this->redis->exists($lockKey) > 0;
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Delete session
     */
    public function deleteSession(string $sessionId): bool
    {
        $key = $this->prefix.$sessionId;

        try {
            $this->redis->del($key);

            // Also delete from backups
            if (! empty($this->config['backup_nodes'])) {
                foreach ($this->config['backup_nodes'] as $name => $host) {
                    try {
                        $backupRedis = new \Redis;
                        $backupRedis->connect($host, 6379);
                        $backupRedis->auth(config('database.redis.default.password'));
                        $backupRedis->del($key);
                        $backupRedis->close();
                    } catch (Exception $e) {
                        // Continue with other backups
                    }
                }
            }

            return true;
        } catch (Exception $e) {
            Log::error('Failed to delete session', [
                'session_id' => $sessionId,
                'error' => $e->getMessage(),
            ]);

            return false;
        }
    }

    /**
     * Get session metadata
     */
    public function getSessionMetadata(string $sessionId): array
    {
        $key = 'meta:'.$this->prefix.$sessionId;

        try {
            $metadata = $this->redis->get($key);

            if ($metadata) {
                return json_decode($metadata, true);
            }

            return [];
        } catch (Exception $e) {
            return [];
        }
    }

    /**
     * Update session metadata
     */
    public function updateSessionMetadata(string $sessionId, array $metadata): bool
    {
        $key = 'meta:'.$this->prefix.$sessionId;

        try {
            $this->redis->setex($key, 3600, json_encode($metadata));

            return true;
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * Check health of session store
     */
    public function healthCheck(): array
    {
        $health = [
            'primary' => false,
            'backups' => [],
            'overall' => 'unhealthy',
        ];

        // Check primary
        try {
            $this->redis->ping();
            $health['primary'] = true;
        } catch (Exception $e) {
            $health['primary_error'] = $e->getMessage();
        }

        // Check backups
        if (! empty($this->config['backup_nodes'])) {
            foreach ($this->config['backup_nodes'] as $name => $host) {
                try {
                    $backupRedis = new \Redis;
                    $backupRedis->connect($host, 6379);
                    $backupRedis->auth(config('database.redis.default.password'));
                    $backupRedis->ping();
                    $backupRedis->close();

                    $health['backups'][$name] = true;
                } catch (Exception $e) {
                    $health['backups'][$name] = false;
                    $health['backups'][$name.'_error'] = $e->getMessage();
                }
            }
        }

        // Determine overall health
        $backupHealthy = count(array_filter($health['backups']));
        if ($health['primary'] && $backupHealthy >= 1) {
            $health['overall'] = 'healthy';
        } elseif ($backupHealthy >= 2) {
            $health['overall'] = 'degraded';
        }

        return $health;
    }
}

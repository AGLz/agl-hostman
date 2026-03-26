<?php

namespace App\Services\Health;

use Carbon\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;

class HealthCheckService
{
    private array $results = [];

    private bool $allHealthy = true;

    /**
     * Run all health checks
     */
    public function checkAll(): array
    {
        $this->checkDatabase();
        $this->checkRedis();
        $this->checkStorage();
        $this->checkExternalServices();
        $this->checkQueueWorkers();
        $this->checkWebSocketServer();
        $this->checkSSLCertificates();

        return [
            'healthy' => $this->allHealthy,
            'checks' => $this->results,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Check database connectivity
     */
    private function checkDatabase(): void
    {
        try {
            DB::connection()->getPdo();
            $this->recordCheck('database', 'healthy', 'PostgreSQL connection OK');
        } catch (\Exception $e) {
            $this->recordCheck('database', 'unhealthy', 'PostgreSQL connection failed: '.$e->getMessage(), 'critical');
        }
    }

    /**
     * Check Redis connectivity
     */
    private function checkRedis(): void
    {
        try {
            Redis::ping();
            $this->recordCheck('redis', 'healthy', 'Redis connection OK');
        } catch (\Exception $e) {
            $this->recordCheck('redis', 'unhealthy', 'Redis connection failed: '.$e->getMessage(), 'critical');
        }
    }

    /**
     * Check storage availability
     */
    private function checkStorage(): void
    {
        try {
            $disk = Storage::disk('local');
            $testFile = 'health_check_'.time().'.txt';

            $disk->put($testFile, 'health check');
            $disk->delete($testFile);

            // Check disk space
            $path = storage_path();
            $freeSpace = disk_free_space($path);
            $totalSpace = disk_total_space($path);
            $usedPercent = (($totalSpace - $freeSpace) / $totalSpace) * 100;

            if ($usedPercent > 90) {
                $this->recordCheck('storage', 'warning', "Disk usage at {$usedPercent}%", 'important');
            } else {
                $this->recordCheck('storage', 'healthy', "Disk usage at {$usedPercent}%");
            }
        } catch (\Exception $e) {
            $this->recordCheck('storage', 'unhealthy', 'Storage check failed: '.$e->getMessage(), 'critical');
        }
    }

    /**
     * Check external service connectivity
     */
    private function checkExternalServices(): void
    {
        $services = [
            'proxmox' => config('proxmox.api_url'),
            'dokploy' => config('dokploy.base_url'),
            'harbor' => config('services.harbor.url'),
            'github' => 'https://api.github.com',
        ];

        foreach ($services as $name => $url) {
            if (! $url) {
                continue;
            }

            try {
                $response = Http::timeout(5)->get($url);

                if ($response->successful() || $response->status() === 401) {
                    // 401 is OK - service is responding
                    $this->recordCheck("external_{$name}", 'healthy', "{$name} API responding");
                } else {
                    $this->recordCheck("external_{$name}", 'warning', "{$name} returned status {$response->status()}", 'important');
                }
            } catch (\Exception $e) {
                $this->recordCheck("external_{$name}", 'warning', "{$name} connection failed", 'optional');
            }
        }
    }

    /**
     * Check queue worker status
     */
    private function checkQueueWorkers(): void
    {
        try {
            // Check if jobs are being processed
            $queueSize = Redis::llen('queues:default');

            // Check for stuck jobs (jobs older than 1 hour)
            $oldJobs = DB::table('jobs')
                ->where('created_at', '<', now()->subHour())
                ->count();

            if ($oldJobs > 10) {
                $this->recordCheck('queue_workers', 'warning', "{$oldJobs} stuck jobs detected", 'important');
            } elseif ($queueSize > 1000) {
                $this->recordCheck('queue_workers', 'warning', "Large queue backlog: {$queueSize} jobs", 'important');
            } else {
                $this->recordCheck('queue_workers', 'healthy', "Queue healthy ({$queueSize} jobs)");
            }
        } catch (\Exception $e) {
            $this->recordCheck('queue_workers', 'unhealthy', 'Queue check failed: '.$e->getMessage(), 'important');
        }
    }

    /**
     * Check WebSocket server (Laravel Reverb)
     */
    private function checkWebSocketServer(): void
    {
        try {
            $wsUrl = config('broadcasting.connections.reverb.host');
            $wsPort = config('broadcasting.connections.reverb.port');

            if (! $wsUrl || ! $wsPort) {
                $this->recordCheck('websocket', 'warning', 'WebSocket not configured', 'optional');

                return;
            }

            // Try to connect to health endpoint
            $healthUrl = "http://{$wsUrl}:{$wsPort}/health";
            $response = Http::timeout(3)->get($healthUrl);

            if ($response->successful()) {
                $this->recordCheck('websocket', 'healthy', 'WebSocket server responding');
            } else {
                $this->recordCheck('websocket', 'warning', 'WebSocket server unhealthy', 'important');
            }
        } catch (\Exception $e) {
            $this->recordCheck('websocket', 'warning', 'WebSocket check failed', 'optional');
        }
    }

    /**
     * Check SSL certificate expiry
     */
    private function checkSSLCertificates(): void
    {
        $domains = [
            config('app.url'),
            config('dokploy.base_url'),
        ];

        foreach ($domains as $url) {
            if (! $url || ! str_starts_with($url, 'https://')) {
                continue;
            }

            try {
                $host = parse_url($url, PHP_URL_HOST);
                $get = stream_context_create([
                    'ssl' => [
                        'capture_peer_cert' => true,
                        'verify_peer' => false,
                        'verify_peer_name' => false,
                    ],
                ]);

                $read = @stream_socket_client("ssl://{$host}:443", $errno, $errstr, 30, STREAM_CLIENT_CONNECT, $get);

                if ($read === false) {
                    continue;
                }

                $cert = stream_context_get_params($read);
                $certInfo = openssl_x509_parse($cert['options']['ssl']['peer_certificate']);

                $validUntil = Carbon::createFromTimestamp($certInfo['validTo_time_t']);
                $daysRemaining = now()->diffInDays($validUntil, false);

                if ($daysRemaining < 7) {
                    $this->recordCheck("ssl_{$host}", 'unhealthy', "SSL expires in {$daysRemaining} days", 'critical');
                } elseif ($daysRemaining < 30) {
                    $this->recordCheck("ssl_{$host}", 'warning', "SSL expires in {$daysRemaining} days", 'important');
                } else {
                    $this->recordCheck("ssl_{$host}", 'healthy', "SSL valid for {$daysRemaining} days");
                }
            } catch (\Exception $e) {
                $this->recordCheck("ssl_{$host}", 'warning', 'SSL check failed', 'optional');
            }
        }
    }

    /**
     * Record check result
     */
    private function recordCheck(string $name, string $status, string $message, string $severity = 'optional'): void
    {
        $this->results[] = [
            'name' => $name,
            'status' => $status,
            'message' => $message,
            'severity' => $severity,
            'timestamp' => now()->toIso8601String(),
        ];

        if ($status === 'unhealthy' && in_array($severity, ['critical', 'important'])) {
            $this->allHealthy = false;
        }
    }

    /**
     * Get summary status
     */
    public function getSummary(): array
    {
        $results = $this->checkAll();

        $statusCounts = [
            'healthy' => 0,
            'warning' => 0,
            'unhealthy' => 0,
        ];

        foreach ($results['checks'] as $check) {
            $statusCounts[$check['status']]++;
        }

        return [
            'overall_status' => $results['healthy'] ? 'healthy' : 'unhealthy',
            'total_checks' => count($results['checks']),
            'status_breakdown' => $statusCounts,
            'critical_issues' => array_filter($results['checks'], fn ($c) => $c['status'] === 'unhealthy' && $c['severity'] === 'critical'
            ),
            'timestamp' => $results['timestamp'],
        ];
    }
}

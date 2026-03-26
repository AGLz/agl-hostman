<?php

namespace App\Services;

use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Redis;

/**
 * Deployment Service
 *
 * Comprehensive deployment management service supporting:
 * - Blue-green deployment strategy
 * - Zero-downtime deployments
 * - Rollback capabilities
 * - Health checks and monitoring
 * - Deployment notifications
 */
class DeploymentService
{
    /**
     * Deployment slots for blue-green strategy
     */
    const SLOT_BLUE = 'blue';

    const SLOT_GREEN = 'green';

    /**
     * Traffic switch percentages for gradual rollout
     */
    const TRAFFIC_INTERVALS = [10, 50, 100];

    /**
     * Health check retry configuration
     */
    const HEALTH_CHECK_RETRIES = 30;

    const HEALTH_CHECK_INTERVAL = 10; // seconds

    /**
     * Monitoring window after traffic switch
     */
    const MONITOR_DURATION = 300; // 5 minutes

    /**
     * Rollback window duration
     */
    const ROLLBACK_WINDOW = 3600; // 1 hour

    /**
     * Error rate threshold for automatic rollback
     */
    const ERROR_RATE_THRESHOLD = 0.05; // 5%

    /**
     * Response time threshold (milliseconds)
     */
    const RESPONSE_TIME_THRESHOLD = 500;

    /**
     * Get the current active deployment slot.
     */
    public function getActiveSlot(string $environment = 'production'): string
    {
        $key = "deployment:{$environment}:active_slot";

        return Redis::get($key, self::SLOT_BLUE);
    }

    /**
     * Get the inactive deployment slot.
     */
    public function getInactiveSlot(string $environment = 'production'): string
    {
        $active = $this->getActiveSlot($environment);

        return $active === self::SLOT_BLUE ? self::SLOT_GREEN : self::SLOT_BLUE;
    }

    /**
     * Deploy to a specific slot.
     */
    public function deployToSlot(string $slot, string $version, string $environment = 'production'): array
    {
        Log::info("Deploying version {$version} to {$slot} slot", [
            'environment' => $environment,
            'slot' => $slot,
            'version' => $version,
        ]);

        try {
            $dokployUrl = $this->getDokployUrl($environment);
            $dokployToken = $this->getDokployToken($environment);

            $response = Http::timeout(300)->post("{$dokployUrl}/api/v1/deploy/slot", [
                'slot' => $slot,
                'version' => $version,
                'environment' => $environment,
            ], [
                'Authorization' => "Bearer {$dokployToken}",
                'Accept' => 'application/json',
            ]);

            if ($response->successful()) {
                $deploymentId = $response->json('deployment_id');

                // Store deployment info
                $this->storeDeploymentInfo($environment, $slot, $version, $deploymentId);

                return [
                    'success' => true,
                    'deployment_id' => $deploymentId,
                    'slot' => $slot,
                    'version' => $version,
                ];
            }

            return [
                'success' => false,
                'message' => 'Deployment failed',
                'error' => $response->body(),
            ];
        } catch (\Exception $e) {
            Log::error('Deployment to slot failed', [
                'slot' => $slot,
                'version' => $version,
                'error' => $e->getMessage(),
            ]);

            return [
                'success' => false,
                'message' => 'Deployment failed',
                'error' => $e->getMessage(),
            ];
        }
    }

    /**
     * Wait for deployment to complete.
     */
    public function waitForDeployment(string $deploymentId, string $environment = 'production', int $timeout = 600): array
    {
        $dokployUrl = $this->getDokployUrl($environment);
        $dokployToken = $this->getDokployToken($environment);
        $startTime = now();

        while (now()->diffInSeconds($startTime) < $timeout) {
            $response = Http::timeout(10)->get("{$dokployUrl}/api/v1/deployments/{$deploymentId}", [
                'Authorization' => "Bearer {$dokployToken}",
            ]);

            if ($response->successful()) {
                $status = $response->json('status');

                return match ($status) {
                    'success' => ['success' => true, 'status' => $status],
                    'failed', 'error' => ['success' => false, 'status' => $status],
                    default => ['success' => false, 'status' => $status],
                };
            }

            sleep(5);
        }

        return [
            'success' => false,
            'message' => 'Deployment timeout',
        ];
    }

    /**
     * Run health checks on a specific slot.
     */
    public function runHealthChecks(string $slot, string $environment = 'production'): array
    {
        $domain = $this->getDomain($environment);
        $healthUrl = "https://{$slot}-{$domain}/api/health";

        Log::info("Running health checks for {$slot} slot", ['url' => $healthUrl]);

        $checks = [
            'http' => false,
            'database' => false,
            'cache' => false,
            'queue' => false,
        ];

        // HTTP health check
        for ($i = 0; $i < self::HEALTH_CHECK_RETRIES; $i++) {
            $response = Http::timeout(5)->get($healthUrl);

            if ($response->successful()) {
                $checks['http'] = true;

                // Check detailed health
                $data = $response->json();
                $checks['database'] = $data['components']['database']['status'] === 'ok' ?? false;
                $checks['cache'] = $data['components']['cache']['status'] === 'ok' ?? false;
                $checks['queue'] = $data['components']['queue']['status'] === 'ok' ?? false;

                break;
            }

            sleep(self::HEALTH_CHECK_INTERVAL);
        }

        $healthy = $checks['http'] && $checks['database'] && $checks['cache'];

        return [
            'healthy' => $healthy,
            'checks' => $checks,
            'url' => $healthUrl,
        ];
    }

    /**
     * Run smoke tests on a specific slot.
     */
    public function runSmokeTests(string $slot, string $environment = 'production'): array
    {
        $domain = $this->getDomain($environment);
        $baseUrl = "https://{$slot}-{$domain}";

        $endpoints = [
            '/api/health',
            '/api/overview',
            '/api/containers',
            '/api/vms',
        ];

        $results = [];
        $passed = 0;
        $failed = 0;

        foreach ($endpoints as $endpoint) {
            $url = $baseUrl.$endpoint;
            $response = Http::timeout(10)->get($url);

            $results[$endpoint] = [
                'success' => $response->successful(),
                'status' => $response->status(),
            ];

            if ($response->successful()) {
                $passed++;
            } else {
                $failed++;
            }
        }

        return [
            'success' => $failed === 0,
            'passed' => $passed,
            'failed' => $failed,
            'results' => $results,
        ];
    }

    /**
     * Switch traffic between slots gradually.
     */
    public function gradualTrafficSwitch(string $fromSlot, string $toSlot, string $environment = 'production'): array
    {
        $lbApiUrl = config("deployment.{$environment}.lb_api_url");
        $lbToken = config("deployment.{$environment}.lb_token");

        Log::info('Starting gradual traffic switch', [
            'from' => $fromSlot,
            'to' => $toSlot,
            'environment' => $environment,
        ]);

        foreach (self::TRAFFIC_INTERVALS as $percentage) {
            Log::info("Switching {$percentage}% traffic to {$toSlot}");

            $response = Http::timeout(30)->post("{$lbApiUrl}/traffic", [
                'from' => $fromSlot,
                'to' => $toSlot,
                'percentage' => $percentage,
            ], [
                'Authorization' => "Bearer {$lbToken}",
            ]);

            if (! $response->successful()) {
                return [
                    'success' => false,
                    'message' => "Failed to switch traffic to {$percentage}%",
                    'error' => $response->body(),
                ];
            }

            // Monitor for issues before next switch
            $monitorResult = $this->monitorDeployment($toSlot, $environment, 60);

            if (! $monitorResult['healthy']) {
                return [
                    'success' => false,
                    'message' => "Issues detected at {$percentage}% traffic",
                    'monitor_result' => $monitorResult,
                ];
            }

            sleep(30);
        }

        return ['success' => true];
    }

    /**
     * Monitor deployment for issues.
     */
    public function monitorDeployment(string $slot, string $environment = 'production', int $duration = self::MONITOR_DURATION): array
    {
        $domain = $this->getDomain($environment);
        $metricsUrl = "https://{$slot}-{$domain}/api/metrics";

        $startTime = now();
        $errorRateSamples = [];
        $responseTimeSamples = [];

        while (now()->diffInSeconds($startTime) < $duration) {
            $response = Http::timeout(5)->get($metricsUrl);

            if ($response->successful()) {
                $metrics = $response->json();

                $errorRateSamples[] = $metrics['error_rate'] ?? 0;
                $responseTimeSamples[] = $metrics['avg_response_time'] ?? 0;

                // Check thresholds
                $avgErrorRate = collect($errorRateSamples)->avg();
                $avgResponseTime = collect($responseTimeSamples)->avg();

                if ($avgErrorRate > self::ERROR_RATE_THRESHOLD) {
                    return [
                        'healthy' => false,
                        'reason' => 'error_rate_exceeded',
                        'error_rate' => $avgErrorRate,
                        'threshold' => self::ERROR_RATE_THRESHOLD,
                    ];
                }

                if ($avgResponseTime > self::RESPONSE_TIME_THRESHOLD) {
                    return [
                        'healthy' => false,
                        'reason' => 'response_time_exceeded',
                        'response_time' => $avgResponseTime,
                        'threshold' => self::RESPONSE_TIME_THRESHOLD,
                    ];
                }
            }

            sleep(30);
        }

        return [
            'healthy' => true,
            'avg_error_rate' => collect($errorRateSamples)->avg(),
            'avg_response_time' => collect($responseTimeSamples)->avg(),
        ];
    }

    /**
     * Activate a slot as the primary.
     */
    public function activateSlot(string $slot, string $environment = 'production'): bool
    {
        $key = "deployment:{$environment}:active_slot";
        Redis::set($key, $slot);

        // Store previous slot for rollback
        $previousSlot = $slot === self::SLOT_BLUE ? self::SLOT_GREEN : self::SLOT_BLUE;
        Redis::set("deployment:{$environment}:previous_slot", $previousSlot);
        Redis::set("deployment:{$environment}:rollback_expires", now()->addSeconds(self::ROLLBACK_WINDOW)->timestamp);

        Log::info("Activated {$slot} slot", [
            'environment' => $environment,
            'previous_slot' => $previousSlot,
            'rollback_window' => self::ROLLBACK_WINDOW,
        ]);

        return true;
    }

    /**
     * Rollback to the previous slot.
     */
    public function rollback(string $environment = 'production'): array
    {
        $previousSlot = Redis::get("deployment:{$environment}:previous_slot");
        $rollbackExpires = Redis::get("deployment:{$environment}:rollback_expires");

        if (! $previousSlot || ! $rollbackExpires) {
            return [
                'success' => false,
                'message' => 'No rollback target available',
            ];
        }

        if (now()->timestamp > $rollbackExpires) {
            return [
                'success' => false,
                'message' => 'Rollback window has expired',
            ];
        }

        Log::warning("Initiating rollback to {$previousSlot}", [
            'environment' => $environment,
        ]);

        // Switch traffic immediately
        $activeSlot = $this->getActiveSlot($environment);
        $result = $this->gradualTrafficSwitch($activeSlot, $previousSlot, $environment);

        if (! $result['success']) {
            return [
                'success' => false,
                'message' => 'Rollback traffic switch failed',
                'error' => $result['error'] ?? null,
            ];
        }

        // Verify health
        $healthCheck = $this->runHealthChecks($previousSlot, $environment);

        if (! $healthCheck['healthy']) {
            return [
                'success' => false,
                'message' => 'Rollback target is unhealthy',
                'health_check' => $healthCheck,
            ];
        }

        // Activate rollback slot
        $this->activateSlot($previousSlot, $environment);

        return [
            'success' => true,
            'message' => 'Rollback completed successfully',
            'active_slot' => $previousSlot,
        ];
    }

    /**
     * Send deployment notification.
     */
    public function sendNotification(string $status, array $data = []): bool
    {
        $webhookUrl = config('deployment.slack_webhook_url');

        if (! $webhookUrl) {
            return false;
        }

        $color = match ($status) {
            'success' => '#36a64f',
            'failure' => '#dc3545',
            'warning' => '#ffc107',
            default => '#6c757d',
        };

        $payload = [
            'attachments' => [
                [
                    'color' => $color,
                    'title' => "Deployment {$status}",
                    'fields' => [
                        ['title' => 'Environment', 'value' => $data['environment'] ?? 'unknown', 'short' => true],
                        ['title' => 'Version', 'value' => $data['version'] ?? 'latest', 'short' => true],
                        ['title' => 'Slot', 'value' => $data['slot'] ?? 'unknown', 'short' => true],
                        ['title' => 'Duration', 'value' => $data['duration'] ?? '-', 'short' => true],
                    ],
                    'footer' => 'AGL Hostman Deployment Service',
                    'ts' => now()->timestamp,
                ],
            ],
        ];

        try {
            Http::post($webhookUrl, $payload);

            return true;
        } catch (\Exception $e) {
            Log::error('Failed to send deployment notification', ['error' => $e->getMessage()]);

            return false;
        }
    }

    /**
     * Store deployment information.
     */
    protected function storeDeploymentInfo(string $environment, string $slot, string $version, string $deploymentId): void
    {
        $key = "deployment:{$environment}:{$slot}";
        Redis::hmset($key, [
            'version' => $version,
            'deployment_id' => $deploymentId,
            'deployed_at' => now()->toIso8601String(),
        ]);
        Redis::expire($key, 86400 * 7); // Keep for 7 days
    }

    /**
     * Get domain for environment.
     */
    protected function getDomain(string $environment): string
    {
        return match ($environment) {
            'production' => config('deployment.production.domain', 'prod-agl.aglz.io'),
            'staging' => config('deployment.staging.domain', 'staging-agl.aglz.io'),
            default => "{$environment}-agl.aglz.io",
        };
    }

    /**
     * Get Dokploy URL for environment.
     */
    protected function getDokployUrl(string $environment): string
    {
        return config("deployment.{$environment}.dokploy_url");
    }

    /**
     * Get Dokploy token for environment.
     */
    protected function getDokployToken(string $environment): string
    {
        return config("deployment.{$environment}.dokploy_token");
    }
}

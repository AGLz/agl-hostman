<?php

namespace App\Jobs;

use App\Models\PhysicalLocation;
use App\Services\N8NService;
use App\Services\AIModelService;
use App\Services\InfrastructureAnalyticsService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Cache;

class MonitorInfrastructure implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    protected array $servers;
    protected string $monitoringType;

    /**
     * Create a new job instance.
     */
    public function __construct(array $servers, string $monitoringType = 'health')
    {
        $this->servers = $servers;
        $this->monitoringType = $monitoringType;
    }

    /**
     * Execute the job.
     */
    public function handle(
        N8NService $n8nService, 
        AIModelService $aiService,
        InfrastructureAnalyticsService $analyticsService
    ): void
    {
        Log::info('Starting infrastructure monitoring', [
            'servers' => $this->servers,
            'type' => $this->monitoringType,
        ]);

        $results = [];
        
        foreach ($this->servers as $serverCode) {
            $location = PhysicalLocation::where('code', $serverCode)->first();
            
            if (!$location) {
                Log::warning("Server not found: {$serverCode}");
                continue;
            }

            $result = $this->monitorServer($location);
            $results[$serverCode] = $result;

            // Store in cache for quick access
            Cache::put("server_status_{$serverCode}", $result, now()->addMinutes(5));

            // If issues detected, trigger AI analysis
            if ($result['status'] === 'warning' || $result['status'] === 'critical') {
                $this->triggerAIAnalysis($location, $result, $aiService);
            }
        }

        // Send results to N8N for workflow processing
        $n8nService->triggerMonitoring($this->servers);

        // Store aggregated results
        Cache::put('infrastructure_status', $results, now()->addMinutes(5));

        // Perform AI analytics
        $analytics = $analyticsService->analyzeInfrastructure($results);
        
        // Broadcast updates for real-time dashboard
        foreach ($results as $serverCode => $status) {
            $analyticsService->broadcastUpdate($serverCode, $status);
        }

        Log::info('Infrastructure monitoring completed', [
            'results' => $results,
            'analytics' => $analytics,
        ]);
    }

    /**
     * Monitor a specific server
     */
    protected function monitorServer(PhysicalLocation $location): array
    {
        $status = 'healthy';
        $metrics = [];
        $issues = [];

        // Extract IP from ip_range (e.g., "192.168.0.245/32" -> "192.168.0.245")
        $ip = explode('/', $location->ip_range)[0];

        // Ping test
        $pingResult = $this->pingServer($ip);
        $metrics['ping'] = $pingResult;

        if (!$pingResult['success']) {
            $status = 'critical';
            $issues[] = 'Server unreachable';
        }

        // For containers, check specific services
        if ($location->type === 'container') {
            $metrics['services'] = $this->checkContainerServices($location);
        }

        // For datacenters, check resource usage
        if ($location->type === 'datacenter') {
            $metrics['resources'] = $this->checkDatacenterResources($location);
        }

        return [
            'location' => $location->code,
            'name' => $location->name,
            'type' => $location->type,
            'status' => $status,
            'metrics' => $metrics,
            'issues' => $issues,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Ping server to check availability
     */
    protected function pingServer(string $ip): array
    {
        $startTime = microtime(true);
        $result = exec("ping -c 1 -W 1 {$ip}", $output, $returnCode);
        $responseTime = (microtime(true) - $startTime) * 1000;

        return [
            'success' => $returnCode === 0,
            'response_time' => round($responseTime, 2),
            'ip' => $ip,
        ];
    }

    /**
     * Check container-specific services
     */
    protected function checkContainerServices(PhysicalLocation $location): array
    {
        $services = [];
        
        // Check based on container metadata
        if ($location->code === 'CT179') {
            // Development container with Docker
            $services['docker'] = $this->checkDockerStatus($location->ip_range);
        }
        
        if ($location->code === 'CT180') {
            // Dokploy container
            $services['dokploy'] = $this->checkHttpService('https://dok.aglz.io');
        }
        
        if ($location->code === 'CT183') {
            // Archon container
            $services['archon'] = $this->checkHttpService('https://archon.aglz.io');
        }

        return $services;
    }

    /**
     * Check datacenter resources
     */
    protected function checkDatacenterResources(PhysicalLocation $location): array
    {
        // This would typically connect to Proxmox API or monitoring system
        return [
            'cpu_usage' => rand(20, 80), // Simulated for now
            'memory_usage' => rand(40, 90),
            'disk_usage' => rand(30, 70),
            'container_count' => $location->metadata['containers'] ?? 0,
        ];
    }

    /**
     * Check Docker status
     */
    protected function checkDockerStatus(string $ip): bool
    {
        // Would typically SSH and check docker status
        return true; // Simulated
    }

    /**
     * Check HTTP service availability
     */
    protected function checkHttpService(string $url): bool
    {
        try {
            $response = Http::timeout(5)->get($url);
            return $response->successful();
        } catch (\Exception $e) {
            return false;
        }
    }

    /**
     * Trigger AI analysis for issues
     */
    protected function triggerAIAnalysis(PhysicalLocation $location, array $result, AIModelService $aiService): void
    {
        $prompt = "Analyze the following infrastructure issue:\n" .
                  "Server: {$location->name} ({$location->code})\n" .
                  "Type: {$location->type}\n" .
                  "Status: {$result['status']}\n" .
                  "Issues: " . implode(', ', $result['issues']) . "\n" .
                  "Metrics: " . json_encode($result['metrics']) . "\n\n" .
                  "Provide recommendations for resolution.";

        dispatch(new ProcessAIRequest('claude', $prompt, [
            'context' => 'infrastructure_monitoring',
            'server' => $location->code,
        ]));
    }

    /**
     * Get the tags that should be assigned to this job.
     */
    public function tags(): array
    {
        return ['monitoring', 'infrastructure', ...$this->servers];
    }
}
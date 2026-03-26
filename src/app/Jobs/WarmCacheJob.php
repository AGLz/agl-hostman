<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Services\DokployService;
use App\Services\HarborService;
use App\Services\ProxmoxService;
use App\Services\RedisCacheStrategy;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

/**
 * Cache Warming Job
 *
 * Warms up Redis cache with frequently accessed data from external services.
 * Runs on schedule to ensure cache is fresh and ready for peak usage.
 */
class WarmCacheJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    private RedisCacheStrategy $cacheStrategy;

    private ProxmoxService $proxmox;

    private DokployService $dokploy;

    private HarborService $harbor;

    /**
     * The number of times the job may be attempted.
     *
     * @var int
     */
    public $tries = 3;

    /**
     * The maximum number of unhandled exceptions to allow before failing.
     *
     * @var int
     */
    public $maxExceptions = 3;

    /**
     * The number of seconds the job can run before timing out.
     *
     * @var int
     */
    public $timeout = 300; // 5 minutes

    public function __construct(
        RedisCacheStrategy $cacheStrategy,
        ProxmoxService $proxmox,
        DokployService $dokploy,
        HarborService $harbor
    ) {
        $this->cacheStrategy = $cacheStrategy;
        $this->proxmox = $proxmox;
        $this->dokploy = $dokploy;
        $this->harbor = $harbor;
    }

    /**
     * Execute the job.
     */
    public function handle(): void
    {
        Log::info('Starting cache warming');

        $startTime = microtime(true);
        $warmedItems = 0;

        try {
            // Warm Proxmox cache
            $warmedItems += $this->warmProxmoxCache();

            // Warm Dokploy cache
            $warmedItems += $this->warmDokployCache();

            // Warm Harbor cache
            $warmedItems += $this->warmHarborCache();

            // Warm database cache
            $warmedItems += $this->warmDatabaseCache();

            $duration = round(microtime(true) - $startTime, 2);

            Log::info('Cache warming completed', [
                'items_warmed' => $warmedItems,
                'duration' => $duration,
            ]);

        } catch (\Exception $e) {
            Log::error('Cache warming failed', [
                'error' => $e->getMessage(),
                'trace' => $e->getTraceAsString(),
            ]);

            throw $e;
        }
    }

    /**
     * Warm Proxmox cache
     *
     * @return int Number of items warmed
     */
    private function warmProxmoxCache(): int
    {
        $count = 0;

        try {
            // Warm servers list
            $servers = $this->cacheStrategy->cacheProxmoxResponse(
                'nodes',
                null,
                fn () => $this->proxmox->getNodes(),
                'short'
            );
            $count++;

            // Warm containers list
            $containers = $this->cacheStrategy->cacheProxmoxResponse(
                'containers',
                null,
                fn () => $this->proxmox->getContainers(),
                'short'
            );
            $count++;

            // Warm individual container data (last 20 containers)
            if (isset($containers['data']) && is_array($containers['data'])) {
                $recentContainers = array_slice($containers['data'], 0, 20);

                foreach ($recentContainers as $container) {
                    if (isset($container['vmid'])) {
                        $this->cacheStrategy->cacheProxmoxResponse(
                            'container',
                            $container['vmid'],
                            fn () => $this->proxmox->getContainer($container['vmid']),
                            'short'
                        );
                        $count++;
                    }
                }
            }

            Log::info('Proxmox cache warmed', ['items' => $count]);

        } catch (\Exception $e) {
            Log::warning('Failed to warm Proxmox cache', [
                'error' => $e->getMessage(),
            ]);
        }

        return $count;
    }

    /**
     * Warm Dokploy cache
     *
     * @return int Number of items warmed
     */
    private function warmDokployCache(): int
    {
        $count = 0;

        try {
            // Warm applications list
            $applications = $this->cacheStrategy->cacheDokployResponse(
                'applications',
                null,
                fn () => $this->dokploy->getApplications(),
                'medium'
            );
            $count++;

            // Warm recent deployments (last 10)
            if (isset($applications['data']) && is_array($applications['data'])) {
                foreach (array_slice($applications['data'], 0, 10) as $app) {
                    if (isset($app['id'])) {
                        $deployments = $this->cacheStrategy->cacheDokployResponse(
                            'deployments',
                            $app['id'],
                            fn () => $this->dokploy->getApplicationDeployments($app['id']),
                            'medium'
                        );
                        $count++;
                    }
                }
            }

            Log::info('Dokploy cache warmed', ['items' => $count]);

        } catch (\Exception $e) {
            Log::warning('Failed to warm Dokploy cache', [
                'error' => $e->getMessage(),
            ]);
        }

        return $count;
    }

    /**
     * Warm Harbor cache
     *
     * @return int Number of items warmed
     */
    private function warmHarborCache(): int
    {
        $count = 0;

        try {
            // Warm projects list
            $projects = $this->cacheStrategy->cacheHarborResponse(
                'projects',
                null,
                fn () => $this->harbor->getProjects(),
                'long'
            );
            $count++;

            // Warm repositories for each project
            if (isset($projects['data']) && is_array($projects['data'])) {
                foreach ($projects['data'] as $project) {
                    if (isset($project['name'])) {
                        $repositories = $this->cacheStrategy->cacheHarborResponse(
                            'repositories',
                            $project['name'],
                            fn () => $this->harbor->getRepositories($project['name']),
                            'long'
                        );
                        $count++;
                    }
                }
            }

            Log::info('Harbor cache warmed', ['items' => $count]);

        } catch (\Exception $e) {
            Log::warning('Failed to warm Harbor cache', [
                'error' => $e->getMessage(),
            ]);
        }

        return $count;
    }

    /**
     * Warm database cache
     *
     * @return int Number of items warmed
     */
    private function warmDatabaseCache(): int
    {
        $count = 0;

        try {
            // Warm user roles and permissions
            $users = \App\Models\User::select('id', 'role', 'email')
                ->where('active', true)
                ->limit(100)
                ->get();

            foreach ($users as $user) {
                $this->cacheStrategy->cacheUserData(
                    $user->id,
                    'permissions',
                    fn () => $user->getAllPermissions(),
                    'long'
                );
                $count++;
            }

            // Warm system settings
            $settings = \App\Models\Setting::all()->pluck('value', 'key');
            $this->cacheStrategy->warmCache(
                ['system_settings' => $settings],
                'general'
            );
            $count++;

            Log::info('Database cache warmed', ['items' => $count]);

        } catch (\Exception $e) {
            Log::warning('Failed to warm database cache', [
                'error' => $e->getMessage(),
            ]);
        }

        return $count;
    }

    /**
     * Handle a job failure.
     */
    public function failed(\Exception $exception): void
    {
        Log::error('Cache warming job failed', [
            'error' => $exception->getMessage(),
            'attempts' => $this->attempts(),
        ]);
    }
}

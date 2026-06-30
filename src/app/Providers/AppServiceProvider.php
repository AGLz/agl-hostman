<?php

namespace App\Providers;

use App\Services\PcGamer\MarketProviderRegistry;
use App\Auth\ActiveEloquentUserProvider;
use App\Validation\SecureValidator;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Validator;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        if (! class_exists(\Illuminate\Support\Process::class)) {
            class_alias(\Illuminate\Support\Facades\Process::class, \Illuminate\Support\Process::class);
        }

        Auth::provider('active_eloquent', function ($app, array $config) {
            return new ActiveEloquentUserProvider($app['hash'], $config['model']);
        });

        // Register ProxmoxApiClient with configuration
        $this->app->singleton(\App\Services\Proxmox\ProxmoxApiClient::class, function ($app) {
            return \App\Services\Proxmox\ProxmoxApiClient::fromConfig(
                config('proxmox')
            );
        });

        // Alias ProxmoxService to ProxmoxApiClient
        $this->app->alias(\App\Services\Proxmox\ProxmoxApiClient::class, \App\Services\ProxmoxService::class);

        // Register ContainerLifecycleService with dependencies
        $this->app->singleton(\App\Services\Container\ContainerLifecycleService::class, function ($app) {
            return new \App\Services\Container\ContainerLifecycleService(
                $app->make(\App\Services\Proxmox\ProxmoxApiClient::class),
                $app->make(\App\Services\Broadcasting\WebSocketBroadcastService::class)
            );
        });

        // Alias ContainerService to ContainerLifecycleService
        $this->app->alias(\App\Services\Container\ContainerLifecycleService::class, \App\Services\ContainerService::class);

        // Register NetworkTopologyService with dependencies
        $this->app->singleton(\App\Services\NetworkTopologyService::class, function ($app) {
            return new \App\Services\NetworkTopologyService(
                $app->make(\App\Services\Proxmox\ProxmoxApiClient::class),
                $app->make(\App\Services\Container\ContainerLifecycleService::class)
            );
        });

        // ========== Agent OS v3 Services ==========
        // Register AgentOSService with all dependencies
        $this->app->singleton(\App\Services\AgentOS\AgentOSService::class, function ($app) {
            return new \App\Services\AgentOS\AgentOSService(
                $app->make(\App\Services\AgentOS\MemoryService::class),
                $app->make(\App\Services\AgentOS\Coordination\AdaptiveCoordinator::class),
                $app->make(\App\Services\AgentOS\Consensus\ByzantineCoordinator::class)
            );
        });

        // Register Memory Service with HNSW indexing
        $this->app->singleton(\App\Services\AgentOS\MemoryService::class);

        // Register HNSW Indexer
        $this->app->singleton(\App\Services\AgentOS\HNSWIndexer::class);

        // Register Vector Quantization
        $this->app->singleton(\App\Services\AgentOS\VectorQuantization::class);

        // Register ReasoningBank
        $this->app->singleton(\App\Services\AgentOS\ReasoningBank::class);

        // Register Coordination Services
        $this->app->singleton(\App\Services\AgentOS\Coordination\HierarchicalCoordinator::class);
        $this->app->singleton(\App\Services\AgentOS\Coordination\MeshCoordinator::class);
        $this->app->singleton(\App\Services\AgentOS\Coordination\AdaptiveCoordinator::class, function () {
            return new \App\Services\AgentOS\Coordination\AdaptiveCoordinator;
        });

        // Register Consensus Services
        $this->app->singleton(\App\Services\AgentOS\Consensus\ByzantineCoordinator::class, function ($app) {
            return new \App\Services\AgentOS\Consensus\ByzantineCoordinator(
                config('agent-os.consensus')
            );
        });

        // PC Gamer — providers de mercado
        $this->app->singleton(MarketProviderRegistry::class);
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        Validator::resolver(function ($translator, $data, $rules, $messages, $attributes) {
            return new SecureValidator($translator, $data, $rules, $messages, $attributes);
        });
    }
}

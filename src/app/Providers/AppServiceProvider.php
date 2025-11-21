<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
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
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        //
    }
}

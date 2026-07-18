<?php

namespace App\Providers;

use Illuminate\Support\ServiceProvider;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Blade;
use Illuminate\Support\Facades\Gate;
use App\Jobs\MonitorContainerHealth;

class ContainerServiceProvider extends ServiceProvider
{
    /**
     * Register services.
     */
    public function register(): void
    {
        // Register Container Service
        $this->app->singleton(\App\Services\Container\ContainerManagementService::class, function ($app) {
            return new \App\Services\Container\ContainerManagementService();
        });

        // Register Proxmox Service
        $this->app->singleton(\App\Services\Proxmox\ProxmoxApiService::class, function ($app) {
            return new \App\Services\Proxmox\ProxmoxApiService();
        });

        // Register WebSocket Service
        $this->app->singleton(\App\Services\WebSocket\WebSocketBroadcastService::class, function ($app) {
            return new \App\Services\WebSocket\WebSocketBroadcastService();
        });

        // Register Notification Service
        $this->app->singleton(\App\Services\Notification\NotificationService::class, function ($app) {
            return new \App\Services\Notification\NotificationService();
        });

        // Register Container Monitor Service
        $this->app->singleton(\App\Services\Monitoring\ContainerMonitorService::class, function ($app) {
            return new \App\Services\Monitoring\ContainerMonitorService();
        });

        // Register Cost Calculator Service
        $this->app->singleton(\App\Services\Cost\ContainerCostService::class, function ($app) {
            return new \App\Services\Cost\ContainerCostService();
        });

        // Facades
        $this->app->alias('container', \App\Facades\ContainerFacade::class);
        $this->app->alias('proxmox', \App\Facades\ProxmoxFacade::class);
        $this->app->alias('websocket', \App\Facades\WebSocketFacade::class);
    }

    /**
     * Bootstrap services.
     */
    public function boot(): void
    {
        // Publish configuration (commented for now - config file doesn't exist yet)
        // $this->publishes([
        //     __DIR__.'/../../config/container.php' => config_path('container.php'),
        // ], 'container-config');

        // Register routes
        $this->loadRoutesFrom(base_path('routes/api/containers.php'));

        // Register migrations
        $this->loadMigrationsFrom(database_path('migrations/containers'));

        // Register events and listeners
        $this->registerEvents();

        // Register scheduled tasks
        $this->registerScheduledTasks();

        // Register Blade components
        $this->registerBladeComponents();

        // Register policies
        $this->registerPolicies();

        // Register console commands
        $this->registerCommands();
    }

    /**
     * Register events and listeners.
     */
    protected function registerEvents(): void
    {
        Event::listen(
            ContainerCreated::class,
            [LogContainerEvent::class, 'handleContainerCreated']
        );

        Event::listen(
            ContainerCloned::class,
            [LogContainerEvent::class, 'handleContainerCloned']
        );

        Event::listen(
            ContainerMigrated::class,
            [LogContainerEvent::class, 'handleContainerMigrated']
        );

        Event::listen(
            ContainerBackedUp::class,
            [LogContainerEvent::class, 'handleContainerBackedUp']
        );

        Event::listen(
            ContainerSnapshotted::class,
            [LogContainerEvent::class, 'handleContainerSnapshotted']
        );

        Event::listen(
            ContainerCreated::class,
            [SendContainerNotification::class, 'handle']
        );

        Event::listen(
            ContainerMigrated::class,
            [UpdateContainerMetrics::class, 'handle']
        );
    }

    /**
     * Register scheduled tasks.
     */
    protected function registerScheduledTasks(): void
    {
        // Schedule container health monitoring
        $this->app->booted(function () {
            $schedule = app(\Illuminate\Console\Scheduling\Schedule::class);

            // Monitor container health every minute
            $schedule->call(function () {
                MonitorContainerHealth::dispatch()->onQueue('monitoring');
            })->everyMinute()->name('monitor-container-health');

            // Cleanup old snapshots
            $schedule->call(function () {
                \App\Jobs\CleanupOldSnapshots::dispatch()->onQueue('cleanup');
            })->dailyAt('02:00')->name('cleanup-snapshots');

            // Cleanup old backups
            $schedule->call(function () {
                \App\Jobs\CleanupOldBackups::dispatch()->onQueue('cleanup');
            })->dailyAt('03:00')->name('cleanup-backups');

            // Generate cost reports
            $schedule->call(function () {
                \App\Jobs\GenerateCostReport::dispatch()->onQueue('reports');
            })->monthlyOn(1)->at('00:00')->name('generate-cost-report');

            // Check container security
            $schedule->call(function () {
                \App\Jobs\CheckContainerSecurity::dispatch()->onQueue('security');
            })->weeklyOn(0)->at('04:00')->name('check-container-security');

            // Update container metrics
            $schedule->call(function () {
                \App\Jobs\UpdateContainerMetrics::dispatch()->onQueue('metrics');
            })->everyFiveMinutes()->name('update-container-metrics');
        });
    }

    /**
     * Register Blade components.
     */
    protected function registerBladeComponents(): void
    {
        Blade::component('container-card', \App\View\Components\Container\ContainerCard::class);
        Blade::component('container-list', \App\View\Components\Container\ContainerList::class);
        Blade::component('container-form', \App\View\Components\Container\ContainerForm::class);
        Blade::component('container-stats', \App\View\Components\Container\ContainerStats::class);
        Blade::component('backup-list', \App\View\Components\Backup\BackupList::class);
        Blade::component('migration-progress', \App\View\Components\Migration\MigrationProgress::class);
    }

    /**
     * Register policies.
     */
    protected function registerPolicies(): void
    {
        Gate::policy(\App\Models\LxcContainer::class, \App\Policies\ContainerPolicy::class);
        Gate::policy(\App\Models\ContainerBackup::class, \App\Policies\BackupPolicy::class);
        Gate::policy(\App\Models\ContainerMigration::class, \App\Policies\MigrationPolicy::class);
        Gate::policy(\App\Models\ContainerSnapshot::class, \App\Policies\SnapshotPolicy::class);
    }

    /**
     * Register console commands.
     */
    protected function registerCommands(): void
    {
        if ($this->app->runningInConsole()) {
            // Commands will be registered when they are created
            // $this->commands([
            //     \App\Console\Commands\Container\CreateContainerCommand::class,
            //     \App\Console\Commands\Container\ListContainersCommand::class,
            //     // ... other commands
            // ]);
        }
    }

    /**
     * Get the services provided by the provider.
     */
    public function provides(): array
    {
        return [
            \App\Services\Container\ContainerManagementService::class,
            \App\Services\Proxmox\ProxmoxApiService::class,
            \App\Services\WebSocket\WebSocketBroadcastService::class,
            \App\Services\Notification\NotificationService::class,
            \App\Services\Monitoring\ContainerMonitorService::class,
            \App\Services\Cost\ContainerCostService::class,
        ];
    }
}

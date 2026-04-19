<?php

declare(strict_types=1);

namespace App\Shim;

use Illuminate\Support\ServiceProvider;

/**
 * ShimServiceProvider
 *
 * Bootstraps the API1 → API8 shim layer within the Laravel 8.x container.
 *
 * Register in config/app.php providers array:
 *   App\Shim\ShimServiceProvider::class,
 */
final class ShimServiceProvider extends ServiceProvider
{
    /**
     * Boot application services.
     *
     * Runs after all service providers have been registered, so the DB
     * manager is available for LegacyDatabaseShim to extend.
     */
    public function boot(): void
    {
        LegacyDatabaseShim::bootShim();
    }

    /**
     * Register application services.
     *
     * Both RouteMapper and FeatureFlags are stateless (all-static), but
     * binding them as singletons allows type-hinted injection and simplifies
     * mocking in feature tests.
     */
    public function register(): void
    {
        $this->app->singleton(RouteMapper::class);
        $this->app->singleton(FeatureFlags::class);
    }
}

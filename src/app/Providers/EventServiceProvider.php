<?php

namespace App\Providers;

use App\Events\Notifications\DeploymentCompleted;
use App\Events\Notifications\DeploymentFailed;
use App\Events\Notifications\DeploymentStarted;
use App\Events\Notifications\OnCallRotation;
use App\Events\Notifications\PRCommented;
use App\Events\Notifications\PRMerged;
use App\Events\Notifications\PROpened;
use App\Listeners\Notifications\SendDeploymentNotification;
use App\Listeners\Notifications\SendOnCallNotification;
use App\Listeners\Notifications\SendPRNotification;
use Illuminate\Auth\Events\Registered;
use Illuminate\Auth\Listeners\SendEmailVerificationNotification;
use Illuminate\Foundation\Support\Providers\EventServiceProvider as ServiceProvider;

class EventServiceProvider extends ServiceProvider
{
    /**
     * The event to listener mappings for the application.
     *
     * @var array<class-string, array<int, class-string>>
     */
    protected $listen = [
        Registered::class => [
            SendEmailVerificationNotification::class,
        ],

        // Deployment notifications
        DeploymentStarted::class => [
            SendDeploymentNotification::class.'@handleStarted',
        ],
        DeploymentCompleted::class => [
            SendDeploymentNotification::class.'@handleCompleted',
        ],
        DeploymentFailed::class => [
            SendDeploymentNotification::class.'@handleFailed',
        ],

        // PR notifications
        PROpened::class => [
            SendPRNotification::class.'@handleOpened',
        ],
        PRMerged::class => [
            SendPRNotification::class.'@handleMerged',
        ],
        PRCommented::class => [
            SendPRNotification::class.'@handleCommented',
        ],

        // On-call notifications
        OnCallRotation::class => [
            SendOnCallNotification::class,
        ],
    ];

    /**
     * Register any events for your application.
     */
    public function boot(): void
    {
        //
    }

    /**
     * Determine if events and listeners should be automatically discovered.
     */
    public function shouldDiscoverEvents(): bool
    {
        return false;
    }
}

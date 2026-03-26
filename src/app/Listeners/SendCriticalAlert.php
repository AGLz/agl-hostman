<?php

namespace App\Listeners;

use App\Events\ContainerCritical;
use App\Events\ResourceExhaustionPredicted;
use App\Services\AlertDispatcher;
use Illuminate\Support\Facades\Log;

/**
 * Send Critical Alert Listener
 *
 * Listens for critical infrastructure events and dispatches alerts
 * to configured notification channels.
 */
class SendCriticalAlert
{
    protected AlertDispatcher $alertDispatcher;

    /**
     * Create the event listener
     */
    public function __construct(AlertDispatcher $alertDispatcher)
    {
        $this->alertDispatcher = $alertDispatcher;
    }

    /**
     * Handle ContainerCritical event
     */
    public function handleContainerCritical(ContainerCritical $event): void
    {
        Log::info('Handling ContainerCritical event', [
            'node' => $event->node,
            'vmid' => $event->vmid,
            'severity' => $event->severity,
        ]);

        $this->alertDispatcher->dispatch(
            'container_critical',
            [
                'node' => $event->node,
                'vmid' => $event->vmid,
                'container' => $event->containerName,
                'severity' => $event->severity,
                'issues' => $event->issues,
                'metrics' => $event->metrics,
            ],
            $event->severity
        );
    }

    /**
     * Handle ResourceExhaustionPredicted event
     */
    public function handleResourceExhaustion(ResourceExhaustionPredicted $event): void
    {
        Log::info('Handling ResourceExhaustionPredicted event', [
            'node' => $event->node,
            'vmid' => $event->vmid,
            'resource_type' => $event->resourceType,
        ]);

        $this->alertDispatcher->dispatch(
            'resource_exhaustion',
            [
                'node' => $event->node,
                'vmid' => $event->vmid,
                'resource_type' => $event->resourceType,
                'predicted_usage' => $event->predictedUsage,
                'hours_ahead' => $event->hoursAhead,
                'confidence' => $event->confidence,
            ],
            'warning'
        );
    }

    /**
     * Register event listeners
     */
    public function subscribe($events): array
    {
        return [
            ContainerCritical::class => 'handleContainerCritical',
            ResourceExhaustionPredicted::class => 'handleResourceExhaustion',
        ];
    }
}

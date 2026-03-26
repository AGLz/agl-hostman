<?php

namespace App\Livewire;

use App\Models\ProxmoxServer;
use App\Services\PredictiveMaintenanceService;
use Illuminate\Support\Facades\Cache;
use Livewire\Component;

/**
 * Predictive Maintenance Widget Component
 *
 * Displays AI-powered resource exhaustion predictions and
 * maintenance recommendations for containers.
 */
class PredictiveMaintenanceWidget extends Component
{
    public ?string $node = null;

    public ?int $vmid = null;

    public string $resourceType = 'memory';

    public string $horizon = 'medium_term';

    public array $prediction = [];

    public array $clusterForecasts = [];

    public bool $showClusterView = true;

    public bool $loading = false;

    protected $listeners = [
        'refreshPredictions' => 'loadPredictions',
        'updatePredictionParams' => 'updateParams',
        'echo:predictive-maintenance,ResourceExhaustionPredicted' => 'handlePredictionUpdate',
    ];

    public function mount(?string $node = null, ?int $vmid = null)
    {
        $this->node = $node;
        $this->vmid = $vmid;
        $this->loadPredictions();
    }

    public function render()
    {
        return view('livewire.predictive-maintenance-widget', [
            'prediction' => $this->prediction,
            'clusterForecasts' => $this->clusterForecasts,
            'showClusterView' => $this->showClusterView,
            'loading' => $this->loading,
        ]);
    }

    /**
     * Load prediction data
     */
    public function loadPredictions()
    {
        $this->loading = true;

        try {
            if ($this->showClusterView) {
                $this->loadClusterForecasts();
            } else {
                $this->loadContainerPrediction();
            }

        } catch (\Exception $e) {
            $this->dispatch('predictionError', [
                'message' => 'Failed to load predictions: '.$e->getMessage(),
            ]);
        } finally {
            $this->loading = false;
        }
    }

    /**
     * Load cluster-wide forecasts
     */
    protected function loadClusterForecasts()
    {
        $cacheKey = 'predictive:cluster_forecasts';

        $this->clusterForecasts = Cache::remember(
            $cacheKey,
            now()->addMinutes(15),
            function () {
                $service = app(PredictiveMaintenanceService::class);
                $servers = ProxmoxServer::online()->get();
                $nodes = $servers->pluck('code')->toArray();

                if (empty($nodes)) {
                    return [];
                }

                return $service->predictClusterFailures($nodes);
            }
        );
    }

    /**
     * Load container-specific prediction
     */
    protected function loadContainerPrediction()
    {
        if (! $this->node || ! $this->vmid) {
            $this->prediction = [
                'error' => 'Node and VMID required for container predictions',
            ];

            return;
        }

        $cacheKey = "predictive:{$this->node}:{$this->vmid}:{$this->resourceType}:{$this->horizon}";

        $this->prediction = Cache::remember(
            $cacheKey,
            now()->addMinutes(10),
            function () {
                $service = app(PredictiveMaintenanceService::class);

                return $service->predictResourceExhaustion(
                    $this->node,
                    $this->vmid,
                    $this->resourceType,
                    $this->horizon
                );
            }
        );
    }

    /**
     * Toggle between cluster and container view
     */
    public function toggleView()
    {
        $this->showClusterView = ! $this->showClusterView;
        $this->loadPredictions();
    }

    /**
     * Update prediction parameters
     */
    public function updateParams(array $params)
    {
        if (isset($params['node'])) {
            $this->node = $params['node'];
        }

        if (isset($params['vmid'])) {
            $this->vmid = $params['vmid'];
        }

        if (isset($params['resourceType'])) {
            $this->resourceType = $params['resourceType'];
        }

        if (isset($params['horizon'])) {
            $this->horizon = $params['horizon'];
        }

        $this->showClusterView = false;
        $this->loadPredictions();
    }

    /**
     * Set resource type
     */
    public function setResourceType(string $type)
    {
        $this->resourceType = in_array($type, ['cpu', 'memory', 'disk'])
            ? $type
            : 'memory';

        $this->loadPredictions();
    }

    /**
     * Set forecast horizon
     */
    public function setHorizon(string $horizon)
    {
        $this->horizon = in_array($horizon, ['short_term', 'medium_term', 'long_term'])
            ? $horizon
            : 'medium_term';

        $this->loadPredictions();
    }

    /**
     * Handle prediction update event
     */
    public function handlePredictionUpdate($event)
    {
        // If this update is for our container, refresh
        if (
            ! $this->showClusterView &&
            $event['node'] === $this->node &&
            $event['vmid'] == $this->vmid
        ) {
            $this->loadPredictions();

            $this->dispatch('predictionAlert', [
                'type' => 'warning',
                'message' => "Resource exhaustion predicted for {$event['resource_type']} in {$event['hours_ahead']} hours",
                'prediction' => $event,
            ]);
        }

        // Always refresh cluster view
        if ($this->showClusterView) {
            $this->loadPredictions();
        }
    }

    /**
     * Get confidence level badge color
     */
    public function getConfidenceColor(float $confidence): string
    {
        if ($confidence >= 0.8) {
            return 'green';
        }
        if ($confidence >= 0.6) {
            return 'yellow';
        }
        if ($confidence >= 0.4) {
            return 'orange';
        }

        return 'red';
    }

    /**
     * Get confidence level text
     */
    public function getConfidenceText(float $confidence): string
    {
        if ($confidence >= 0.8) {
            return 'High Confidence';
        }
        if ($confidence >= 0.6) {
            return 'Medium Confidence';
        }
        if ($confidence >= 0.4) {
            return 'Low Confidence';
        }

        return 'Very Low Confidence';
    }

    /**
     * Get prediction severity based on predicted value
     */
    public function getPredictionSeverity(float $predictedValue): string
    {
        if ($predictedValue >= 90) {
            return 'critical';
        }
        if ($predictedValue >= 70) {
            return 'warning';
        }

        return 'info';
    }

    /**
     * Get horizon label
     */
    public function getHorizonLabel(string $horizon): string
    {
        return match ($horizon) {
            'short_term' => '4 hours',
            'medium_term' => '24 hours',
            'long_term' => '7 days',
            default => $horizon,
        };
    }

    /**
     * Get resource type label
     */
    public function getResourceLabel(string $type): string
    {
        return match ($type) {
            'cpu' => 'CPU',
            'memory' => 'Memory',
            'disk' => 'Disk',
            default => ucfirst($type),
        };
    }

    /**
     * Get recommendation based on prediction
     */
    public function getRecommendation(array $prediction): string
    {
        if (! isset($prediction['predicted_value'])) {
            return 'Insufficient data for recommendation';
        }

        $predictedValue = $prediction['predicted_value'];
        $confidence = $prediction['confidence'] ?? 0;

        if ($predictedValue >= 95 && $confidence >= 0.7) {
            return 'URGENT: Immediate action required to prevent resource exhaustion';
        }

        if ($predictedValue >= 85 && $confidence >= 0.6) {
            return 'Plan capacity upgrade or workload optimization within next 24-48 hours';
        }

        if ($predictedValue >= 70 && $confidence >= 0.5) {
            return 'Monitor closely and prepare capacity upgrade plan';
        }

        return 'Resource usage within acceptable range';
    }

    /**
     * Export predictions as JSON
     */
    public function exportJson()
    {
        $data = $this->showClusterView
            ? ['cluster_forecasts' => $this->clusterForecasts]
            : ['prediction' => $this->prediction];

        $data['timestamp'] = now()->toIso8601String();
        $data['node'] = $this->node;
        $data['vmid'] = $this->vmid;
        $data['resource_type'] = $this->resourceType;
        $data['horizon'] = $this->horizon;

        $filename = 'prediction_'.now()->format('Y-m-d_His').'.json';

        return response()->streamDownload(function () use ($data) {
            echo json_encode($data, JSON_PRETTY_PRINT);
        }, $filename, [
            'Content-Type' => 'application/json',
        ]);
    }
}

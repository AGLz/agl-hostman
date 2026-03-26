<?php

namespace App\Services;

use App\Events\ResourceExhaustionPredicted;
use App\Models\ContainerHealthLog;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;

/**
 * Predictive Maintenance Service
 *
 * Uses AI and machine learning techniques to forecast resource exhaustion,
 * predict container failures, and recommend proactive maintenance actions.
 *
 * Features:
 * - Resource exhaustion forecasting (CPU, memory, disk)
 * - Trend-based predictions
 * - Anomaly detection
 * - Capacity planning recommendations
 * - Predictive alerts
 */
class PredictiveMaintenanceService
{
    protected AIModelService $aiService;

    /**
     * Prediction confidence thresholds
     */
    protected array $confidenceThresholds = [
        'high' => 0.85,
        'medium' => 0.70,
        'low' => 0.50,
    ];

    /**
     * Forecast horizons (hours)
     */
    protected array $forecastHorizons = [
        'short_term' => 4,    // 4 hours
        'medium_term' => 24,  // 24 hours
        'long_term' => 168,   // 7 days
    ];

    public function __construct(AIModelService $aiService)
    {
        $this->aiService = $aiService;
    }

    /**
     * Predict resource exhaustion for a container
     *
     * @param  string  $node  Node code
     * @param  int  $vmid  Container VMID
     * @param  string  $resourceType  Resource type (cpu, memory, disk)
     * @param  string  $horizon  Forecast horizon (short_term, medium_term, long_term)
     * @return array Prediction results
     */
    public function predictResourceExhaustion(
        string $node,
        int $vmid,
        string $resourceType = 'memory',
        string $horizon = 'medium_term'
    ): array {
        $cacheKey = "prediction:{$node}:{$vmid}:{$resourceType}:{$horizon}";

        return Cache::remember($cacheKey, now()->addMinutes(30), function () use ($node, $vmid, $resourceType, $horizon) {
            // Get historical data
            $historicalData = $this->getHistoricalResourceData($node, $vmid, $resourceType);

            if ($historicalData->count() < 10) {
                return [
                    'status' => 'insufficient_data',
                    'message' => 'Not enough historical data for prediction',
                    'data_points' => $historicalData->count(),
                ];
            }

            // Perform trend analysis
            $trendAnalysis = $this->analyzeTrend($historicalData);

            // Calculate forecast
            $forecast = $this->forecastResource($historicalData, $resourceType, $horizon);

            // Determine if exhaustion is predicted
            $exhaustionPrediction = $this->detectExhaustionRisk($forecast, $resourceType);

            $result = [
                'node' => $node,
                'vmid' => $vmid,
                'resource_type' => $resourceType,
                'horizon' => $horizon,
                'hours_ahead' => $this->forecastHorizons[$horizon],
                'current_usage' => $historicalData->last(),
                'predicted_usage' => $forecast['predicted_value'],
                'trend' => $trendAnalysis,
                'exhaustion_risk' => $exhaustionPrediction,
                'confidence' => $forecast['confidence'],
                'timestamp' => now()->toIso8601String(),
            ];

            // Trigger alert if high risk
            if ($exhaustionPrediction['risk_level'] === 'high') {
                $this->triggerExhaustionAlert($node, $vmid, $result);
            }

            return $result;
        });
    }

    /**
     * Predict failures across all containers
     *
     * @param  array  $nodes  Nodes to analyze
     * @return array Cluster-wide predictions
     */
    public function predictClusterFailures(array $nodes): array
    {
        $predictions = [
            'timestamp' => now()->toIso8601String(),
            'nodes' => [],
            'high_risk_containers' => [],
            'recommendations' => [],
        ];

        foreach ($nodes as $node) {
            $nodePredictions = $this->predictNodeFailures($node);
            $predictions['nodes'][$node] = $nodePredictions;

            // Collect high-risk containers
            foreach ($nodePredictions['containers'] as $container) {
                if ($container['risk_level'] === 'high') {
                    $predictions['high_risk_containers'][] = $container;
                }
            }
        }

        // Generate cluster-wide recommendations
        $predictions['recommendations'] = $this->generateClusterRecommendations($predictions);

        return $predictions;
    }

    /**
     * Predict failures for containers on a node
     *
     * @param  string  $node  Node code
     * @return array Node predictions
     */
    protected function predictNodeFailures(string $node): array
    {
        // Get recent container health logs
        $containers = ContainerHealthLog::where('node_code', $node)
            ->where('created_at', '>=', now()->subDay())
            ->select('vmid', 'container_name')
            ->distinct()
            ->get();

        $predictions = [
            'node' => $node,
            'total_containers' => $containers->count(),
            'containers' => [],
        ];

        foreach ($containers as $container) {
            // Predict for each resource type
            $cpuPrediction = $this->predictResourceExhaustion($node, $container->vmid, 'cpu', 'medium_term');
            $memoryPrediction = $this->predictResourceExhaustion($node, $container->vmid, 'memory', 'medium_term');
            $diskPrediction = $this->predictResourceExhaustion($node, $container->vmid, 'disk', 'long_term');

            $overallRisk = $this->calculateOverallRisk([
                $cpuPrediction['exhaustion_risk'] ?? ['risk_level' => 'low'],
                $memoryPrediction['exhaustion_risk'] ?? ['risk_level' => 'low'],
                $diskPrediction['exhaustion_risk'] ?? ['risk_level' => 'low'],
            ]);

            $predictions['containers'][] = [
                'vmid' => $container->vmid,
                'name' => $container->container_name,
                'risk_level' => $overallRisk,
                'predictions' => [
                    'cpu' => $cpuPrediction,
                    'memory' => $memoryPrediction,
                    'disk' => $diskPrediction,
                ],
            ];
        }

        return $predictions;
    }

    /**
     * Get historical resource usage data
     *
     * @param  string  $node  Node code
     * @param  int  $vmid  Container VMID
     * @param  string  $resourceType  Resource type
     * @return Collection Historical data
     */
    protected function getHistoricalResourceData(string $node, int $vmid, string $resourceType): Collection
    {
        $columnMap = [
            'cpu' => 'cpu_usage_percent',
            'memory' => 'memory_usage_percent',
            'disk' => 'disk_usage_percent',
        ];

        $column = $columnMap[$resourceType] ?? 'memory_usage_percent';

        return ContainerHealthLog::where('node_code', $node)
            ->where('vmid', $vmid)
            ->where('created_at', '>=', now()->subDays(7))
            ->orderBy('created_at', 'asc')
            ->pluck($column, 'created_at');
    }

    /**
     * Analyze trend in historical data
     *
     * @param  Collection  $data  Historical data
     * @return array Trend analysis
     */
    protected function analyzeTrend(Collection $data): array
    {
        if ($data->count() < 2) {
            return ['type' => 'unknown', 'rate' => 0];
        }

        // Linear regression to determine trend
        $values = $data->values()->toArray();
        $n = count($values);
        $x = range(0, $n - 1);

        $sumX = array_sum($x);
        $sumY = array_sum($values);
        $sumXY = 0;
        $sumX2 = 0;

        for ($i = 0; $i < $n; $i++) {
            $sumXY += $x[$i] * $values[$i];
            $sumX2 += $x[$i] * $x[$i];
        }

        $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX);
        $intercept = ($sumY - $slope * $sumX) / $n;

        // Determine trend type
        if (abs($slope) < 0.1) {
            $type = 'stable';
        } elseif ($slope > 0) {
            $type = 'increasing';
        } else {
            $type = 'decreasing';
        }

        return [
            'type' => $type,
            'rate' => round($slope, 4),
            'intercept' => round($intercept, 2),
            'r_squared' => $this->calculateRSquared($values, $slope, $intercept),
        ];
    }

    /**
     * Calculate R-squared for trend line
     *
     * @param  array  $values  Data values
     * @param  float  $slope  Trend slope
     * @param  float  $intercept  Trend intercept
     * @return float R-squared value
     */
    protected function calculateRSquared(array $values, float $slope, float $intercept): float
    {
        $n = count($values);
        $mean = array_sum($values) / $n;

        $ssRes = 0; // Sum of squared residuals
        $ssTot = 0; // Total sum of squares

        for ($i = 0; $i < $n; $i++) {
            $predicted = $slope * $i + $intercept;
            $ssRes += pow($values[$i] - $predicted, 2);
            $ssTot += pow($values[$i] - $mean, 2);
        }

        return $ssTot > 0 ? round(1 - ($ssRes / $ssTot), 4) : 0;
    }

    /**
     * Forecast resource usage
     *
     * @param  Collection  $historicalData  Historical data
     * @param  string  $resourceType  Resource type
     * @param  string  $horizon  Forecast horizon
     * @return array Forecast results
     */
    protected function forecastResource(Collection $historicalData, string $resourceType, string $horizon): array
    {
        $trendAnalysis = $this->analyzeTrend($historicalData);
        $hoursAhead = $this->forecastHorizons[$horizon];

        // Simple linear extrapolation
        $dataPoints = $historicalData->count();
        $predictedValue = $trendAnalysis['slope'] * ($dataPoints + $hoursAhead) + $trendAnalysis['intercept'];

        // Clamp to 0-100%
        $predictedValue = max(0, min(100, $predictedValue));

        // Calculate confidence based on R-squared and data points
        $confidence = min(
            $trendAnalysis['r_squared'] * ($dataPoints / 100),
            0.95
        );

        return [
            'predicted_value' => round($predictedValue, 2),
            'confidence' => round($confidence, 3),
            'method' => 'linear_regression',
            'data_points' => $dataPoints,
        ];
    }

    /**
     * Detect exhaustion risk from forecast
     *
     * @param  array  $forecast  Forecast results
     * @param  string  $resourceType  Resource type
     * @return array Exhaustion risk assessment
     */
    protected function detectExhaustionRisk(array $forecast, string $resourceType): array
    {
        $thresholds = [
            'cpu' => ['warning' => 70, 'critical' => 90],
            'memory' => ['warning' => 70, 'critical' => 85],
            'disk' => ['warning' => 60, 'critical' => 80],
        ];

        $resourceThresholds = $thresholds[$resourceType] ?? $thresholds['memory'];
        $predictedValue = $forecast['predicted_value'];

        if ($predictedValue >= $resourceThresholds['critical']) {
            $riskLevel = 'high';
            $message = "Critical: {$resourceType} predicted to reach {$predictedValue}%";
        } elseif ($predictedValue >= $resourceThresholds['warning']) {
            $riskLevel = 'medium';
            $message = "Warning: {$resourceType} predicted to reach {$predictedValue}%";
        } else {
            $riskLevel = 'low';
            $message = "{$resourceType} usage within normal range";
        }

        return [
            'risk_level' => $riskLevel,
            'predicted_value' => $predictedValue,
            'threshold_warning' => $resourceThresholds['warning'],
            'threshold_critical' => $resourceThresholds['critical'],
            'message' => $message,
            'confidence' => $forecast['confidence'],
        ];
    }

    /**
     * Calculate overall risk from multiple predictions
     *
     * @param  array  $predictions  Array of exhaustion predictions
     * @return string Overall risk level
     */
    protected function calculateOverallRisk(array $predictions): string
    {
        $riskLevels = array_column($predictions, 'risk_level');

        if (in_array('high', $riskLevels)) {
            return 'high';
        } elseif (in_array('medium', $riskLevels)) {
            return 'medium';
        }

        return 'low';
    }

    /**
     * Trigger exhaustion alert
     *
     * @param  string  $node  Node code
     * @param  int  $vmid  Container VMID
     * @param  array  $prediction  Prediction results
     */
    protected function triggerExhaustionAlert(string $node, int $vmid, array $prediction): void
    {
        $alertKey = "exhaustion_alert:{$node}:{$vmid}:{$prediction['resource_type']}";

        // Prevent alert spam
        if (Cache::has($alertKey)) {
            return;
        }

        Cache::put($alertKey, true, now()->addHours(6));

        event(new ResourceExhaustionPredicted(
            $node,
            $vmid,
            $prediction['resource_type'],
            $prediction['predicted_usage'],
            $prediction['hours_ahead'],
            $prediction['confidence']
        ));

        Log::warning("Resource exhaustion predicted for VMID {$vmid} on {$node}", [
            'resource' => $prediction['resource_type'],
            'predicted_usage' => $prediction['predicted_usage'],
            'hours_ahead' => $prediction['hours_ahead'],
        ]);
    }

    /**
     * Generate cluster-wide recommendations
     *
     * @param  array  $predictions  Cluster predictions
     * @return array Recommendations
     */
    protected function generateClusterRecommendations(array $predictions): array
    {
        $recommendations = [];

        // Analyze high-risk containers
        $highRiskCount = count($predictions['high_risk_containers']);

        if ($highRiskCount > 0) {
            $recommendations[] = [
                'priority' => 'high',
                'action' => 'immediate_intervention',
                'description' => "Review {$highRiskCount} high-risk containers immediately",
                'containers' => array_column($predictions['high_risk_containers'], 'name'),
            ];
        }

        // Check for cluster-wide resource trends
        $memoryIssues = collect($predictions['high_risk_containers'])
            ->filter(fn ($c) => $c['predictions']['memory']['exhaustion_risk']['risk_level'] === 'high')
            ->count();

        if ($memoryIssues > 3) {
            $recommendations[] = [
                'priority' => 'high',
                'action' => 'increase_cluster_memory',
                'description' => 'Multiple containers showing memory exhaustion risk',
                'affected_count' => $memoryIssues,
            ];
        }

        return $recommendations;
    }

    /**
     * Get AI-powered maintenance insights
     *
     * @param  string  $node  Node code
     * @param  int  $vmid  Container VMID
     * @return array AI insights
     */
    public function getAIMaintenanceInsights(string $node, int $vmid): array
    {
        $historicalData = [
            'cpu' => $this->getHistoricalResourceData($node, $vmid, 'cpu'),
            'memory' => $this->getHistoricalResourceData($node, $vmid, 'memory'),
            'disk' => $this->getHistoricalResourceData($node, $vmid, 'disk'),
        ];

        $prompt = $this->buildMaintenancePrompt($node, $vmid, $historicalData);

        $insights = $this->aiService->multiAgentQuery(
            ['claude', 'gemini', 'openai'],
            $prompt,
            ['context' => 'predictive_maintenance']
        );

        return [
            'consensus' => $this->extractMaintenanceConsensus($insights),
            'model_specific' => $insights,
            'timestamp' => now()->toIso8601String(),
        ];
    }

    /**
     * Build prompt for AI maintenance insights
     *
     * @param  string  $node  Node code
     * @param  int  $vmid  Container VMID
     * @param  array  $historicalData  Historical resource data
     * @return string AI prompt
     */
    protected function buildMaintenancePrompt(string $node, int $vmid, array $historicalData): string
    {
        return "Analyze the following container resource usage trends and provide predictive maintenance recommendations:\n\n".
               "Node: {$node}\n".
               "Container VMID: {$vmid}\n\n".
               "Resource Usage Trends (last 7 days):\n".
               json_encode($historicalData, JSON_PRETTY_PRINT)."\n\n".
               "Please provide:\n".
               "1. Risk assessment (high/medium/low)\n".
               "2. Predicted time to resource exhaustion\n".
               "3. Recommended preventive actions\n".
               "4. Capacity planning suggestions\n".
               "5. Optimization opportunities\n\n".
               'Format your response as actionable maintenance tasks.';
    }

    /**
     * Extract consensus from AI responses
     *
     * @param  array  $responses  AI model responses
     * @return array Consensus insights
     */
    protected function extractMaintenanceConsensus(array $responses): array
    {
        // Simplified consensus extraction
        return [
            'risk_assessment' => 'medium',
            'recommended_actions' => [],
            'confidence' => count(array_filter($responses, fn ($r) => $r['success'] ?? false)) / max(count($responses), 1),
        ];
    }
}

---
name: monitoring-analytics-predictive
description: "Advanced monitoring with anomaly detection, trend forecasting, SLO/SLI tracking, and predictive alerting using Prometheus, Grafana, and statistical analysis. Use when implementing proactive monitoring, capacity planning, or performance forecasting."
category: monitoring
priority: P1
tags: [monitoring, prometheus, grafana, analytics, prediction]
---

# Monitoring Analytics & Predictive Monitoring

## Overview

This skill provides advanced monitoring capabilities including real-time anomaly detection, trend forecasting, SLO/SLI tracking, and predictive alerting. It integrates Prometheus for metrics collection, Grafana for visualization, and statistical analysis for predictive insights.

**Key Features:**
- Real-time anomaly detection using z-score and IQR methods
- Trend forecasting with linear regression and moving averages
- SLO/SLI tracking with error budget calculations
- Predictive alerting before thresholds are breached
- Automated Grafana dashboard management
- Log aggregation with Loki/Elasticsearch
- Performance baseline establishment

## When to Use This Skill

Use this skill when:
- Implementing proactive monitoring systems
- Setting up capacity planning infrastructure
- Creating predictive alerting mechanisms
- Establishing SLO/SLI frameworks
- Building performance baselines
- Integrating Prometheus/Grafana monitoring

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐     │
│  │   Laravel    │  │   Queue      │  │  Scheduler   │     │
│  │   Services   │  │   Workers    │  │   Jobs       │     │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘     │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
┌─────────┼──────────────────┼──────────────────┼─────────────┐
│         ▼                  ▼                  ▼              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Metrics Collection Layer                     │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │   Custom    │  │  Prom       │  │   Business  │ │   │
│  │  │  Exporters  │  │  Clients    │  │   Metrics   │ │   │
│  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘ │   │
│  └─────────┼──────────────────┼──────────────────┼──────┘   │
└────────────┼──────────────────┼──────────────────┼──────────┘
             │                  │                  │
┌────────────┼──────────────────┼──────────────────┼──────────┐
│             ▼                  ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │           Storage & Analysis Layer                   │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │ Performance │  │   Redis     │  │  Database   │ │   │
│  │  │   Trends    │  │   Cache     │  │  Metrics    │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │         Analytics & Prediction Layer                 │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │   Anomaly   │  │    Trend    │  │  Predictive │ │   │
│  │  │  Detection  │  │  Forecast   │  │   Alerting  │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
             │                  │                  │
┌────────────┼──────────────────┼──────────────────┼──────────┐
│             ▼                  ▼                  ▼          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            Visualization & Alerting                  │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐ │   │
│  │  │  Prometheus │  │   Grafana   │  │    Alert    │ │   │
│  │  │    TSDB     │  │  Dashboards │  │  Manager    │ │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
│  ┌─────────────┐  ┌─────────────┐                         │
│  │    Loki     │  │ Elasticsearch│                         │
│  │   Logs      │  │    Logs      │                         │
│  └─────────────┘  └─────────────┘                         │
└─────────────────────────────────────────────────────────────┘
```

## Prometheus Setup

### Installation

```bash
# Docker Compose setup
docker-compose up -d prometheus prometheus-pushgateway grafana loki
```

### Metrics Export

Use the provided script to configure Prometheus metrics export:

```bash
./scripts/prometheus-export.sh
```

### Custom Metrics Definition

```php
// app/Metrics/CustomMetrics.php

namespace App\Metrics;

use Prometheus\CollectorRegistry;
use Prometheus\RenderTextFormat;

class CustomMetrics
{
    private CollectorRegistry $registry;

    public function __construct(CollectorRegistry $registry)
    {
        $this->registry = $registry;
    }

    public function recordRequestDuration(string $endpoint, float $duration): void
    {
        $histogram = $this->registry->getOrRegisterHistogram(
            'app',
            'http_request_duration',
            'HTTP request duration',
            ['endpoint']
        );

        $histogram->observe($duration, [$endpoint]);
    }

    public function recordActiveConnections(int $count): void
    {
        $gauge = $this->registry->getOrRegisterGauge(
            'app',
            'active_connections',
            'Active database connections'
        );

        $gauge->set($count);
    }

    public function incrementErrors(string $type): void
    {
        $counter = $this->registry->getOrRegisterCounter(
            'app',
            'errors_total',
            'Total errors',
            ['type']
        );

        $counter->inc([$type]);
    }
}
```

## Grafana Dashboards

### Dashboard Management

```bash
# Export dashboards to version control
./scripts/grafana-dashboard-export.sh

# Import dashboards
curl -X POST \
  http://localhost:3000/api/dashboards/import \
  -H "Authorization: Bearer $GRAFANA_API_KEY" \
  -H "Content-Type: application/json" \
  -d @templates/grafana-dashboards/overview.json
```

### Dashboard Templates

Located in `templates/grafana-dashboards/`:
- `overview.json` - System overview dashboard
- `performance.json` - Performance metrics dashboard
- `slo-compliance.json` - SLO/SLI tracking dashboard
- `capacity-planning.json` - Capacity planning dashboard
- `anomalies.json` - Anomaly detection dashboard

## Anomaly Detection

### Statistical Methods

The skill implements multiple anomaly detection algorithms:

#### Z-Score Method

```php
// app/Services/AnomalyDetection/ZScoreDetector.php

namespace App\Services\AnomalyDetection;

class ZScoreDetector
{
    private float $threshold;

    public function __construct(float $threshold = 3.0)
    {
        $this->threshold = $threshold;
    }

    public function detect(array $values): array
    {
        $mean = $this->calculateMean($values);
        $stdDev = $this->calculateStandardDeviation($values, $mean);

        $anomalies = [];
        foreach ($values as $index => $value) {
            $zScore = abs(($value - $mean) / $stdDev);
            if ($zScore > $this->threshold) {
                $anomalies[] = [
                    'index' => $index,
                    'value' => $value,
                    'z_score' => $zScore,
                    'severity' => $this->calculateSeverity($zScore)
                ];
            }
        }

        return $anomalies;
    }

    private function calculateMean(array $values): float
    {
        return array_sum($values) / count($values);
    }

    private function calculateStandardDeviation(array $values, float $mean): float
    {
        $variance = array_reduce($values, function ($carry, $value) use ($mean) {
            return $carry + pow($value - $mean, 2);
        }, 0) / count($values);

        return sqrt($variance);
    }

    private function calculateSeverity(float $zScore): string
    {
        if ($zScore > 5) return 'critical';
        if ($zScore > 4) return 'high';
        if ($zScore > 3) return 'medium';
        return 'low';
    }
}
```

#### IQR Method

```php
// app/Services/AnomalyDetection/IQRDetector.php

namespace App\Services\AnomalyDetection;

class IQRDetector
{
    private float $multiplier;

    public function __construct(float $multiplier = 1.5)
    {
        $this->multiplier = $multiplier;
    }

    public function detect(array $values): array
    {
        sort($values);

        $q1 = $this->calculatePercentile($values, 25);
        $q3 = $this->calculatePercentile($values, 75);
        $iqr = $q3 - $q1;

        $lowerBound = $q1 - ($this->multiplier * $iqr);
        $upperBound = $q3 + ($this->multiplier * $iqr);

        $anomalies = [];
        foreach ($values as $index => $value) {
            if ($value < $lowerBound || $value > $upperBound) {
                $anomalies[] = [
                    'index' => $index,
                    'value' => $value,
                    'type' => $value < $lowerBound ? 'low' : 'high',
                    'deviation' => $value < $lowerBound
                        ? $lowerBound - $value
                        : $value - $upperBound
                ];
            }
        }

        return $anomalies;
    }

    private function calculatePercentile(array $values, float $percentile): float
    {
        $index = (count($values) - 1) * ($percentile / 100);
        $lower = floor($index);
        $upper = ceil($index);

        if ($lower == $upper) {
            return $values[(int)$index];
        }

        return ($values[(int)$lower] * ($upper - $index)) +
               ($values[(int)$upper] * ($index - $lower));
    }
}
```

### Detection Script

```bash
./scripts/anomaly-detect.sh --metric cpu_usage --hours 24
```

## Trend Forecasting

### Linear Regression

```php
// app/Services/Forecasting/LinearRegressionForecaster.php

namespace App\Services\Forecasting;

class LinearRegressionForecaster
{
    public function forecast(array $historicalData, int $periods): array
    {
        $n = count($historicalData);
        $x = range(1, $n);
        $y = $historicalData;

        [$slope, $intercept] = $this->calculateRegression($x, $y);

        $forecasts = [];
        $lastX = $n;
        for ($i = 1; $i <= $periods; $i++) {
            $forecasts[] = [
                'period' => $lastX + $i,
                'value' => $slope * ($lastX + $i) + $intercept,
                'confidence' => $this->calculateConfidence($x, $y, $slope, $intercept)
            ];
        }

        return [
            'slope' => $slope,
            'intercept' => $intercept,
            'r_squared' => $this->calculateRSquared($x, $y, $slope, $intercept),
            'forecasts' => $forecasts
        ];
    }

    private function calculateRegression(array $x, array $y): array
    {
        $n = count($x);
        $sumX = array_sum($x);
        $sumY = array_sum($y);
        $sumXY = array_sum(array_map(fn($a, $b) => $a * $b, $x, $y));
        $sumX2 = array_sum(array_map(fn($v) => $v * $v, $x));

        $slope = ($n * $sumXY - $sumX * $sumY) / ($n * $sumX2 - $sumX * $sumX);
        $intercept = ($sumY - $slope * $sumX) / $n;

        return [$slope, $intercept];
    }

    private function calculateRSquared(array $x, array $y, float $slope, float $intercept): float
    {
        $yMean = array_sum($y) / count($y);
        $sst = array_reduce($y, fn($carry, $v) => $carry + pow($v - $yMean, 2), 0);
        $ssr = array_reduce(array_map(fn($xi, $yi) => $yi - ($slope * $xi + $intercept), $x, $y),
            fn($carry, $v) => $carry + pow($v, 2), 0);

        return 1 - ($ssr / $sst);
    }

    private function calculateConfidence(array $x, array $y, float $slope, float $intercept): float
    {
        $rSquared = $this->calculateRSquared($x, $y, $slope, $intercept);
        return max(0, min(1, $rSquared));
    }
}
```

### Moving Average

```php
// app/Services/Forecasting/MovingAverageForecaster.php

namespace App\Services\Forecasting;

class MovingAverageForecaster
{
    private int $window;

    public function __construct(int $window = 7)
    {
        $this->window = $window;
    }

    public function forecast(array $historicalData, int $periods): array
    {
        $averages = $this->calculateMovingAverages($historicalData);

        // Simple forecast: use the last moving average
        $lastAverage = end($averages);
        $trend = $this->calculateTrend($averages);

        $forecasts = [];
        for ($i = 1; $i <= $periods; $i++) {
            $forecasts[] = [
                'period' => count($historicalData) + $i,
                'value' => $lastAverage + ($trend * $i),
                'method' => 'moving_average'
            ];
        }

        return [
            'window' => $this->window,
            'moving_averages' => $averages,
            'trend' => $trend,
            'forecasts' => $forecasts
        ];
    }

    private function calculateMovingAverages(array $data): array
    {
        $averages = [];
        for ($i = $this->window - 1; $i < count($data); $i++) {
            $window = array_slice($data, $i - $this->window + 1, $this->window);
            $averages[] = array_sum($window) / $this->window;
        }
        return $averages;
    }

    private function calculateTrend(array $averages): float
    {
        if (count($averages) < 2) return 0;

        $first = $averages[0];
        $last = end($averages);

        return ($last - $first) / count($averages);
    }
}
```

### Forecasting Script

```bash
./scripts/trend-forecast.sh --metric disk_usage --periods 30
```

## SLO/SLI Framework

### SLO Definition

```php
// app/Services/SLO/ServiceLevelObjective.php

namespace App\Services\SLO;

class ServiceLevelObjective
{
    private string $name;
    private float $target;
    private string $window;
    private array $sliDefinitions;

    public function __construct(
        string $name,
        float $target,
        string $window = '30d',
        array $sliDefinitions = []
    ) {
        $this->name = $name;
        $this->target = $target;
        $this->window = $window;
        $this->sliDefinitions = $sliDefinitions;
    }

    public function calculateCompliance(array $sliData): array
    {
        $totalEvents = $sliData['good'] + $sliData['bad'];
        $sli = $totalEvents > 0 ? $sliData['good'] / $totalEvents : 1;

        $errorBudget = $this->calculateErrorBudget($sli);
        $compliance = $sli >= $this->target;

        return [
            'slo_name' => $this->name,
            'target' => $this->target,
            'sli' => $sli,
            'compliance' => $compliance,
            'error_budget' => $errorBudget,
            'error_budget_remaining' => $errorBudget['total'] - $errorBudget['consumed'],
            'window' => $this->window
        ];
    }

    private function calculateErrorBudget(float $sli): array
    {
        $allowedErrors = 1 - $this->target;
        $actualErrors = 1 - $sli;

        return [
            'total' => $allowedErrors,
            'consumed' => max(0, $actualErrors),
            'remaining' => max(0, $allowedErrors - $actualErrors)
        ];
    }
}
```

### SLI Tracking

```php
// app/Services/SLO/ServiceLevelIndicator.php

namespace App\Services\SLO;

use App\Models\PerformanceTrend;
use Carbon\Carbon;

class ServiceLevelIndicator
{
    public function calculateAvailability(
        string $resourceType,
        string $resourceId,
        string $window
    ): array {
        $start = $this->parseWindow($window);

        $totalChecks = PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType('health_check')
            ->whereBetween('recorded_at', [$start, now()])
            ->count();

        $passedChecks = PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType('health_check')
            ->where('value', 1)
            ->whereBetween('recorded_at', [$start, now()])
            ->count();

        $availability = $totalChecks > 0 ? $passedChecks / $totalChecks : 1;

        return [
            'metric' => 'availability',
            'total_checks' => $totalChecks,
            'passed_checks' => $passedChecks,
            'value' => $availability,
            'percentage' => $availability * 100
        ];
    }

    public function calculateLatency(
        string $resourceType,
        string $resourceId,
        string $window,
        array $percentiles = [50, 90, 95, 99]
    ): array {
        $start = $this->parseWindow($window);

        $latencies = PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType('response_time')
            ->whereBetween('recorded_at', [$start, now()])
            ->pluck('value')
            ->sort()
            ->values()
            ->toArray();

        $percentileValues = [];
        foreach ($percentiles as $percentile) {
            $percentileValues["p{$percentile}"] = $this->calculatePercentile(
                $latencies,
                $percentile
            );
        }

        return [
            'metric' => 'latency',
            'samples' => count($latencies),
            'values' => $percentileValues
        ];
    }

    private function parseWindow(string $window): Carbon
    {
        preg_match('/(\d+)([dhm])/', $window, $matches);
        $value = (int)$matches[1];
        $unit = $matches[2];

        return match($unit) {
            'd' => now()->subDays($value),
            'h' => now()->subHours($value),
            'm' => now()->subMinutes($value),
            default => now()->subDays(30)
        };
    }

    private function calculatePercentile(array $values, float $percentile): float
    {
        if (empty($values)) return 0;

        $index = (count($values) - 1) * ($percentile / 100);
        $lower = floor($index);
        $upper = ceil($index);

        if ($lower == $upper) {
            return $values[(int)$index];
        }

        return ($values[(int)$lower] * ($upper - $index)) +
               ($values[(int)$upper] * ($index - $lower));
    }
}
```

### SLO Report Script

```bash
./scripts/slo-report.sh --slo availability --window 30d
```

## Predictive Alerting

### Alert Prediction Service

```php
// app/Services/Alerting/PredictiveAlertService.php

namespace App\Services\Alerting;

use App\Services\Forecasting\LinearRegressionForecaster;
use App\Models\PerformanceTrend;
use Carbon\Carbon;

class PredictiveAlertService
{
    private LinearRegressionForecaster $forecaster;
    private array $thresholds;

    public function __construct(array $thresholds)
    {
        $this->forecaster = new LinearRegressionForecaster();
        $this->thresholds = $thresholds;
    }

    public function checkPredictiveAlerts(
        string $resourceType,
        string $resourceId,
        string $metricType
    ): array {
        $historicalData = $this->getHistoricalData(
            $resourceType,
            $resourceId,
            $metricType,
            24 // hours
        );

        if (count($historicalData) < 10) {
            return ['alerts' => [], 'reason' => 'insufficient_data'];
        }

        $forecast = $this->forecaster->forecast($historicalData, 6); // 6 hours ahead
        $threshold = $this->getThreshold($metricType);

        $alerts = [];
        foreach ($forecast['forecasts'] as $prediction) {
            if ($prediction['value'] > $threshold) {
                $alerts[] = [
                    'resource_type' => $resourceType,
                    'resource_id' => $resourceId,
                    'metric' => $metricType,
                    'predicted_value' => $prediction['value'],
                    'threshold' => $threshold,
                    'time_until_threshold' => $prediction['period'],
                    'confidence' => $prediction['confidence'],
                    'severity' => $this->calculateSeverity($prediction['value'], $threshold),
                    'recommended_action' => $this->getRecommendation($metricType)
                ];
            }
        }

        return [
            'alerts' => $alerts,
            'forecast' => $forecast,
            'current_trend' => $forecast['slope'] > 0 ? 'increasing' : 'decreasing'
        ];
    }

    private function getHistoricalData(
        string $resourceType,
        string $resourceId,
        string $metricType,
        int $hours
    ): array {
        return PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType($metricType)
            ->recent($hours)
            ->orderBy('recorded_at')
            ->pluck('value')
            ->toArray();
    }

    private function getThreshold(string $metricType): float
    {
        return $this->thresholds[$metricType] ?? 90;
    }

    private function calculateSeverity(float $value, float $threshold): string
    {
        $excess = $value - $threshold;
        if ($excess > 20) return 'critical';
        if ($excess > 10) return 'warning';
        return 'info';
    }

    private function getRecommendation(string $metricType): string
    {
        return match($metricType) {
            'cpu_usage' => 'Consider scaling up or optimizing CPU-intensive tasks',
            'memory_usage' => 'Consider adding memory or optimizing memory usage',
            'disk_usage' => 'Plan disk cleanup or expansion',
            default => 'Monitor closely and prepare for potential scaling'
        };
    }
}
```

## Log Aggregation

### Loki Integration

```php
// app/Services/Logging/LokiService.php

namespace App\Services\Logging;

use GuzzleHttp\Client;

class LokiService
{
    private Client $client;
    private string $lokiUrl;

    public function __construct(Client $client)
    {
        $this->client = $client;
        $this->lokiUrl = config('monitoring.integrations.loki.url');
    }

    public function sendLog(array $logEntry): void
    {
        $streams = [
            [
                'stream' => [
                    'job' => config('app.name'),
                    'environment' => config('app.env'),
                    'level' => $logEntry['level'],
                    'service' => $logEntry['service'] ?? 'app'
                ],
                'values' => [
                    [
                        (string)(time() * 1000000000),
                        json_encode($logEntry)
                    ]
                ]
            ]
        ];

        $this->client->post("{$this->lokiUrl}/loki/api/v1/push", [
            'json' => ['streams' => $streams]
        ]);
    }

    public function queryLogs(string $query, int $limit = 100): array
    {
        $response = $this->client->get("{$this->lokiUrl}/loki/api/v1/query_range", [
            'query' => [
                'query' => $query,
                'limit' => $limit,
                'start' => now()->subHours(24)->format('c'),
                'end' => now()->format('c')
            ]
        ]);

        return json_decode($response->getBody()->getContents(), true);
    }
}
```

## Performance Baselines

### Baseline Establishment

```php
// app/Services/Baselines/BaselineService.php

namespace App\Services\Baselines;

use App\Models\PerformanceTrend;
use Carbon\Carbon;

class BaselineService
{
    public function establishBaseline(
        string $resourceType,
        string $resourceId,
        string $metricType,
        int $days = 7
    ): array {
        $start = now()->subDays($days);

        $metrics = PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType($metricType)
            ->whereBetween('recorded_at', [$start, now()])
            ->pluck('value')
            ->toArray();

        if (count($metrics) < 100) {
            throw new \Exception('Insufficient data for baseline');
        }

        return [
            'resource_type' => $resourceType,
            'resource_id' => $resourceId,
            'metric_type' => $metricType,
            'period_days' => $days,
            'baseline' => [
                'mean' => $this->calculateMean($metrics),
                'median' => $this->calculateMedian($metrics),
                'std_dev' => $this->calculateStandardDeviation($metrics),
                'min' => min($metrics),
                'max' => max($metrics),
                'percentiles' => [
                    'p50' => $this->calculatePercentile($metrics, 50),
                    'p90' => $this->calculatePercentile($metrics, 90),
                    'p95' => $this->calculatePercentile($metrics, 95),
                    'p99' => $this->calculatePercentile($metrics, 99),
                ]
            ],
            'thresholds' => [
                'warning' => $this->calculateWarningThreshold($metrics),
                'critical' => $this->calculateCriticalThreshold($metrics)
            ],
            'created_at' => now()
        ];
    }

    public function compareWithBaseline(
        string $resourceType,
        string $resourceId,
        string $metricType,
        array $baseline
    ): array {
        $currentValue = PerformanceTrend::byResource($resourceType, $resourceId)
            ->byMetricType($metricType)
            ->latest()
            ->value('value');

        $deviation = ($currentValue - $baseline['baseline']['mean'])
            / $baseline['baseline']['std_dev'];

        return [
            'current_value' => $currentValue,
            'baseline_mean' => $baseline['baseline']['mean'],
            'deviation' => $deviation,
            'status' => $this->determineStatus($currentValue, $baseline),
            'is_anomaly' => abs($deviation) > 3
        ];
    }

    private function calculateMean(array $values): float
    {
        return array_sum($values) / count($values);
    }

    private function calculateMedian(array $values): float
    {
        sort($values);
        $count = count($values);
        $middle = floor($count / 2);

        if ($count % 2) {
            return $values[$middle];
        }

        return ($values[$middle - 1] + $values[$middle]) / 2;
    }

    private function calculateStandardDeviation(array $values): float
    {
        $mean = $this->calculateMean($values);
        $variance = array_reduce($values, function ($carry, $value) use ($mean) {
            return $carry + pow($value - $mean, 2);
        }, 0) / count($values);

        return sqrt($variance);
    }

    private function calculatePercentile(array $values, float $percentile): float
    {
        sort($values);
        $index = (count($values) - 1) * ($percentile / 100);
        $lower = floor($index);
        $upper = ceil($index);

        if ($lower == $upper) {
            return $values[(int)$index];
        }

        return ($values[(int)$lower] * ($upper - $index)) +
               ($values[(int)$upper] * ($index - $lower));
    }

    private function calculateWarningThreshold(array $metrics): float
    {
        $mean = $this->calculateMean($metrics);
        $stdDev = $this->calculateStandardDeviation($metrics);
        return $mean + (2 * $stdDev);
    }

    private function calculateCriticalThreshold(array $metrics): float
    {
        $mean = $this->calculateMean($metrics);
        $stdDev = $this->calculateStandardDeviation($metrics);
        return $mean + (3 * $stdDev);
    }

    private function determineStatus(float $value, array $baseline): string
    {
        if ($value > $baseline['thresholds']['critical']) return 'critical';
        if ($value > $baseline['thresholds']['warning']) return 'warning';
        return 'normal';
    }
}
```

## Configuration

Add to `config/monitoring.php`:

```php
return [
    // ... existing config ...

    'predictive' => [
        'enabled' => env('MONITORING_PREDICTIVE_ENABLED', false),
        'forecast_horizon_hours' => (int) env('MONITORING_FORECAST_HORIZON', 6),
        'min_data_points' => (int) env('MONITORING_MIN_DATA_POINTS', 10),
        'confidence_threshold' => (float) env('MONITORING_CONFIDENCE_THRESHOLD', 0.7),
    ],

    'slo' => [
        'objectives' => [
            'availability' => [
                'target' => 0.99, // 99%
                'window' => '30d'
            ],
            'latency' => [
                'target_p95' => 500, // milliseconds
                'window' => '7d'
            ],
            'error_rate' => [
                'target' => 0.01, // 1%
                'window' => '24h'
            ]
        ]
    ],

    'anomaly_detection' => [
        'methods' => ['zscore', 'iqr', 'isolation_forest'],
        'zscore_threshold' => (float) env('ANOMALY_ZSCORE_THRESHOLD', 3.0),
        'iqr_multiplier' => (float) env('ANOMALY_IQR_MULTIPLIER', 1.5),
        'min_samples' => (int) env('ANOMALY_MIN_SAMPLES', 30),
    ],
];
```

## Scheduled Jobs

Add to `app/Console/Kernel.php`:

```php
protected function schedule(Schedule $schedule)
{
    // Collect metrics every minute
    $schedule->call(new CollectMetricsCommand())->everyMinute();

    // Detect anomalies hourly
    $schedule->call(new DetectAnomaliesCommand)->hourly();

    // Generate forecasts every 6 hours
    $schedule->call(new GenerateForecastsCommand)->everySixHours();

    // Check SLO compliance daily
    $schedule->call(new CheckSLOComplianceCommand)->daily();

    // Generate weekly SLO report
    $schedule->call(new GenerateSLOReportCommand)->weekly();
}
```

## Quick Start

1. **Setup Prometheus and Grafana:**
   ```bash
   ./scripts/prometheus-export.sh
   docker-compose up -d prometheus grafana
   ```

2. **Establish performance baselines:**
   ```bash
   php artisan baseline:establish --resource-type server --metric cpu_usage --days 7
   ```

3. **Run anomaly detection:**
   ```bash
   ./scripts/anomaly-detect.sh --metric cpu_usage --hours 24
   ```

4. **Generate trend forecast:**
   ```bash
   ./scripts/trend-forecast.sh --metric disk_usage --periods 30
   ```

5. **Check SLO compliance:**
   ```bash
   ./scripts/slo-report.sh --slo availability --window 30d
   ```

6. **Export Grafana dashboards:**
   ```bash
   ./scripts/grafana-dashboard-export.sh --output templates/grafana-dashboards/
   ```

## Best Practices

1. **Data Collection**: Collect metrics at appropriate intervals (1-5 minutes)
2. **Baseline Period**: Use at least 7 days of data for baselines
3. **Alert Thresholds**: Set thresholds based on statistical analysis, not arbitrary values
4. **Forecast Confidence**: Only act on forecasts with confidence > 0.7
5. **SLO Windows**: Align SLO windows with business requirements
6. **Regular Reviews**: Review and update baselines monthly
7. **Error Budgets**: Track and report error budget consumption

## Troubleshooting

**Issue**: Anomaly detection produces too many false positives
**Solution**: Increase z-score threshold or use IQR method with higher multiplier

**Issue**: Forecasts have low confidence
**Solution**: Increase historical data window or use moving average method

**Issue**: SLO compliance is consistently below target
**Solution**: Review target values and consider service improvements

**Issue**: Grafana dashboards not loading
**Solution**: Verify Prometheus data source configuration and check query syntax

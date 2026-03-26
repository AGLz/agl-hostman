<?php

namespace App\Livewire;

use App\Models\PerformanceTrend;
use Livewire\Component;

/**
 * Resource Trend Chart Component
 *
 * Displays interactive charts for resource usage trends over time.
 * Supports CPU, memory, disk, and custom metrics.
 */
class ResourceTrendChart extends Component
{
    public string $metricType = 'container_performance';

    public string $metricName = 'cpu_usage';

    public string $chartType = 'line'; // line, area, bar

    public int $hours = 24;

    public ?string $node = null;

    public ?int $vmid = null;

    public array $chartData = [];

    public array $statistics = [];

    protected $listeners = [
        'refreshChart' => 'loadChartData',
        'updateMetric' => 'updateMetric',
    ];

    public function mount(
        string $metricType = 'container_performance',
        string $metricName = 'cpu_usage',
        ?string $node = null,
        ?int $vmid = null,
        int $hours = 24
    ) {
        $this->metricType = $metricType;
        $this->metricName = $metricName;
        $this->node = $node;
        $this->vmid = $vmid;
        $this->hours = $hours;
        $this->loadChartData();
    }

    public function render()
    {
        return view('livewire.resource-trend-chart', [
            'chartData' => $this->chartData,
            'statistics' => $this->statistics,
            'chartConfig' => $this->getChartConfig(),
        ]);
    }

    /**
     * Load chart data from performance trends
     */
    public function loadChartData()
    {
        try {
            // Get trend statistics
            $this->statistics = PerformanceTrend::getTrendStats(
                $this->metricType,
                $this->metricName,
                $this->hours,
                $this->node,
                $this->vmid
            );

            // Get detailed data points
            $query = PerformanceTrend::ofType($this->metricType)
                ->named($this->metricName)
                ->recent($this->hours)
                ->chronological();

            if ($this->node) {
                $query->forNode($this->node);
            }

            if ($this->vmid) {
                $query->where('vmid', $this->vmid);
            }

            $trends = $query->get();

            $this->chartData = [
                'labels' => $trends->map(fn ($trend) => $trend->recorded_at->format('H:i'))->toArray(),
                'datasets' => [[
                    'label' => $this->getMetricLabel(),
                    'data' => $trends->pluck('value')->toArray(),
                    'backgroundColor' => $this->getChartColor('background'),
                    'borderColor' => $this->getChartColor('border'),
                    'borderWidth' => 2,
                    'fill' => $this->chartType === 'area',
                    'tension' => 0.4,
                ]],
            ];

        } catch (\Exception $e) {
            $this->chartData = [
                'error' => 'Failed to load chart data: '.$e->getMessage(),
            ];
        }
    }

    /**
     * Update metric and refresh chart
     */
    public function updateMetric(string $metricType, string $metricName)
    {
        $this->metricType = $metricType;
        $this->metricName = $metricName;
        $this->loadChartData();
    }

    /**
     * Change time range
     */
    public function setTimeRange(int $hours)
    {
        $this->hours = min(max($hours, 1), 168); // 1 hour to 7 days
        $this->loadChartData();
    }

    /**
     * Change chart type
     */
    public function setChartType(string $type)
    {
        $this->chartType = in_array($type, ['line', 'area', 'bar']) ? $type : 'line';
        $this->loadChartData();
    }

    /**
     * Get chart configuration for Chart.js
     */
    protected function getChartConfig(): array
    {
        return [
            'type' => $this->chartType === 'area' ? 'line' : $this->chartType,
            'options' => [
                'responsive' => true,
                'maintainAspectRatio' => false,
                'plugins' => [
                    'legend' => [
                        'display' => true,
                        'position' => 'top',
                    ],
                    'tooltip' => [
                        'mode' => 'index',
                        'intersect' => false,
                    ],
                ],
                'scales' => [
                    'y' => [
                        'beginAtZero' => true,
                        'max' => $this->getMaxValue(),
                        'ticks' => [
                            'callback' => 'function(value) { return value + "%"; }',
                        ],
                    ],
                    'x' => [
                        'display' => true,
                        'title' => [
                            'display' => true,
                            'text' => 'Time',
                        ],
                    ],
                ],
            ],
        ];
    }

    /**
     * Get metric label for display
     */
    protected function getMetricLabel(): string
    {
        return match ($this->metricName) {
            'cpu_usage' => 'CPU Usage (%)',
            'memory_usage' => 'Memory Usage (%)',
            'disk_usage' => 'Disk Usage (%)',
            'network_rx' => 'Network RX (MB/s)',
            'network_tx' => 'Network TX (MB/s)',
            default => ucwords(str_replace('_', ' ', $this->metricName)),
        };
    }

    /**
     * Get chart colors based on metric
     */
    protected function getChartColor(string $type = 'border'): string
    {
        $colors = match ($this->metricName) {
            'cpu_usage' => [
                'border' => 'rgb(59, 130, 246)', // Blue
                'background' => 'rgba(59, 130, 246, 0.1)',
            ],
            'memory_usage' => [
                'border' => 'rgb(16, 185, 129)', // Green
                'background' => 'rgba(16, 185, 129, 0.1)',
            ],
            'disk_usage' => [
                'border' => 'rgb(245, 158, 11)', // Orange
                'background' => 'rgba(245, 158, 11, 0.1)',
            ],
            default => [
                'border' => 'rgb(107, 114, 128)', // Gray
                'background' => 'rgba(107, 114, 128, 0.1)',
            ],
        };

        return $colors[$type] ?? $colors['border'];
    }

    /**
     * Get max value for Y-axis
     */
    protected function getMaxValue(): int
    {
        // For percentage metrics, max is 100
        if (str_contains($this->metricName, 'usage') || str_contains($this->metricName, 'percent')) {
            return 100;
        }

        // For other metrics, use max from statistics + 10%
        return isset($this->statistics['max'])
            ? (int) ceil($this->statistics['max'] * 1.1)
            : 100;
    }

    /**
     * Export chart data as CSV
     */
    public function exportCsv()
    {
        $filename = "{$this->metricType}_{$this->metricName}_".now()->format('Y-m-d_His').'.csv';

        $csv = "Timestamp,{$this->getMetricLabel()}\n";

        foreach ($this->chartData['labels'] as $index => $label) {
            $value = $this->chartData['datasets'][0]['data'][$index] ?? '';
            $csv .= "{$label},{$value}\n";
        }

        return response()->streamDownload(function () use ($csv) {
            echo $csv;
        }, $filename, [
            'Content-Type' => 'text/csv',
        ]);
    }
}

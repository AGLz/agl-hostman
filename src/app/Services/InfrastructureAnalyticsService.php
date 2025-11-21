<?php

namespace App\Services;

use App\Models\PhysicalLocation;
use App\Events\InfrastructureStatusUpdated;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Http;

class InfrastructureAnalyticsService
{
    protected AIModelService $aiService;
    protected FlexibleCacheService $cacheService;

    public function __construct(AIModelService $aiService, FlexibleCacheService $cacheService)
    {
        $this->aiService = $aiService;
        $this->cacheService = $cacheService;
    }

    /**
     * Analyze infrastructure metrics with AI
     */
    public function analyzeInfrastructure(array $metrics): array
    {
        // Use flexible caching for infrastructure analysis
        return $this->cacheService->cacheInfrastructureAnalysis($metrics, function() use ($metrics) {
            $analysis = [
                'health_score' => $this->calculateHealthScore($metrics),
                'predictions' => $this->predictFutureIssues($metrics),
                'recommendations' => $this->generateRecommendations($metrics),
                'anomalies' => $this->detectAnomalies($metrics),
                'optimization_opportunities' => $this->findOptimizations($metrics),
            ];

            // Get AI insights
            $aiAnalysis = $this->getAIInsights($metrics, $analysis);
            $analysis['ai_insights'] = $aiAnalysis;

            return $analysis;
        });
    }

    /**
     * Calculate overall health score
     */
    protected function calculateHealthScore(array $metrics): array
    {
        $totalScore = 0;
        $weights = [
            'cpu' => 0.3,
            'memory' => 0.3,
            'disk' => 0.2,
            'network' => 0.1,
            'services' => 0.1,
        ];
        
        $scores = [];
        
        foreach ($metrics as $server => $data) {
            $serverScore = 100;
            
            // CPU score
            if (isset($data['metrics']['resources']['cpu_usage'])) {
                $cpuScore = 100 - $data['metrics']['resources']['cpu_usage'];
                $serverScore -= (100 - $cpuScore) * $weights['cpu'];
            }
            
            // Memory score
            if (isset($data['metrics']['resources']['memory_usage'])) {
                $memScore = 100 - $data['metrics']['resources']['memory_usage'];
                $serverScore -= (100 - $memScore) * $weights['memory'];
            }
            
            // Disk score
            if (isset($data['metrics']['resources']['disk_usage'])) {
                $diskScore = 100 - $data['metrics']['resources']['disk_usage'];
                $serverScore -= (100 - $diskScore) * $weights['disk'];
            }
            
            // Services score
            if (isset($data['metrics']['services'])) {
                $totalServices = count($data['metrics']['services']);
                $healthyServices = array_filter($data['metrics']['services']);
                $servicesScore = $totalServices > 0 ? (count($healthyServices) / $totalServices) * 100 : 100;
                $serverScore -= (100 - $servicesScore) * $weights['services'];
            }
            
            $scores[$server] = round($serverScore, 2);
            $totalScore += $serverScore;
        }
        
        return [
            'overall' => round($totalScore / max(count($metrics), 1), 2),
            'servers' => $scores,
            'status' => $this->getHealthStatus($totalScore / max(count($metrics), 1)),
        ];
    }

    /**
     * Predict future issues using AI
     */
    protected function predictFutureIssues(array $metrics): array
    {
        $predictions = [];
        
        foreach ($metrics as $server => $data) {
            $serverPredictions = [];
            
            // High CPU prediction
            if (isset($data['metrics']['resources']['cpu_usage']) && $data['metrics']['resources']['cpu_usage'] > 70) {
                $serverPredictions[] = [
                    'type' => 'cpu_overload',
                    'probability' => min(95, $data['metrics']['resources']['cpu_usage'] + 20),
                    'timeframe' => '2-4 hours',
                    'impact' => 'high',
                ];
            }
            
            // Memory leak detection
            if (isset($data['metrics']['resources']['memory_usage']) && $data['metrics']['resources']['memory_usage'] > 80) {
                $serverPredictions[] = [
                    'type' => 'memory_exhaustion',
                    'probability' => min(90, $data['metrics']['resources']['memory_usage'] + 10),
                    'timeframe' => '4-8 hours',
                    'impact' => 'critical',
                ];
            }
            
            // Disk space prediction
            if (isset($data['metrics']['resources']['disk_usage']) && $data['metrics']['resources']['disk_usage'] > 75) {
                $serverPredictions[] = [
                    'type' => 'disk_full',
                    'probability' => $data['metrics']['resources']['disk_usage'],
                    'timeframe' => '1-2 days',
                    'impact' => 'medium',
                ];
            }
            
            if (!empty($serverPredictions)) {
                $predictions[$server] = $serverPredictions;
            }
        }
        
        return $predictions;
    }

    /**
     * Generate AI-powered recommendations
     */
    protected function generateRecommendations(array $metrics): array
    {
        $recommendations = [];
        
        foreach ($metrics as $server => $data) {
            $serverRecs = [];
            
            // CPU recommendations
            if (isset($data['metrics']['resources']['cpu_usage']) && $data['metrics']['resources']['cpu_usage'] > 80) {
                $serverRecs[] = [
                    'priority' => 'high',
                    'action' => 'scale_horizontally',
                    'description' => 'Consider adding more CPU cores or distributing load',
                    'estimated_impact' => '30-40% CPU reduction',
                ];
            }
            
            // Memory recommendations
            if (isset($data['metrics']['resources']['memory_usage']) && $data['metrics']['resources']['memory_usage'] > 85) {
                $serverRecs[] = [
                    'priority' => 'critical',
                    'action' => 'increase_memory',
                    'description' => 'Increase RAM allocation or optimize memory usage',
                    'estimated_impact' => 'Prevent OOM errors',
                ];
            }
            
            // Container optimization
            if (isset($data['metrics']['resources']['container_count']) && $data['metrics']['resources']['container_count'] > 15) {
                $serverRecs[] = [
                    'priority' => 'medium',
                    'action' => 'consolidate_containers',
                    'description' => 'Consider consolidating similar containers',
                    'estimated_impact' => '20% resource optimization',
                ];
            }
            
            if (!empty($serverRecs)) {
                $recommendations[$server] = $serverRecs;
            }
        }
        
        return $recommendations;
    }

    /**
     * Detect anomalies in metrics
     */
    protected function detectAnomalies(array $metrics): array
    {
        $anomalies = [];
        
        // Get historical data for comparison
        $historical = Cache::get('infrastructure_history', []);
        
        foreach ($metrics as $server => $data) {
            $serverAnomalies = [];
            
            // Check for sudden spikes
            if (isset($historical[$server])) {
                $prev = $historical[$server];
                
                // CPU spike detection
                if (isset($data['metrics']['resources']['cpu_usage']) && 
                    isset($prev['metrics']['resources']['cpu_usage'])) {
                    $cpuDiff = $data['metrics']['resources']['cpu_usage'] - $prev['metrics']['resources']['cpu_usage'];
                    if (abs($cpuDiff) > 30) {
                        $serverAnomalies[] = [
                            'type' => 'cpu_spike',
                            'severity' => abs($cpuDiff) > 50 ? 'high' : 'medium',
                            'change' => $cpuDiff . '%',
                            'timestamp' => now()->toIso8601String(),
                        ];
                    }
                }
                
                // Service failure detection
                if (isset($data['metrics']['services'])) {
                    foreach ($data['metrics']['services'] as $service => $status) {
                        if (!$status && isset($prev['metrics']['services'][$service]) && $prev['metrics']['services'][$service]) {
                            $serverAnomalies[] = [
                                'type' => 'service_failure',
                                'severity' => 'high',
                                'service' => $service,
                                'timestamp' => now()->toIso8601String(),
                            ];
                        }
                    }
                }
            }
            
            // Check for unreachable servers
            if ($data['status'] === 'critical') {
                $serverAnomalies[] = [
                    'type' => 'server_unreachable',
                    'severity' => 'critical',
                    'timestamp' => now()->toIso8601String(),
                ];
            }
            
            if (!empty($serverAnomalies)) {
                $anomalies[$server] = $serverAnomalies;
            }
        }
        
        // Store current metrics as historical
        Cache::put('infrastructure_history', $metrics, now()->addHours(24));
        
        return $anomalies;
    }

    /**
     * Find optimization opportunities
     */
    protected function findOptimizations(array $metrics): array
    {
        $optimizations = [];
        
        foreach ($metrics as $server => $data) {
            $serverOpts = [];
            
            // Under-utilized resources
            if (isset($data['metrics']['resources'])) {
                $resources = $data['metrics']['resources'];
                
                if ($resources['cpu_usage'] < 20 && $resources['memory_usage'] < 30) {
                    $serverOpts[] = [
                        'type' => 'under_utilized',
                        'suggestion' => 'Consider consolidating workloads or downsizing',
                        'potential_savings' => '30-40%',
                    ];
                }
                
                if ($resources['memory_usage'] < 50 && $resources['cpu_usage'] > 70) {
                    $serverOpts[] = [
                        'type' => 'cpu_bound',
                        'suggestion' => 'Optimize CPU-intensive processes or upgrade CPU',
                        'potential_improvement' => '25-35% performance gain',
                    ];
                }
            }
            
            // Container density optimization
            if (isset($data['metrics']['resources']['container_count'])) {
                if ($data['metrics']['resources']['container_count'] < 5) {
                    $serverOpts[] = [
                        'type' => 'low_density',
                        'suggestion' => 'Server has capacity for more containers',
                        'potential_capacity' => '10-15 additional containers',
                    ];
                }
            }
            
            if (!empty($serverOpts)) {
                $optimizations[$server] = $serverOpts;
            }
        }
        
        return $optimizations;
    }

    /**
     * Get AI insights using multiple models
     */
    protected function getAIInsights(array $metrics, array $analysis): array
    {
        $prompt = $this->buildAIPrompt($metrics, $analysis);
        
        // Use multi-agent query for comprehensive analysis
        $insights = $this->aiService->multiAgentQuery(
            ['claude', 'gemini', 'openai'],
            $prompt,
            ['context' => 'infrastructure_analytics']
        );
        
        return [
            'consensus' => $this->extractConsensus($insights),
            'model_specific' => $insights,
            'confidence_level' => $this->calculateConfidence($insights),
        ];
    }

    /**
     * Build prompt for AI analysis
     */
    protected function buildAIPrompt(array $metrics, array $analysis): string
    {
        return "Analyze the following infrastructure metrics and provide strategic insights:\n\n" .
               "Current Metrics:\n" . json_encode($metrics, JSON_PRETTY_PRINT) . "\n\n" .
               "Initial Analysis:\n" . json_encode($analysis, JSON_PRETTY_PRINT) . "\n\n" .
               "Please provide:\n" .
               "1. Key risks to watch\n" .
               "2. Optimization strategies\n" .
               "3. Capacity planning recommendations\n" .
               "4. Cost optimization opportunities\n" .
               "5. Security considerations\n\n" .
               "Format your response as actionable insights.";
    }

    /**
     * Extract consensus from multiple AI responses
     */
    protected function extractConsensus(array $responses): array
    {
        // Simple consensus extraction - can be enhanced
        $consensus = [
            'agreed_risks' => [],
            'agreed_optimizations' => [],
            'disagreements' => [],
        ];
        
        // Process responses to find common themes
        // This is a simplified implementation
        
        return $consensus;
    }

    /**
     * Calculate confidence level
     */
    protected function calculateConfidence(array $responses): float
    {
        $successfulResponses = array_filter($responses, fn($r) => $r['success'] ?? false);
        return round((count($successfulResponses) / max(count($responses), 1)) * 100, 2);
    }

    /**
     * Get health status label
     */
    protected function getHealthStatus(float $score): string
    {
        if ($score >= 90) return 'excellent';
        if ($score >= 75) return 'good';
        if ($score >= 60) return 'fair';
        if ($score >= 40) return 'poor';
        return 'critical';
    }

    /**
     * Broadcast infrastructure update
     */
    public function broadcastUpdate(string $serverCode, array $status): void
    {
        $statusLevel = 'info';
        
        if ($status['status'] === 'critical') {
            $statusLevel = 'error';
        } elseif ($status['status'] === 'warning') {
            $statusLevel = 'warning';
        }
        
        broadcast(new InfrastructureStatusUpdated($serverCode, $status, $statusLevel));
    }
}
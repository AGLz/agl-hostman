<?php

namespace Tests\LegislationAnalysis\Validators;

/**
 * Coverage Validator
 * Validates coverage completeness across all legislation analysis components
 */
class CoverageValidator
{
    private array $missingComponents = [];
    private array $coveredSections = [];

    /**
     * Validate completeness of coverage
     */
    public function validateCompleteness(array $findings): array
    {
        $this->resetValidationState();

        $requiredComponents = [
            'swarm/researcher/cmn-4963' => 'CMN-4963 Research',
            'swarm/researcher/cmn-5272' => 'CMN-5272 Research',
            'swarm/coder/comparison-results' => 'Comparison Results',
            'swarm/analyst/regulatory-impact' => 'Regulatory Impact',
        ];

        foreach ($requiredComponents as $key => $name) {
            if (isset($findings[$key]) && !empty($findings[$key])) {
                $this->coveredSections[] = $name;
            } else {
                $this->missingComponents[] = [
                    'key' => $key,
                    'name' => $name,
                    'severity' => 'high',
                ];
            }
        }

        $coveragePercentage = $this->calculateCoveragePercentage(
            count($requiredComponents),
            count($this->coveredSections)
        );

        return [
            'coverage_percentage' => $coveragePercentage,
            'covered_sections' => $this->coveredSections,
            'missing_components' => $this->missingComponents,
            'total_components' => count($requiredComponents),
            'covered_count' => count($this->coveredSections),
            'missing_count' => count($this->missingComponents),
            'is_complete' => empty($this->missingComponents),
        ];
    }

    /**
     * Validate performance metrics
     */
    public function validatePerformance(array $findings): array
    {
        $performanceData = [];

        foreach ($findings as $key => $data) {
            if (isset($data['metadata'])) {
                $performanceData[$key] = [
                    'data_size' => strlen(json_encode($data)),
                    'has_timestamp' => isset($data['metadata']['timestamp']),
                    'has_confidence' => isset($data['metadata']['confidence_score']),
                ];
            }
        }

        $totalDataSize = array_sum(array_column($performanceData, 'data_size'));
        $averageDataSize = count($performanceData) > 0
            ? $totalDataSize / count($performanceData)
            : 0;

        $efficiencyScore = $this->calculateEfficiencyScore($performanceData);

        return [
            'processing_time' => 'N/A', // Would be populated in real execution
            'data_size' => [
                'total' => $totalDataSize,
                'average' => $averageDataSize,
                'by_component' => $performanceData,
            ],
            'efficiency_score' => $efficiencyScore,
            'metadata_coverage' => $this->calculateMetadataCoverage($performanceData),
        ];
    }

    /**
     * Calculate coverage percentage
     */
    private function calculateCoveragePercentage(int $total, int $covered): float
    {
        if ($total === 0) {
            return 0.0;
        }

        return round(($covered / $total) * 100, 2);
    }

    /**
     * Calculate efficiency score based on performance data
     */
    private function calculateEfficiencyScore(array $performanceData): float
    {
        if (empty($performanceData)) {
            return 0.0;
        }

        $score = 0;
        $count = 0;

        foreach ($performanceData as $data) {
            if ($data['has_timestamp']) {
                $score += 25;
            }
            if ($data['has_confidence']) {
                $score += 25;
            }
            if ($data['data_size'] > 0) {
                $score += 25;
            }
            $count++;
        }

        return $count > 0 ? round(($score / $count), 2) : 0.0;
    }

    /**
     * Calculate metadata coverage
     */
    private function calculateMetadataCoverage(array $performanceData): array
    {
        $total = count($performanceData);
        if ($total === 0) {
            return [
                'timestamp_coverage' => 0,
                'confidence_coverage' => 0,
                'overall_coverage' => 0,
            ];
        }

        $timestampCount = count(array_filter($performanceData, fn($d) => $d['has_timestamp']));
        $confidenceCount = count(array_filter($performanceData, fn($d) => $d['has_confidence']));

        return [
            'timestamp_coverage' => round(($timestampCount / $total) * 100, 2),
            'confidence_coverage' => round(($confidenceCount / $total) * 100, 2),
            'overall_coverage' => round((($timestampCount + $confidenceCount) / ($total * 2)) * 100, 2),
        ];
    }

    /**
     * Reset validation state
     */
    private function resetValidationState(): void
    {
        $this->missingComponents = [];
        $this->coveredSections = [];
    }
}

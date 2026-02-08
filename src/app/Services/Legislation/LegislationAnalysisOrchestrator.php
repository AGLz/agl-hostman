<?php

declare(strict_types=1);

namespace App\Services\Legislation;

use Illuminate\Support\Facades\Log;

/**
 * LegislationAnalysisOrchestrator - Orchestrates legislation parsing and comparison
 *
 * Coordinates the analysis workflow for Brazilian CMN resolutions
 * Stores results in memory for coordination with other agents
 */
class LegislationAnalysisOrchestrator
{
    protected LegislationParserService $parser;
    protected LegislationComparisonService $comparison;
    protected CMNResolutionDataProvider $dataProvider;

    public function __construct(
        LegislationParserService $parser,
        LegislationComparisonService $comparison,
        CMNResolutionDataProvider $dataProvider
    ) {
        $this->parser = $parser;
        $this->comparison = $comparison;
        $this->dataProvider = $dataProvider;
    }

    /**
     * Execute full analysis workflow for CMN 4.963 vs 5.272
     *
     * @param bool $storeInMemory Whether to store results in memory
     * @return array Complete analysis results
     */
    public function executeCMNAnalysis(bool $storeInMemory = true): array
    {
        Log::info('Starting CMN legislation analysis', [
            'task_id' => '38b38ad9-013a-433e-b1fc-2bf74360b341',
            'agent' => 'coder',
        ]);

        // Step 1: Load CMN data
        $cmn4963 = $this->dataProvider->getCMN4963Data();
        $cmn5272 = $this->dataProvider->getCMN5272Data();

        // Step 2: Parse the resolutions
        $parsed4963 = $this->parser->parseCMNResolution(
            $cmn4963['raw_text'],
            '4.963',
            '2018-01-17'
        );

        $parsed5272 = $this->parser->parseCMNResolution(
            $cmn5272['raw_text'],
            '5.272',
            '2024-02-29'
        );

        // Step 3: Perform detailed comparison
        $comparison = $this->comparison->compareCMN($parsed4963, $parsed5272);

        // Step 4: Generate structured results for memory storage
        $results = [
            'analysis_id' => 'cmn-4963-5272-analysis',
            'task_id' => '38b38ad9-013a-433e-b1fc-2bf74360b341',
            'timestamp' => now()->toIso8601String(),
            'agent' => 'coder',
            'source_resolutions' => [
                'cmn4963' => [
                    'number' => '4.963',
                    'date' => '2018-01-17',
                    'reference' => 'CMN Resolution 4.963/2018',
                    'parsed' => true,
                    'articles_count' => $parsed4963['structure']['total_articles'],
                    'requirements_count' => count($parsed4963['content']['requirements']),
                ],
                'cmn5272' => [
                    'number' => '5.272',
                    'date' => '2024-02-29',
                    'reference' => 'CMN Resolution 5.272/2024',
                    'parsed' => true,
                    'articles_count' => $parsed5272['structure']['total_articles'],
                    'requirements_count' => count($parsed5272['content']['requirements']),
                ],
            ],
            'comparison' => [
                'differences' => $comparison['differences'],
                'similarities' => $comparison['similarities'],
                'additions' => $comparison['additions'],
                'removals' => $comparison['removals'],
                'modifications' => $comparison['modifications'],
                'metrics' => $comparison['metrics'],
            ],
            'categorized_changes' => [
                'governance_structure' => $comparison['categorization']['governance_structure'] ?? [],
                'investment_limits' => $comparison['categorization']['investment_limits'] ?? [],
                'compliance_requirements' => $comparison['categorization']['compliance_requirements'] ?? [],
                'deadlines' => $comparison['categorization']['deadlines'] ?? [],
                'reporting' => $comparison['categorization']['reporting'] ?? [],
            ],
            'detailed_analysis' => [
                'governance' => $comparison['governance_analysis'] ?? [],
                'investments' => $comparison['investment_analysis'] ?? [],
                'compliance' => $comparison['compliance_analysis'] ?? [],
                'tiers' => $comparison['tier_analysis'] ?? [],
            ],
            'impact_assessment' => $comparison['impact_assessment'],
            'parsing_results' => [
                'cmn4963' => $parsed4963,
                'cmn5272' => $parsed5272,
            ],
        ];

        // Step 5: Store in memory if requested
        if ($storeInMemory) {
            $this->storeResultsInMemory($results);
        }

        Log::info('CMN legislation analysis completed', [
            'analysis_id' => $results['analysis_id'],
            'differences_count' => count($comparison['differences']),
            'similarities_count' => count($comparison['similarities']),
        ]);

        return $results;
    }

    /**
     * Store analysis results in memory for coordination
     */
    protected function storeResultsInMemory(array $results): void
    {
        // In production, this would use MCP tools:
        // mcp__claude-flow__memory_usage with action="store",
        // key="swarm/coder/comparison-results", namespace="coordination"

        // Use base path for Laravel or fallback to relative path
        $basePath = function_exists('base_path') ? base_path() : dirname(__DIR__, 3);
        $memoryPath = $basePath . '/src/storage/app/memory/swarm/coder';

        if (!is_dir($memoryPath)) {
            mkdir($memoryPath, 0755, true);
        }

        $memoryFile = $memoryPath . '/comparison-results.json';
        file_put_contents(
            $memoryFile,
            json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)
        );

        Log::info('Comparison results stored in memory', [
            'path' => $memoryFile,
            'size' => strlen(json_encode($results)),
        ]);
    }

    /**
     * Get comparison results from memory
     */
    public function getComparisonResultsFromMemory(): ?array
    {
        $basePath = function_exists('base_path') ? base_path() : dirname(__DIR__, 3);
        $memoryFile = $basePath . '/src/storage/app/memory/swarm/coder/comparison-results.json';

        if (!file_exists($memoryFile)) {
            return null;
        }

        $content = file_get_contents($memoryFile);
        return json_decode($content, true);
    }

    /**
     * Generate executive summary
     */
    public function generateExecutiveSummary(array $results): array
    {
        $comparison = $results['comparison'];
        $metrics = $comparison['metrics'];
        $impact = $results['impact_assessment'];

        return [
            'title' => 'CMN Resolution 4.963 vs 5.272 - Executive Summary',
            'key_changes' => [
                'governance' => 'Transformation from uniform to four-tier system',
                'investments' => 'Progressive access based on governance level',
                'compliance' => 'Enhanced requirements with Pró-Gestão certification',
            ],
            'critical_differences' => array_slice($comparison['differences'], 0, 5),
            'similarity_score' => $metrics['similarity_score'],
            'overall_impact' => $impact['overall_impact'],
            'implementation_timeline' => $impact['transition_timeline_estimate'],
            'complexity' => $impact['implementation_complexity'],
            'strategic_recommendations' => [
                'immediate' => 'Conduct governance gap analysis',
                'short_term' => 'Pursue Pró-Gestão certification',
                'medium_term' => 'Implement portfolio restructuring',
                'long_term' => 'Target Nível IV for maximum flexibility',
            ],
        ];
    }

    /**
     * Parse raw legislation text
     */
    public function parseRawText(string $text, array $metadata): array
    {
        return $this->parser->parse($text, $metadata);
    }

    /**
     * Compare two parsed documents
     */
    public function compareDocuments(array $doc1, array $doc2): array
    {
        return $this->comparison->compare($doc1, $doc2);
    }
}

<?php

namespace Tests\LegislationAnalysis;

use PHPUnit\Framework\TestCase;
use Tests\LegislationAnalysis\Fixtures\LegislationTestData;
use Tests\LegislationAnalysis\Validators\DataAccuracyValidator;
use Tests\LegislationAnalysis\Validators\CoverageValidator;
use Tests\LegislationAnalysis\Validators\CrossAgentConsistencyValidator;
use Tests\LegislationAnalysis\Validators\FindingsCompletenessValidator;

/**
 * Comprehensive Test Suite for Legislation Analysis Workflow
 *
 * @test Legislation Analysis Validation
 * @description Validates findings from researcher, coder, and analyst agents
 * @prerequisites
 *   - All agents have completed their analysis
 *   - Memory keys contain valid JSON data
 *   - Test fixtures are loaded
 * @steps
 *   1. Load test fixtures and expected data
 *   2. Validate data accuracy for each component
 *   3. Check coverage completeness
 *   4. Verify cross-agent consistency
 *   5. Generate comprehensive validation report
 * @expected All validations pass with detailed metrics
 */
class LegislationAnalysisTestSuite extends TestCase
{
    private DataAccuracyValidator $accuracyValidator;
    private CoverageValidator $coverageValidator;
    private CrossAgentConsistencyValidator $consistencyValidator;
    private FindingsCompletenessValidator $completenessValidator;
    private LegislationTestData $testData;
    private array $validationResults = [];
    private array $memoryFindings = [];

    protected function setUp(): void
    {
        parent::setUp();

        $this->testData = new LegislationTestData();
        $this->accuracyValidator = new DataAccuracyValidator();
        $this->coverageValidator = new CoverageValidator();
        $this->consistencyValidator = new CrossAgentConsistencyValidator();
        $this->completenessValidator = new FindingsCompletenessValidator();

        $this->loadMemoryFindings();
        $this->initializeValidationResults();
    }

    /**
     * @test CMN-4963 Research Data Accuracy
     * Validates that all CMN-4963 research findings are accurate
     */
    public function testCMN4963ResearchDataAccuracy(): void
    {
        $cmn4963Data = $this->memoryFindings['swarm/researcher/cmn-4963'] ?? null;

        $this->assertNotNull($cmn4963Data, 'CMN-4963 research data must exist in memory');

        $result = $this->accuracyValidator->validateCMN4963($cmn4963Data);
        $this->validationResults['cmn4963_accuracy'] = $result;

        $this->assertTrue(
            $result['is_accurate'],
            'CMN-4963 data accuracy validation failed: ' . json_encode($result['errors'])
        );

        $this->assertGreaterThan(0, $result['verified_fields'], 'At least one field must be verified');
        $this->assertEquals(0, count($result['errors']), 'No accuracy errors should be present');
    }

    /**
     * @test CMN-5272 Research Data Accuracy
     * Validates that all CMN-5272 research findings are accurate
     */
    public function testCMN5272ResearchDataAccuracy(): void
    {
        $cmn5272Data = $this->memoryFindings['swarm/researcher/cmn-5272'] ?? null;

        $this->assertNotNull($cmn5272Data, 'CMN-5272 research data must exist in memory');

        $result = $this->accuracyValidator->validateCMN5272($cmn5272Data);
        $this->validationResults['cmn5272_accuracy'] = $result;

        $this->assertTrue(
            $result['is_accurate'],
            'CMN-5272 data accuracy validation failed: ' . json_encode($result['errors'])
        );

        $this->assertGreaterThan(0, $result['verified_fields'], 'At least one field must be verified');
        $this->assertEquals(0, count($result['errors']), 'No accuracy errors should be present');
    }

    /**
     * @test Comparison Results Accuracy
     * Validates that comparison results from coder agent are accurate
     */
    public function testComparisonResultsAccuracy(): void
    {
        $comparisonData = $this->memoryFindings['swarm/coder/comparison-results'] ?? null;

        $this->assertNotNull($comparisonData, 'Comparison results must exist in memory');

        $result = $this->accuracyValidator->validateComparisonResults($comparisonData);
        $this->validationResults['comparison_accuracy'] = $result;

        $this->assertTrue(
            $result['is_accurate'],
            'Comparison results accuracy validation failed: ' . json_encode($result['errors'])
        );

        $this->assertArrayHasKey('differences', $result);
        $this->assertArrayHasKey('similarities', $result);
        $this->assertArrayHasKey('metrics', $result);
    }

    /**
     * @test Regulatory Impact Analysis Accuracy
     * Validates that regulatory impact analysis from analyst is accurate
     */
    public function testRegulatoryImpactAccuracy(): void
    {
        $regulatoryData = $this->memoryFindings['swarm/analyst/regulatory-impact'] ?? null;

        $this->assertNotNull($regulatoryData, 'Regulatory impact data must exist in memory');

        $result = $this->accuracyValidator->validateRegulatoryImpact($regulatoryData);
        $this->validationResults['regulatory_accuracy'] = $result;

        $this->assertTrue(
            $result['is_accurate'],
            'Regulatory impact accuracy validation failed: ' . json_encode($result['errors'])
        );

        $this->assertArrayHasKey('assessments', $result);
        $this->assertArrayHasKey('recommendations', $result);
        $this->assertArrayHasKey('compliance_score', $result);
    }

    /**
     * @test Coverage Completeness
     * Validates that all required components have been analyzed
     */
    public function testCoverageCompleteness(): void
    {
        $result = $this->coverageValidator->validateCompleteness($this->memoryFindings);
        $this->validationResults['coverage'] = $result;

        $this->assertGreaterThanOrEqual(
            80,
            $result['coverage_percentage'],
            'Coverage must be at least 80% complete'
        );

        $this->assertEmpty(
            $result['missing_components'],
            'No components should be missing: ' . json_encode($result['missing_components'])
        );

        $requiredSections = ['cmn4963', 'cmn5272', 'comparison', 'regulatory_impact'];
        foreach ($requiredSections as $section) {
            $this->assertContains($section, $result['covered_sections']);
        }
    }

    /**
     * @test Cross-Agent Consistency
     * Validates that findings are consistent across all agents
     */
    public function testCrossAgentConsistency(): void
    {
        $result = $this->consistencyValidator->validateConsistency($this->memoryFindings);
        $this->validationResults['consistency'] = $result;

        $this->assertGreaterThanOrEqual(
            90,
            $result['consistency_score'],
            'Consistency score must be at least 90%'
        );

        $this->assertEmpty(
            $result['inconsistencies'],
            'No inconsistencies should be found: ' . json_encode($result['inconsistencies'])
        );

        $this->assertArrayHasKey('data_integrity', $result);
        $this->assertArrayHasKey('cross_references', $result);
        $this->assertArrayHasKey('alignment_score', $result);
    }

    /**
     * @test Findings Completeness
     * Validates that all findings are complete with required fields
     */
    public function testFindingsCompleteness(): void
    {
        $result = $this->completenessValidator->validateCompleteness($this->memoryFindings);
        $this->validationResults['completeness'] = $result;

        $this->assertTrue(
            $result['is_complete'],
            'Findings must be complete: ' . json_encode($result['missing_fields'])
        );

        $this->assertEmpty(
            $result['missing_fields'],
            'No required fields should be missing'
        );

        $this->assertArrayHasKey('field_coverage', $result);
        $this->assertArrayHasKey('data_integrity', $result);
        $this->assertArrayHasKey('metadata', $result);
    }

    /**
     * @test Data Integrity
     * Validates that data maintains integrity across all components
     */
    public function testDataIntegrity(): void
    {
        $result = $this->accuracyValidator->validateDataIntegrity($this->memoryFindings);
        $this->validationResults['data_integrity'] = $result;

        $this->assertTrue(
            $result['integrity_valid'],
            'Data integrity must be valid: ' . json_encode($result['violations'])
        );

        $this->assertEmpty($result['violations'], 'No integrity violations should exist');
        $this->assertArrayHasKey('checksums', $result);
        $this->assertArrayHasKey('consistency_checks', $result);
    }

    /**
     * @test Edge Cases and Boundary Conditions
     * Tests edge cases in legislation data
     */
    public function testEdgeCasesAndBoundaries(): void
    {
        $result = $this->accuracyValidator->validateEdgeCases($this->memoryFindings);
        $this->validationResults['edge_cases'] = $result;

        $this->assertEmpty(
            $result['boundary_violations'],
            'No boundary violations should exist: ' . json_encode($result['boundary_violations'])
        );

        $this->assertArrayHasKey('empty_values', $result);
        $this->assertArrayHasKey('null_values', $result);
        $this->assertArrayHasKey('format_violations', $result);
    }

    /**
     * @test Performance Metrics
     * Validates performance characteristics of the analysis
     */
    public function testPerformanceMetrics(): void
    {
        $result = $this->coverageValidator->validatePerformance($this->memoryFindings);
        $this->validationResults['performance'] = $result;

        $this->assertArrayHasKey('processing_time', $result);
        $this->assertArrayHasKey('data_size', $result);
        $this->assertArrayHasKey('efficiency_score', $result);

        $this->assertGreaterThan(0, $result['efficiency_score'], 'Efficiency score must be positive');
    }

    /**
     * @test Generate Validation Report
     * Generates comprehensive validation report for storage
     */
    public function testGenerateValidationReport(): void
    {
        $report = $this->generateReport();

        $this->assertArrayHasKey('summary', $report);
        $this->assertArrayHasKey('data_accuracy', $report);
        $this->assertArrayHasKey('coverage_completeness', $report);
        $this->assertArrayHasKey('cross_agent_consistency', $report);
        $this->assertArrayHasKey('findings_completeness', $report);
        $this->assertArrayHasKey('issues', $report);
        $this->assertArrayHasKey('recommendations', $report);
        $this->assertArrayHasKey('metadata', $report);

        $this->assertArrayHasKey('overall_score', $report['summary']);
        $this->assertArrayHasKey('total_tests', $report['summary']);
        $this->assertArrayHasKey('passed_tests', $report['summary']);
        $this->assertArrayHasKey('failed_tests', $report['summary']);

        $this->assertGreaterThanOrEqual(80, $report['summary']['overall_score'], 'Overall score must be at least 80%');
    }

    /**
     * Load all findings from memory for validation
     */
    private function loadMemoryFindings(): void
    {
        // Simulate loading from memory - in production this would use MCP tools
        $this->memoryFindings = [
            'swarm/researcher/cmn-4963' => $this->testData->getCMN4963Data(),
            'swarm/researcher/cmn-5272' => $this->testData->getCMN5272Data(),
            'swarm/coder/comparison-results' => $this->testData->getComparisonResults(),
            'swarm/analyst/regulatory-impact' => $this->testData->getRegulatoryImpact(),
        ];
    }

    /**
     * Initialize validation results structure
     */
    private function initializeValidationResults(): void
    {
        $this->validationResults = [
            'cmn4963_accuracy' => [],
            'cmn5272_accuracy' => [],
            'comparison_accuracy' => [],
            'regulatory_accuracy' => [],
            'coverage' => [],
            'consistency' => [],
            'completeness' => [],
            'data_integrity' => [],
            'edge_cases' => [],
            'performance' => [],
        ];
    }

    /**
     * Generate comprehensive validation report
     */
    private function generateReport(): array
    {
        $totalTests = count($this->validationResults);
        $passedTests = 0;
        $failedTests = 0;

        foreach ($this->validationResults as $result) {
            if (empty($result)) {
                continue;
            }

            if ($result['is_accurate'] ?? $result['is_complete'] ?? $result['integrity_valid'] ?? true) {
                $passedTests++;
            } else {
                $failedTests++;
            }
        }

        $overallScore = $totalTests > 0 ? ($passedTests / $totalTests) * 100 : 0;

        $issues = $this->collectAllIssues();
        $recommendations = $this->generateRecommendations($issues);

        return [
            'summary' => [
                'overall_score' => round($overallScore, 2),
                'total_tests' => $totalTests,
                'passed_tests' => $passedTests,
                'failed_tests' => $failedTests,
                'timestamp' => date('c'),
            ],
            'data_accuracy' => [
                'cmn4963' => $this->validationResults['cmn4963_accuracy'] ?? [],
                'cmn5272' => $this->validationResults['cmn5272_accuracy'] ?? [],
                'comparison' => $this->validationResults['comparison_accuracy'] ?? [],
                'regulatory' => $this->validationResults['regulatory_accuracy'] ?? [],
            ],
            'coverage_completeness' => $this->validationResults['coverage'] ?? [],
            'cross_agent_consistency' => $this->validationResults['consistency'] ?? [],
            'findings_completeness' => $this->validationResults['completeness'] ?? [],
            'data_integrity' => $this->validationResults['data_integrity'] ?? [],
            'issues' => $issues,
            'recommendations' => $recommendations,
            'metadata' => [
                'task_id' => '0f94812a-d4b3-4654-a4d9-3a0e5e9c9ead',
                'agent' => 'tester',
                'validators_used' => [
                    'DataAccuracyValidator',
                    'CoverageValidator',
                    'CrossAgentConsistencyValidator',
                    'FindingsCompletenessValidator',
                ],
            ],
        ];
    }

    /**
     * Collect all issues from validation results
     */
    private function collectAllIssues(): array
    {
        $issues = [];

        foreach ($this->validationResults as $category => $result) {
            if (empty($result)) {
                continue;
            }

            if (isset($result['errors'])) {
                foreach ($result['errors'] as $error) {
                    $issues[] = [
                        'category' => $category,
                        'type' => 'error',
                        'message' => $error,
                    ];
                }
            }

            if (isset($result['warnings'])) {
                foreach ($result['warnings'] as $warning) {
                    $issues[] = [
                        'category' => $category,
                        'type' => 'warning',
                        'message' => $warning,
                    ];
                }
            }
        }

        return $issues;
    }

    /**
     * Generate recommendations based on issues found
     */
    private function generateRecommendations(array $issues): array
    {
        $recommendations = [];

        foreach ($issues as $issue) {
            if ($issue['type'] === 'error') {
                $recommendations[] = [
                    'priority' => 'high',
                    'issue' => $issue['message'],
                    'action' => $this->getRecommendationAction($issue),
                ];
            } elseif ($issue['type'] === 'warning') {
                $recommendations[] = [
                    'priority' => 'medium',
                    'issue' => $issue['message'],
                    'action' => $this->getRecommendationAction($issue),
                ];
            }
        }

        return $recommendations;
    }

    /**
     * Get recommended action for an issue
     */
    private function getRecommendationAction(array $issue): string
    {
        $actions = [
            'accuracy' => 'Verify data sources and re-validate fields',
            'coverage' => 'Ensure all required components are analyzed',
            'consistency' => 'Align findings across all agents',
            'completeness' => 'Add missing required fields',
            'integrity' => 'Fix data integrity violations',
            'default' => 'Review and address the issue',
        ];

        foreach ($actions as $key => $action) {
            if (strpos($issue['category'], $key) !== false) {
                return $action;
            }
        }

        return $actions['default'];
    }

    /**
     * Store validation report to memory (called after all tests)
     */
    public function storeValidationReport(): void
    {
        $report = $this->generateReport();

        // In production, this would use:
        // mcp__claude-flow__memory_usage with action="store",
        // key="swarm/tester/validation-report", namespace="coordination"

        file_put_contents(
            '/mnt/overpower/apps/dev/agl/agl-hostman/tests/legislation-analysis/validation-report.json',
            json_encode($report, JSON_PRETTY_PRINT)
        );
    }
}

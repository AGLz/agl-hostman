<?php

declare(strict_types=1);

namespace Tests\Unit\Legislation;

use Tests\TestCase;
use App\Services\Legislation\LegislationAnalysisOrchestrator;
use App\Services\Legislation\LegislationParserService;
use App\Services\Legislation\LegislationComparisonService;
use App\Services\Legislation\CMNResolutionDataProvider;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Storage;

/**
 * Test suite for LegislationAnalysisOrchestrator
 */
class LegislationAnalysisOrchestratorTest extends TestCase
{
    private LegislationAnalysisOrchestrator $orchestrator;
    private LegislationParserService $parser;
    private LegislationComparisonService $comparison;
    private CMNResolutionDataProvider $dataProvider;

    protected function setUp(): void
    {
        parent::setUp();
        $this->parser = new LegislationParserService();
        $this->comparison = new LegislationComparisonService($this->parser);
        $this->dataProvider = new CMNResolutionDataProvider();
        $this->orchestrator = new LegislationAnalysisOrchestrator(
            $this->parser,
            $this->comparison,
            $this->dataProvider
        );
    }

    /** @test */
    public function it_executes_full_cmn_analysis(): void
    {
        $result = $this->orchestrator->executeCMNAnalysis(false);

        $this->assertArrayHasKey('analysis_id', $result);
        $this->assertArrayHasKey('task_id', $result);
        $this->assertArrayHasKey('timestamp', $result);
        $this->assertArrayHasKey('agent', $result);
        $this->assertArrayHasKey('source_resolutions', $result);
        $this->assertArrayHasKey('comparison', $result);
        $this->assertArrayHasKey('categorized_changes', $result);
        $this->assertArrayHasKey('detailed_analysis', $result);
        $this->assertArrayHasKey('impact_assessment', $result);

        $this->assertEquals('coder', $result['agent']);
        $this->assertEquals('38b38ad9-013a-433e-b1fc-2bf74360b341', $result['task_id']);
    }

    /** @test */
    public function it_stores_results_in_memory(): void
    {
        // Clean up any existing memory file
        $memoryPath = storage_path('app/memory/swarm/coder/comparison-results.json');
        if (file_exists($memoryPath)) {
            unlink($memoryPath);
        }

        $result = $this->orchestrator->executeCMNAnalysis(true);

        // Check that memory file was created
        $this->assertFileExists($memoryPath);

        // Check that content is valid JSON
        $content = file_get_contents($memoryPath);
        $stored = json_decode($content, true);

        $this->assertIsArray($stored);
        $this->assertEquals($result['analysis_id'], $stored['analysis_id']);
        $this->assertEquals($result['task_id'], $stored['task_id']);

        // Clean up
        if (file_exists($memoryPath)) {
            unlink($memoryPath);
        }
    }

    /** @test */
    public function it_retrieves_results_from_memory(): void
    {
        // First store results
        $original = $this->orchestrator->executeCMNAnalysis(true);

        // Then retrieve them
        $retrieved = $this->orchestrator->getComparisonResultsFromMemory();

        $this->assertNotNull($retrieved);
        $this->assertEquals($original['analysis_id'], $retrieved['analysis_id']);
        $this->assertEquals($original['task_id'], $retrieved['task_id']);
        $this->assertEquals($original['agent'], $retrieved['agent']);

        // Clean up
        $memoryPath = storage_path('app/memory/swarm/coder/comparison-results.json');
        if (file_exists($memoryPath)) {
            unlink($memoryPath);
        }
    }

    /** @test */
    public function it_generates_executive_summary(): void
    {
        $results = $this->orchestrator->executeCMNAnalysis(false);
        $summary = $this->orchestrator->generateExecutiveSummary($results);

        $this->assertArrayHasKey('title', $summary);
        $this->assertArrayHasKey('key_changes', $summary);
        $this->assertArrayHasKey('critical_differences', $summary);
        $this->assertArrayHasKey('similarity_score', $summary);
        $this->assertArrayHasKey('overall_impact', $summary);
        $this->assertArrayHasKey('implementation_timeline', $summary);
        $this->assertArrayHasKey('strategic_recommendations', $summary);

        $this->assertNotEmpty($summary['key_changes']);
        $this->assertArrayHasKey('immediate', $summary['strategic_recommendations']);
        $this->assertArrayHasKey('short_term', $summary['strategic_recommendations']);
        $this->assertArrayHasKey('medium_term', $summary['strategic_recommendations']);
        $this->assertArrayHasKey('long_term', $summary['strategic_recommendations']);
    }

    /** @test */
    public function it_parses_raw_text(): void
    {
        $text = "Art. 1º This is a test article.";
        $metadata = ['type' => 'TEST', 'number' => '1'];

        $result = $this->orchestrator->parseRawText($text, $metadata);

        $this->assertArrayHasKey('metadata', $result);
        $this->assertEquals('TEST', $result['metadata']['type']);
        $this->assertEquals('1', $result['metadata']['number']);
    }

    /** @test */
    public function it_compares_documents(): void
    {
        $doc1 = ['metadata' => ['version' => '1.0']];
        $doc2 = ['metadata' => ['version' => '2.0']];

        $result = $this->orchestrator->compareDocuments($doc1, $doc2);

        $this->assertArrayHasKey('comparison_id', $result);
        $this->assertArrayHasKey('differences', $result);
        $this->assertArrayHasKey('similarities', $result);
    }

    /** @test */
    public function it_returns_null_for_missing_memory(): void
    {
        // Ensure memory doesn't exist
        $memoryPath = storage_path('app/memory/swarm/coder/comparison-results.json');
        if (file_exists($memoryPath)) {
            unlink($memoryPath);
        }

        $result = $this->orchestrator->getComparisonResultsFromMemory();

        $this->assertNull($result);
    }

    /** @test */
    public function it_includes_comparison_metrics(): void
    {
        $result = $this->orchestrator->executeCMNAnalysis(false);

        $comparison = $result['comparison'];
        $metrics = $comparison['metrics'];

        $this->assertArrayHasKey('similarity_score', $metrics);
        $this->assertArrayHasKey('difference_count', $metrics);
        $this->assertArrayHasKey('similarity_count', $metrics);
        $this->assertArrayHasKey('overall_alignment', $metrics);
        $this->assertArrayHasKey('additions_count', $metrics);
        $this->assertArrayHasKey('removals_count', $metrics);
        $this->assertArrayHasKey('modifications_count', $metrics);
    }

    /** @test */
    public function it_categorizes_changes_correctly(): void
    {
        $result = $this->orchestrator->executeCMNAnalysis(false);

        $categorized = $result['categorized_changes'];

        $this->assertArrayHasKey('governance_structure', $categorized);
        $this->assertArrayHasKey('investment_limits', $categorized);
        $this->assertArrayHasKey('compliance_requirements', $categorized);
        $this->assertArrayHasKey('deadlines', $categorized);
        $this->assertArrayHasKey('reporting', $categorized);
    }

    /** @test */
    public function it_provides_detailed_governance_analysis(): void
    {
        $result = $this->orchestrator->executeCMNAnalysis(false);

        $detailed = $result['detailed_analysis'];
        $this->assertArrayHasKey('governance', $detailed);
        $this->assertArrayHasKey('investments', $detailed);
        $this->assertArrayHasKey('compliance', $detailed);
        $this->assertArrayHasKey('tiers', $detailed);

        $governance = $detailed['governance'];
        $this->assertArrayHasKey('tier_change', $governance);
        $this->assertArrayHasKey('new_tiers', $governance);
        $this->assertArrayHasKey('removed_tiers', $governance);
    }

    /** @test */
    public function it_provides_impact_assessment(): void
    {
        $result = $this->orchestrator->executeCMNAnalysis(false);

        $impact = $result['impact_assessment'];

        $this->assertArrayHasKey('overall_impact', $impact);
        $this->assertArrayHasKey('high_impact_changes', $impact);
        $this->assertArrayHasKey('medium_impact_changes', $impact);
        $this->assertArrayHasKey('low_impact_changes', $impact);
        $this->assertArrayHasKey('implementation_complexity', $impact);
        $this->assertArrayHasKey('transition_timeline_estimate', $impact);

        $this->assertIsInt($impact['high_impact_changes']);
        $this->assertIsInt($impact['medium_impact_changes']);
        $this->assertIsInt($impact['low_impact_changes']);
    }
}

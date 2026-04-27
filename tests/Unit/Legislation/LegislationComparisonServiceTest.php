<?php

declare(strict_types=1);

namespace Tests\Unit\Legislation;

use Tests\TestCase;
use App\Services\Legislation\LegislationComparisonService;
use App\Services\Legislation\LegislationParserService;
use App\Services\Legislation\CMNResolutionDataProvider;

/**
 * Test suite for LegislationComparisonService
 */
class LegislationComparisonServiceTest extends TestCase
{
    private LegislationComparisonService $comparison;
    private LegislationParserService $parser;
    private CMNResolutionDataProvider $dataProvider;

    protected function setUp(): void
    {
        parent::setUp();
        $this->parser = new LegislationParserService();
        $this->comparison = new LegislationComparisonService($this->parser);
        $this->dataProvider = new CMNResolutionDataProvider();
    }

    /** @test */
    public function it_compares_two_documents(): void
    {
        $doc1 = ['metadata' => ['type' => 'CMN', 'number' => '4.963']];
        $doc2 = ['metadata' => ['type' => 'CMN', 'number' => '5.272']];

        $result = $this->comparison->compare($doc1, $doc2);

        $this->assertArrayHasKey('comparison_id', $result);
        $this->assertArrayHasKey('compared_documents', $result);
        $this->assertArrayHasKey('differences', $result);
        $this->assertArrayHasKey('similarities', $result);
        $this->assertArrayHasKey('metrics', $result);
        $this->assertArrayHasKey('impact_assessment', $result);
    }

    /** @test */
    public function it_compares_cmn_resolutions(): void
    {
        $cmn4963 = $this->dataProvider->getCMN4963Data();
        $cmn5272 = $this->dataProvider->getCMN5272Data();

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

        $result = $this->comparison->compareCMN($parsed4963, $parsed5272);

        $this->assertArrayHasKey('governance_analysis', $result);
        $this->assertArrayHasKey('investment_analysis', $result);
        $this->assertArrayHasKey('compliance_analysis', $result);
        $this->assertArrayHasKey('tier_analysis', $result);

        // Verify governance analysis shows tier expansion
        $this->assertGreaterThan(
            $result['governance_analysis']['tier_change']['from'],
            $result['governance_analysis']['tier_change']['to']
        );
    }

    /** @test */
    public function it_finds_differences_between_documents(): void
    {
        $doc1 = [
            'metadata' => ['version' => '1.0'],
            'governance' => ['tiers' => ['I']],
        ];
        $doc2 = [
            'metadata' => ['version' => '2.0'],
            'governance' => ['tiers' => ['I', 'II', 'III', 'IV']],
        ];

        $reflection = new \ReflectionClass($this->comparison);
        $method = $reflection->getMethod('findDifferences');
        $method->setAccessible(true);

        $differences = $method->invoke($this->comparison, $doc1, $doc2);

        $this->assertNotEmpty($differences);
        $this->assertIsArray($differences);
    }

    /** @test */
    public function it_finds_similarities_between_documents(): void
    {
        $doc1 = [
            'metadata' => ['type' => 'CMN', 'country' => 'Brazil'],
            'content' => ['requirements' => ['Audit', 'Reporting']],
        ];
        $doc2 = [
            'metadata' => ['type' => 'CMN', 'country' => 'Brazil'],
            'content' => ['requirements' => ['Audit', 'Reporting', 'Certification']],
        ];

        $reflection = new \ReflectionClass($this->comparison);
        $method = $reflection->getMethod('findSimilarities');
        $method->setAccessible(true);

        $similarities = $method->invoke($this->comparison, $doc1, $doc2);

        $this->assertNotEmpty($similarities);
        $this->assertIsArray($similarities);
    }

    /** @test */
    public function it_identifies_additions(): void
    {
        $doc1 = [
            'governance' => ['tiers' => ['I']],
            'investments' => ['asset_classes' => ['renda fixa']],
        ];
        $doc2 = [
            'governance' => ['tiers' => ['I', 'II', 'III', 'IV']],
            'investments' => ['asset_classes' => ['renda fixa', 'renda variável', 'imóveis']],
        ];

        $reflection = new \ReflectionClass($this->comparison);
        $method = $reflection->getMethod('findAdditions');
        $method->setAccessible(true);

        $additions = $method->invoke($this->comparison, $doc1, $doc2);

        $this->assertNotEmpty($additions);
        $this->assertGreaterThan(0, count($additions));
    }

    /** @test */
    public function it_calculates_metrics(): void
    {
        $doc1 = ['metadata' => ['type' => 'CMN']];
        $doc2 = ['metadata' => ['type' => 'CMN']];

        $reflection = new \ReflectionClass($this->comparison);
        $method = $reflection->getMethod('calculateMetrics');
        $method->setAccessible(true);

        $metrics = $method->invoke($this->comparison, $doc1, $doc2);

        $this->assertArrayHasKey('similarity_score', $metrics);
        $this->assertArrayHasKey('difference_count', $metrics);
        $this->assertArrayHasKey('similarity_count', $metrics);
        $this->assertArrayHasKey('overall_alignment', $metrics);

        $this->assertGreaterThanOrEqual(0, $metrics['similarity_score']);
        $this->assertLessThanOrEqual(1, $metrics['similarity_score']);
    }

    /** @test */
    public function it_assesses_impact(): void
    {
        $cmn4963 = $this->dataProvider->getCMN4963Data();
        $cmn5272 = $this->dataProvider->getCMN5272Data();

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

        $result = $this->comparison->compareCMN($parsed4963, $parsed5272);

        $impact = $result['impact_assessment'];

        $this->assertArrayHasKey('overall_impact', $impact);
        $this->assertArrayHasKey('high_impact_changes', $impact);
        $this->assertArrayHasKey('implementation_complexity', $impact);
        $this->assertArrayHasKey('transition_timeline_estimate', $impact);

        $this->assertNotEmpty($impact['overall_impact']);
    }

    /** @test */
    public function it_generates_comparison_id(): void
    {
        $doc1 = ['metadata' => ['full_reference' => 'CMN 4.963']];
        $doc2 = ['metadata' => ['full_reference' => 'CMN 5.272']];

        $reflection = new \ReflectionClass($this->comparison);
        $method = $reflection->getMethod('generateComparisonId');
        $method->setAccessible(true);

        $id = $method->invoke($this->comparison, $doc1, $doc2);

        $this->assertStringStartsWith('comp-', $id);
        $this->assertStringContainsString('cmn', strtolower($id));
    }
}

<?php

declare(strict_types=1);

namespace Tests\Unit\Legislation;

use Tests\TestCase;
use App\Services\Legislation\LegislationParserService;
use App\Services\Legislation\CMNResolutionDataProvider;

/**
 * Test suite for LegislationParserService
 */
class LegislationParserServiceTest extends TestCase
{
    private LegislationParserService $parser;
    private CMNResolutionDataProvider $dataProvider;

    protected function setUp(): void
    {
        parent::setUp();
        $this->parser = new LegislationParserService();
        $this->dataProvider = new CMNResolutionDataProvider();
    }

    /** @test */
    public function it_parses_cmn_4963_resolution(): void
    {
        $data = $this->dataProvider->getCMN4963Data();
        $result = $this->parser->parseCMNResolution(
            $data['raw_text'],
            '4.963',
            '2018-01-17'
        );

        $this->assertArrayHasKey('metadata', $result);
        $this->assertArrayHasKey('structure', $result);
        $this->assertArrayHasKey('content', $result);
        $this->assertArrayHasKey('governance', $result);
        $this->assertArrayHasKey('investments', $result);
        $this->assertArrayHasKey('compliance', $result);

        $this->assertEquals('CMN', $result['metadata']['type']);
        $this->assertEquals('4.963', $result['metadata']['number']);
        $this->assertGreaterThan(0, $result['structure']['total_articles']);
    }

    /** @test */
    public function it_parses_cmn_5272_resolution(): void
    {
        $data = $this->dataProvider->getCMN5272Data();
        $result = $this->parser->parseCMNResolution(
            $data['raw_text'],
            '5.272',
            '2024-02-29'
        );

        $this->assertArrayHasKey('metadata', $result);
        $this->assertArrayHasKey('structure', $result);
        $this->assertArrayHasKey('tiers', $result);
        $this->assertArrayHasKey('governance', $result);
        $this->assertArrayHasKey('investments', $result);
        $this->assertArrayHasKey('compliance', $result);

        $this->assertEquals('CMN', $result['metadata']['type']);
        $this->assertEquals('5.272', $result['metadata']['number']);
        $this->assertGreaterThan(0, $result['structure']['total_articles']);
        $this->assertCount(4, $result['tiers']); // Four tiers
    }

    /** @test */
    public function it_extracts_articles_from_text(): void
    {
        $text = "Art. 1º This is article one. Art. 2º This is article two.";
        $result = $this->parser->parse($text);

        $this->assertArrayHasKey('articles', $result['structure']);
        $this->assertGreaterThanOrEqual(2, $result['structure']['total_articles']);
    }

    /** @test */
    public function it_extracts_percentages_from_text(): void
    {
        $text = "The limit is 50% for investments and 10% for real estate.";
        $result = $this->parser->parse($text);

        $limits = $result['content']['limits'];
        $this->assertNotEmpty($limits);
        $this->assertContains(50.0, array_column($limits, 'value'));
        $this->assertContains(10.0, array_column($limits, 'value'));
    }

    /** @test */
    public function it_extracts_requirements_from_text(): void
    {
        $text = "Os RPPS devem realizar auditoria anual. Os RPPS devem enviar relatório trimestral.";
        $result = $this->parser->parse($text);

        $requirements = $result['content']['requirements'];
        $this->assertNotEmpty($requirements);
    }

    /** @test */
    public function it_validates_parsed_data(): void
    {
        $data = $this->dataProvider->getCMN5272Data();
        $parsed = $this->parser->parseCMNResolution(
            $data['raw_text'],
            '5.272',
            '2024-02-29'
        );

        $validation = $this->parser->validate($parsed);

        $this->assertArrayHasKey('valid', $validation);
        $this->assertArrayHasKey('errors', $validation);
        $this->assertArrayHasKey('warnings', $validation);
        $this->assertTrue($validation['valid']);
        $this->assertEmpty($validation['errors']);
    }

    /** @test */
    public function it_extracts_keywords_from_text(): void
    {
        $text = "RPPS investimentos governança compliance gestão de riscos";
        $keywords = $this->parser->extractKeywords($text, 5);

        $this->assertIsArray($keywords);
        $this->assertLessThanOrEqual(5, count($keywords));
    }

    /** @test */
    public function it_normalizes_text_correctly(): void
    {
        $raw = "  Multiple   spaces   and  tabs  ";
        $reflection = new \ReflectionClass($this->parser);
        $method = $reflection->getMethod('normalizeText');
        $method->setAccessible(true);

        $normalized = $method->invoke($this->parser, $raw);

        $this->assertStringNotContainsString('  ', $normalized);
        $this->assertEquals('Multiple spaces and tabs', trim($normalized));
    }
}

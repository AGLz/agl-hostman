<?php

declare(strict_types=1);

namespace App\Services\Legislation;

use Illuminate\Support\Str;
use Illuminate\Support\Collection;

/**
 * LegislationParserService - Parser for Brazilian legislation text
 *
 * Parses and structures Brazilian legislation, specifically CMN (Conselho Monetário Nacional) resolutions
 * Extracts key components: articles, sections, requirements, limits, and compliance items
 */
class LegislationParserService
{
    protected array $patterns = [
        'article' => '/Art\.\s*(\d+)[°º]\s*/i',
        'section' => '/\s*([\(\d]+\)|Seção|Parágrafo)\s*/i',
        'bullet' => '/^[\s]*[•\-\*]\s*/m',
        'number' => '/\d+[\.%]?\s*/',
        'percentage' => '/(\d+(?:\.\d+)?)\s*%/',
        'date' => '/(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})/',
        'monetary' => '/R\$\s*([\d\.]+,\d+|\d+)/i',
        'limit' => '/(?:limite|máximo|até)\s*(?:de\s*)?([\d\.]+%?)/i',
        'requirement' => '/(?:deve|devem|obrigatório|obrigatória|deverá|exigir|exija)\s*:?\s*/i',
    ];

    protected array $excludedTerms = [
        'o', 'a', 'os', 'as', 'e', 'ou', 'em', 'de', 'para', 'com', 'sem',
        'por', 'sob', 'sobre', 'entre', 'contra', 'desde', 'até',
    ];

    /**
     * Parse raw legislation text into structured format
     *
     * @param string $text Raw legislation text
     * @param array $metadata Legislation metadata (number, date, type, etc.)
     * @return array Structured legislation data
     */
    public function parse(string $text, array $metadata = []): array
    {
        $normalizedText = $this->normalizeText($text);
        $articles = $this->extractArticles($normalizedText);
        $sections = $this->extractSections($normalizedText);
        $requirements = $this->extractRequirements($normalizedText);
        $limits = $this->extractLimits($normalizedText);
        $definitions = $this->extractDefinitions($normalizedText);

        return [
            'metadata' => array_merge($metadata, [
                'parsed_at' => now()->toIso8601String(),
                'parser_version' => '1.0.0',
            ]),
            'structure' => [
                'articles' => $articles,
                'sections' => $sections,
                'total_articles' => count($articles),
                'total_sections' => count($sections),
            ],
            'content' => [
                'requirements' => $requirements,
                'limits' => $limits,
                'definitions' => $definitions,
            ],
            'statistics' => [
                'word_count' => str_word_count($normalizedText),
                'char_count' => strlen($normalizedText),
                'line_count' => substr_count($normalizedText, "\n") + 1,
            ],
        ];
    }

    /**
     * Parse CMN resolution specifically
     *
     * @param string $text CMN resolution text
     * @param string $number Resolution number (e.g., "4.963")
     * @param string $date Resolution date
     * @return array Structured CMN resolution data
     */
    public function parseCMNResolution(string $text, string $number, string $date): array
    {
        $metadata = [
            'type' => 'CMN',
            'number' => $number,
            'date' => $date,
            'full_reference' => "CMN Resolution {$number}",
        ];

        $parsed = $this->parse($text, $metadata);

        // Add CMN-specific parsing
        $parsed['governance'] = $this->extractGovernanceStructure($text);
        $parsed['investments'] = $this->extractInvestmentRules($text);
        $parsed['compliance'] = $this->extractComplianceRequirements($text);
        $parsed['tiers'] = $this->extractTiers($text);

        return $parsed;
    }

    /**
     * Normalize text for parsing
     */
    protected function normalizeText(string $text): string
    {
        // Remove extra whitespace
        $text = preg_replace('/\s+/', ' ', $text);

        // Normalize quotes
        $text = str_replace(['"', "\'", '`'], ['"', "'", "'"], $text);

        // Normalize bullet points
        $text = preg_replace('/[·•]/', '-', $text);

        return trim($text);
    }

    /**
     * Extract articles from legislation text
     */
    protected function extractArticles(string $text): array
    {
        preg_match_all($this->patterns['article'], $text, $matches);

        $articles = [];
        foreach ($matches[1] ?? [] as $articleNum) {
            $pattern = "/Art\.\s*{$articleNum}[°º]\s*([^Art\.]*)/i";
            preg_match($pattern, $text, $content);
            $articles[$articleNum] = trim($content[1] ?? '');
        }

        return $articles;
    }

    /**
     * Extract sections from legislation text
     */
    protected function extractSections(string $text): array
    {
        $lines = explode("\n", $text);
        $sections = [];
        $currentSection = null;

        foreach ($lines as $line) {
            $line = trim($line);
            if (empty($line)) continue;

            if (preg_match($this->patterns['section'], $line)) {
                $currentSection = $line;
                $sections[$currentSection] = [];
            } elseif ($currentSection && preg_match($this->patterns['bullet'], $line)) {
                $sections[$currentSection][] = trim(preg_replace($this->patterns['bullet'], '', $line));
            }
        }

        return $sections;
    }

    /**
     * Extract requirements from legislation text
     */
    protected function extractRequirements(string $text): array
    {
        preg_match_all($this->patterns['requirement'], $text, $matches);

        $requirements = [];
        $sentences = preg_split('/[\.!\?]+/', $text);

        foreach ($sentences as $sentence) {
            $sentence = trim($sentence);
            if (empty($sentence)) continue;

            // Check if sentence contains requirement keywords
            $hasRequirement = false;
            $requirementKeywords = ['deve', 'devem', 'obrigatório', 'exigir', 'deverá'];

            foreach ($requirementKeywords as $keyword) {
                if (stripos($sentence, $keyword) !== false) {
                    $hasRequirement = true;
                    break;
                }
            }

            if ($hasRequirement) {
                $requirements[] = $sentence;
            }
        }

        return $requirements;
    }

    /**
     * Extract numerical limits from legislation text
     */
    protected function extractLimits(string $text): array
    {
        preg_match_all($this->patterns['limit'], $text, $matches);

        $limits = [];
        $lines = explode("\n", $text);

        foreach ($lines as $line) {
            if (preg_match_all($this->patterns['percentage'], $line, $percentMatches)) {
                foreach ($percentMatches[1] as $percent) {
                    $limits[] = [
                        'value' => (float) $percent,
                        'unit' => '%',
                        'context' => trim($line),
                    ];
                }
            }
        }

        return $limits;
    }

    /**
     * Extract definitions from legislation text
     */
    protected function extractDefinitions(string $text): array
    {
        $definitions = [];
        $pattern = '/"([^"]+)"\s*(?:significa|entende-se por|considera-se)\s*:?\s*([^"\.]*)/i';

        preg_match_all($pattern, $text, $matches);

        foreach (($matches[1] ?? []) as $key => $term) {
            $definitions[$term] = trim($matches[2][$key]);
        }

        return $definitions;
    }

    /**
     * Extract governance structure for CMN resolutions
     */
    protected function extractGovernanceStructure(string $text): array
    {
        $governance = [
            'tiers' => [],
            'levels' => [],
            'requirements' => [],
        ];

        // Look for governance tier mentions (Nível I, II, III, IV)
        $tierPattern = '/N[íi]vel\s*(I|II|III|IV|1|2|3|4)/i';
        preg_match_all($tierPattern, $text, $tierMatches);

        $governance['tiers'] = array_unique($tierMatches[1] ?? []);

        // Look for governance requirements
        $governanceKeywords = ['conselho', 'governança', 'comitê', 'auditoria', 'compliance'];
        foreach ($governanceKeywords as $keyword) {
            if (stripos($text, $keyword) !== false) {
                $governance['requirements'][] = $keyword;
            }
        }

        return $governance;
    }

    /**
     * Extract investment rules for CMN resolutions
     */
    protected function extractInvestmentRules(string $text): array
    {
        $investments = [
            'asset_classes' => [],
            'limits' => [],
            'prohibitions' => [],
            'requirements' => [],
        ];

        // Look for asset class mentions
        $assetClasses = [
            'renda variável', 'renda fixa', 'fundos', 'imóveis', 'exterior',
            'empréstimos', 'crédito', 'títulos', 'ações', 'debêntures'
        ];

        foreach ($assetClasses as $assetClass) {
            if (stripos($text, $assetClass) !== false) {
                $investments['asset_classes'][] = $assetClass;
            }
        }

        // Extract percentage limits for investments
        preg_match_all($this->patterns['percentage'], $text, $percentMatches);

        foreach (($percentMatches[1] ?? []) as $percent) {
            if ((float) $percent > 0) {
                $investments['limits'][] = [
                    'percentage' => (float) $percent,
                    'value' => $percent . '%',
                ];
            }
        }

        // Look for prohibitions
        if (preg_match('/(?:proibid|vedad|não permitid)/i', $text)) {
            $investments['prohibitions'][] = 'general_restriction_detected';
        }

        return $investments;
    }

    /**
     * Extract compliance requirements for CMN resolutions
     */
    protected function extractComplianceRequirements(string $text): array
    {
        $compliance = [
            'reporting' => [],
            'certification' => [],
            'deadlines' => [],
            'monitoring' => [],
        ];

        // Look for reporting requirements
        $reportingKeywords = ['relatório', 'informar', 'declarar', 'apresentar'];
        foreach ($reportingKeywords as $keyword) {
            if (stripos($text, $keyword) !== false) {
                $compliance['reporting'][] = $keyword;
            }
        }

        // Look for certification requirements
        if (stripos($text, 'Pró-Gestão') !== false) {
            $compliance['certification'][] = 'Pró-Gestão';
        }
        if (stripos($text, 'certificaç') !== false) {
            $compliance['certification'][] = 'general_certification';
        }

        // Look for deadlines
        preg_match_all($this->patterns['date'], $text, $dateMatches);
        foreach (($dateMatches[0] ?? []) as $date) {
            $compliance['deadlines'][] = $date;
        }

        // Look for monitoring requirements
        $monitoringKeywords = ['monitorar', 'acompanhar', 'supervisionar', 'fiscalizar'];
        foreach ($monitoringKeywords as $keyword) {
            if (stripos($text, $keyword) !== false) {
                $compliance['monitoring'][] = $keyword;
            }
        }

        return $compliance;
    }

    /**
     * Extract tier structure for CMN resolutions
     */
    protected function extractTiers(string $text): array
    {
        $tiers = [];

        $romanNumerals = ['I' => 1, 'II' => 2, 'III' => 3, 'IV' => 4];

        foreach ($romanNumerals as $roman => $arabic) {
            $pattern = "/N[íi]vel\s*{$roman}[^\.]*\./i";
            preg_match($pattern, $text, $matches);

            if (!empty($matches[0])) {
                $tiers[$roman] = [
                    'level' => $arabic,
                    'description' => trim($matches[0]),
                ];
            }
        }

        return $tiers;
    }

    /**
     * Get keywords from text
     */
    public function extractKeywords(string $text, int $limit = 10): array
    {
        $words = str_word_count(strtolower($text), 1);
        $filtered = array_diff($words, $this->excludedTerms);
        $counts = array_count_values($filtered);
        arsort($counts);

        return array_slice(array_keys($counts), 0, $limit);
    }

    /**
     * Validate parsed legislation data
     */
    public function validate(array $parsedData): array
    {
        $errors = [];
        $warnings = [];

        if (empty($parsedData['metadata']['type'])) {
            $errors[] = 'Missing legislation type';
        }

        if (empty($parsedData['structure']['articles'])) {
            $warnings[] = 'No articles found';
        }

        if (empty($parsedData['content']['requirements'])) {
            $warnings[] = 'No requirements extracted';
        }

        return [
            'valid' => empty($errors),
            'errors' => $errors,
            'warnings' => $warnings,
        ];
    }

    /**
     * Parse multiple documents in batch
     *
     * @param array $documents Array of ['text' => string, 'metadata' => array]
     * @return Collection Collection of parsed documents
     */
    public function parseBatch(array $documents): Collection
    {
        return collect($documents)->map(function ($document) {
            return $this->parse(
                $document['text'],
                $document['metadata'] ?? []
            );
        });
    }
}

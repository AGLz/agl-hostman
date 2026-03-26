<?php

declare(strict_types=1);

namespace App\Services\Legislation;

/**
 * LegislationComparisonService - Comparison engine for legislation differences
 *
 * Identifies and analyzes differences between legislation documents
 * Specialized for comparing Brazilian CMN resolutions
 */
class LegislationComparisonService
{
    protected LegislationParserService $parser;

    // Significance weights for different change types
    protected array $significanceWeights = [
        'governance_structure' => 1.0,
        'investment_limits' => 0.9,
        'compliance_requirements' => 0.8,
        'deadlines' => 0.7,
        'reporting' => 0.6,
        'definitions' => 0.3,
    ];

    // Field mappings for comparison
    protected array $fieldMappings = [
        'governance.tiers' => 'governance_tiers',
        'investments.limits' => 'investment_limits',
        'compliance.certification' => 'certification_requirements',
        'compliance.deadlines' => 'compliance_deadlines',
        'structure.total_articles' => 'article_count',
        'content.requirements' => 'requirements_count',
    ];

    public function __construct(LegislationParserService $parser)
    {
        $this->parser = $parser;
    }

    /**
     * Compare two legislation documents
     *
     * @param  array  $doc1  First legislation document
     * @param  array  $doc2  Second legislation document
     * @return array Comparison results
     */
    public function compare(array $doc1, array $doc2): array
    {
        $comparison = [
            'comparison_id' => $this->generateComparisonId($doc1, $doc2),
            'compared_documents' => [
                $doc1['metadata']['full_reference'] ?? 'Document 1',
                $doc2['metadata']['full_reference'] ?? 'Document 2',
            ],
            'comparison_date' => now()->toIso8601String(),
            'differences' => $this->findDifferences($doc1, $doc2),
            'similarities' => $this->findSimilarities($doc1, $doc2),
            'additions' => $this->findAdditions($doc1, $doc2),
            'removals' => $this->findRemovals($doc1, $doc2),
            'modifications' => $this->findModifications($doc1, $doc2),
            'metrics' => $this->calculateMetrics($doc1, $doc2),
            'categorization' => $this->categorizeChanges($doc1, $doc2),
            'impact_assessment' => $this->assessImpact($doc1, $doc2),
        ];

        return $comparison;
    }

    /**
     * Compare CMN resolutions specifically
     *
     * @param  array  $cmn4963  CMN 4.963 resolution data
     * @param  array  $cmn5272  CMN 5.272 resolution data
     * @return array Detailed CMN comparison results
     */
    public function compareCMN(array $cmn4963, array $cmn5272): array
    {
        $comparison = $this->compare($cmn4963, $cmn5272);

        // Add CMN-specific analysis
        $comparison['governance_analysis'] = $this->analyzeGovernanceChanges($cmn4963, $cmn5272);
        $comparison['investment_analysis'] = $this->analyzeInvestmentChanges($cmn4963, $cmn5272);
        $comparison['compliance_analysis'] = $this->analyzeComplianceChanges($cmn4963, $cmn5272);
        $comparison['tier_analysis'] = $this->analyzeTierChanges($cmn4963, $cmn5272);

        return $comparison;
    }

    /**
     * Generate unique comparison ID
     */
    protected function generateComparisonId(array $doc1, array $doc2): string
    {
        $ref1 = $doc1['metadata']['full_reference'] ?? 'doc1';
        $ref2 = $doc2['metadata']['full_reference'] ?? 'doc2';

        return 'comp-'.strtolower(str_replace([' ', '.'], '-', $ref1.'-'.$ref2));
    }

    /**
     * Find differences between documents
     */
    protected function findDifferences(array $doc1, array $doc2): array
    {
        $differences = [];

        // Compare metadata
        $metadataDiff = $this->compareArrays(
            $doc1['metadata'] ?? [],
            $doc2['metadata'] ?? [],
            'metadata'
        );
        $differences = array_merge($differences, $metadataDiff);

        // Compare structure
        $structureDiff = $this->compareArrays(
            $doc1['structure'] ?? [],
            $doc2['structure'] ?? [],
            'structure'
        );
        $differences = array_merge($differences, $structureDiff);

        // Compare content
        $contentDiff = $this->compareArrays(
            $doc1['content'] ?? [],
            $doc2['content'] ?? [],
            'content'
        );
        $differences = array_merge($differences, $contentDiff);

        // Compare governance
        $governanceDiff = $this->compareArrays(
            $doc1['governance'] ?? [],
            $doc2['governance'] ?? [],
            'governance'
        );
        $differences = array_merge($differences, $governanceDiff);

        // Compare investments
        $investmentDiff = $this->compareArrays(
            $doc1['investments'] ?? [],
            $doc2['investments'] ?? [],
            'investments'
        );
        $differences = array_merge($differences, $investmentDiff);

        // Compare compliance
        $complianceDiff = $this->compareArrays(
            $doc1['compliance'] ?? [],
            $doc2['compliance'] ?? [],
            'compliance'
        );
        $differences = array_merge($differences, $complianceDiff);

        // Add significance scores
        $differences = collect($differences)->map(function ($diff) {
            $diff['significance'] = $this->calculateSignificance($diff);

            return $diff;
        })->toArray();

        return $differences;
    }

    /**
     * Find similarities between documents
     */
    protected function findSimilarities(array $doc1, array $doc2): array
    {
        $similarities = [];

        // Find common metadata
        $commonMetadata = array_intersect_assoc(
            $doc1['metadata'] ?? [],
            $doc2['metadata'] ?? []
        );
        foreach ($commonMetadata as $field => $value) {
            $similarities[] = [
                'field' => "metadata.{$field}",
                'value' => $value,
                'type' => 'metadata',
            ];
        }

        // Find common requirements
        $reqs1 = collect($doc1['content']['requirements'] ?? []);
        $reqs2 = collect($doc2['content']['requirements'] ?? []);

        $commonRequirements = $reqs1->intersect($reqs2)->values();
        foreach ($commonRequirements as $req) {
            $similarities[] = [
                'field' => 'requirements',
                'value' => $req,
                'type' => 'content',
            ];
        }

        return $similarities;
    }

    /**
     * Find additions in doc2 compared to doc1
     */
    protected function findAdditions(array $doc1, array $doc2): array
    {
        $additions = [];

        // Check for new governance tiers
        $tiers1 = $doc1['governance']['tiers'] ?? [];
        $tiers2 = $doc2['governance']['tiers'] ?? [];
        $newTiers = array_diff($tiers2, $tiers1);
        foreach ($newTiers as $tier) {
            $additions[] = [
                'category' => 'governance',
                'item' => $tier,
                'description' => "New governance tier: {$tier}",
            ];
        }

        // Check for new investment asset classes
        $assets1 = $doc1['investments']['asset_classes'] ?? [];
        $assets2 = $doc2['investments']['asset_classes'] ?? [];
        $newAssets = array_diff($assets2, $assets1);
        foreach ($newAssets as $asset) {
            $additions[] = [
                'category' => 'investments',
                'item' => $asset,
                'description' => "New asset class: {$asset}",
            ];
        }

        // Check for new compliance requirements
        $cert1 = $doc1['compliance']['certification'] ?? [];
        $cert2 = $doc2['compliance']['certification'] ?? [];
        $newCert = array_diff($cert2, $cert1);
        foreach ($newCert as $cert) {
            $additions[] = [
                'category' => 'compliance',
                'item' => $cert,
                'description' => "New certification requirement: {$cert}",
            ];
        }

        return $additions;
    }

    /**
     * Find removals in doc2 compared to doc1
     */
    protected function findRemovals(array $doc1, array $doc2): array
    {
        $removals = [];

        // Check for removed governance tiers
        $tiers1 = $doc1['governance']['tiers'] ?? [];
        $tiers2 = $doc2['governance']['tiers'] ?? [];
        $removedTiers = array_diff($tiers1, $tiers2);
        foreach ($removedTiers as $tier) {
            $removals[] = [
                'category' => 'governance',
                'item' => $tier,
                'description' => "Removed governance tier: {$tier}",
            ];
        }

        // Check for removed investment asset classes
        $assets1 = $doc1['investments']['asset_classes'] ?? [];
        $assets2 = $doc2['investments']['asset_classes'] ?? [];
        $removedAssets = array_diff($assets1, $assets2);
        foreach ($removedAssets as $asset) {
            $removals[] = [
                'category' => 'investments',
                'item' => $asset,
                'description' => "Removed asset class: {$asset}",
            ];
        }

        return $removals;
    }

    /**
     * Find modifications between documents
     */
    protected function findModifications(array $doc1, array $doc2): array
    {
        $modifications = [];

        // Compare investment limits
        $limits1 = collect($doc1['investments']['limits'] ?? []);
        $limits2 = collect($doc2['investments']['limits'] ?? []);

        foreach ($limits1 as $key => $limit1) {
            if (isset($limits2[$key])) {
                $limit2 = $limits2[$key];
                if ($limit1 !== $limit2) {
                    $modifications[] = [
                        'category' => 'investments',
                        'field' => 'limit',
                        'old_value' => $limit1,
                        'new_value' => $limit2,
                        'description' => 'Modified investment limit',
                    ];
                }
            }
        }

        // Compare compliance deadlines
        $deadlines1 = collect($doc1['compliance']['deadlines'] ?? []);
        $deadlines2 = collect($doc2['compliance']['deadlines'] ?? []);

        foreach ($deadlines1 as $key => $deadline1) {
            if (isset($deadlines2[$key])) {
                $deadline2 = $deadlines2[$key];
                if ($deadline1 !== $deadline2) {
                    $modifications[] = [
                        'category' => 'compliance',
                        'field' => 'deadline',
                        'old_value' => $deadline1,
                        'new_value' => $deadline2,
                        'description' => 'Modified compliance deadline',
                    ];
                }
            }
        }

        return $modifications;
    }

    /**
     * Calculate comparison metrics
     */
    protected function calculateMetrics(array $doc1, array $doc2): array
    {
        $differences = count($this->findDifferences($doc1, $doc2));
        $similarities = count($this->findSimilarities($doc1, $doc2));
        $total = $differences + $similarities;

        $similarityScore = $total > 0 ? $similarities / $total : 0;

        return [
            'similarity_score' => round($similarityScore, 2),
            'difference_count' => $differences,
            'similarity_count' => $similarities,
            'additions_count' => count($this->findAdditions($doc1, $doc2)),
            'removals_count' => count($this->findRemovals($doc1, $doc2)),
            'modifications_count' => count($this->findModifications($doc1, $doc2)),
            'overall_alignment' => $this->getAlignmentLabel($similarityScore),
        ];
    }

    /**
     * Categorize changes by type
     */
    protected function categorizeChanges(array $doc1, array $doc2): array
    {
        $differences = $this->findDifferences($doc1, $doc2);

        $categories = [
            'governance_structure' => [],
            'investment_limits' => [],
            'compliance_requirements' => [],
            'deadlines' => [],
            'reporting' => [],
            'definitions' => [],
        ];

        foreach ($differences as $diff) {
            $category = $this->determineCategory($diff);
            if ($category && isset($categories[$category])) {
                $categories[$category][] = $diff;
            }
        }

        return $categories;
    }

    /**
     * Analyze governance changes
     */
    protected function analyzeGovernanceChanges(array $doc1, array $doc2): array
    {
        $gov1 = $doc1['governance'] ?? [];
        $gov2 = $doc2['governance'] ?? [];

        return [
            'tier_change' => [
                'from' => count($gov1['tiers'] ?? []),
                'to' => count($gov2['tiers'] ?? []),
                'type' => count($gov2['tiers'] ?? []) > count($gov1['tiers'] ?? []) ? 'expansion' : 'consolidation',
            ],
            'new_tiers' => array_diff($gov2['tiers'] ?? [], $gov1['tiers'] ?? []),
            'removed_tiers' => array_diff($gov1['tiers'] ?? [], $gov2['tiers'] ?? []),
            'requirement_changes' => [
                'from' => count($gov1['requirements'] ?? []),
                'to' => count($gov2['requirements'] ?? []),
            ],
        ];
    }

    /**
     * Analyze investment changes
     */
    protected function analyzeInvestmentChanges(array $doc1, array $doc2): array
    {
        $inv1 = $doc1['investments'] ?? [];
        $inv2 = $doc2['investments'] ?? [];

        return [
            'asset_class_changes' => [
                'new' => array_diff($inv2['asset_classes'] ?? [], $inv1['asset_classes'] ?? []),
                'removed' => array_diff($inv1['asset_classes'] ?? [], $inv2['asset_classes'] ?? []),
            ],
            'limit_changes' => [
                'from_count' => count($inv1['limits'] ?? []),
                'to_count' => count($inv2['limits'] ?? []),
            ],
            'prohibition_changes' => [
                'from_count' => count($inv1['prohibitions'] ?? []),
                'to_count' => count($inv2['prohibitions'] ?? []),
            ],
        ];
    }

    /**
     * Analyze compliance changes
     */
    protected function analyzeComplianceChanges(array $doc1, array $doc2): array
    {
        $comp1 = $doc1['compliance'] ?? [];
        $comp2 = $doc2['compliance'] ?? [];

        return [
            'certification_changes' => [
                'new' => array_diff($comp2['certification'] ?? [], $comp1['certification'] ?? []),
                'removed' => array_diff($comp1['certification'] ?? [], $comp2['certification'] ?? []),
            ],
            'reporting_changes' => [
                'from_count' => count($comp1['reporting'] ?? []),
                'to_count' => count($comp2['reporting'] ?? []),
            ],
            'deadline_changes' => [
                'new' => array_diff($comp2['deadlines'] ?? [], $comp1['deadlines'] ?? []),
                'modified' => array_intersect($comp2['deadlines'] ?? [], $comp1['deadlines'] ?? []),
            ],
        ];
    }

    /**
     * Analyze tier changes
     */
    protected function analyzeTierChanges(array $doc1, array $doc2): array
    {
        $tiers1 = $doc1['tiers'] ?? [];
        $tiers2 = $doc2['tiers'] ?? [];

        return [
            'tier_count_change' => [
                'from' => count($tiers1),
                'to' => count($tiers2),
            ],
            'new_tiers' => array_diff_key($tiers2, $tiers1),
            'removed_tiers' => array_diff_key($tiers1, $tiers2),
            'modified_tiers' => array_intersect_key($tiers1, $tiers2),
        ];
    }

    /**
     * Assess impact of changes
     */
    protected function assessImpact(array $doc1, array $doc2): array
    {
        $differences = $this->findDifferences($doc1, $doc2);
        $categories = $this->categorizeChanges($doc1, $doc2);

        $highImpactCount = 0;
        $mediumImpactCount = 0;
        $lowImpactCount = 0;

        foreach ($differences as $diff) {
            $significance = $diff['significance'] ?? 0.5;
            if ($significance >= 0.8) {
                $highImpactCount++;
            } elseif ($significance >= 0.5) {
                $mediumImpactCount++;
            } else {
                $lowImpactCount++;
            }
        }

        return [
            'overall_impact' => $this->calculateOverallImpact($categories),
            'high_impact_changes' => $highImpactCount,
            'medium_impact_changes' => $mediumImpactCount,
            'low_impact_changes' => $lowImpactCount,
            'implementation_complexity' => $this->assessImplementationComplexity($categories),
            'transition_timeline_estimate' => $this->estimateTransitionTimeline($categories),
        ];
    }

    /**
     * Compare two arrays recursively
     */
    protected function compareArrays(array $arr1, array $arr2, string $prefix = ''): array
    {
        $differences = [];

        foreach ($arr1 as $key => $value1) {
            $field = $prefix ? "{$prefix}.{$key}" : $key;

            if (! array_key_exists($key, $arr2)) {
                $differences[] = [
                    'field' => $field,
                    'status' => 'removed',
                    'doc1_value' => is_array($value1) ? json_encode($value1) : $value1,
                    'doc2_value' => null,
                ];

                continue;
            }

            $value2 = $arr2[$key];

            if (is_array($value1) && is_array($value2)) {
                $differences = array_merge(
                    $differences,
                    $this->compareArrays($value1, $value2, $field)
                );
            } elseif ($value1 !== $value2) {
                $differences[] = [
                    'field' => $field,
                    'status' => 'modified',
                    'doc1_value' => is_array($value1) ? json_encode($value1) : $value1,
                    'doc2_value' => is_array($value2) ? json_encode($value2) : $value2,
                ];
            }
        }

        foreach ($arr2 as $key => $value2) {
            $field = $prefix ? "{$prefix}.{$key}" : $key;

            if (! array_key_exists($key, $arr1)) {
                $differences[] = [
                    'field' => $field,
                    'status' => 'added',
                    'doc1_value' => null,
                    'doc2_value' => is_array($value2) ? json_encode($value2) : $value2,
                ];
            }
        }

        return $differences;
    }

    /**
     * Calculate significance score for a difference
     */
    protected function calculateSignificance(array $diff): float
    {
        $field = $diff['field'] ?? '';

        foreach ($this->significanceWeights as $key => $weight) {
            if (str_contains($field, $key)) {
                return $weight;
            }
        }

        return 0.5;
    }

    /**
     * Determine category for a difference
     */
    protected function determineCategory(array $diff): ?string
    {
        $field = $diff['field'] ?? '';

        if (str_contains($field, 'governance') || str_contains($field, 'tier')) {
            return 'governance_structure';
        }
        if (str_contains($field, 'investment') || str_contains($field, 'limit')) {
            return 'investment_limits';
        }
        if (str_contains($field, 'compliance') || str_contains($field, 'certification')) {
            return 'compliance_requirements';
        }
        if (str_contains($field, 'deadline')) {
            return 'deadlines';
        }
        if (str_contains($field, 'reporting')) {
            return 'reporting';
        }
        if (str_contains($field, 'definition')) {
            return 'definitions';
        }

        return null;
    }

    /**
     * Get alignment label from score
     */
    protected function getAlignmentLabel(float $score): string
    {
        if ($score >= 0.8) {
            return 'high';
        }
        if ($score >= 0.5) {
            return 'moderate';
        }

        return 'low';
    }

    /**
     * Calculate overall impact
     */
    protected function calculateOverallImpact(array $categories): string
    {
        $significantChanges = 0;
        $weights = array_values($this->significanceWeights);

        foreach ($categories as $category => $changes) {
            $weight = $this->significanceWeights[$category] ?? 0.5;
            $significantChanges += count($changes) * $weight;
        }

        if ($significantChanges > 10) {
            return 'very_high';
        }
        if ($significantChanges > 5) {
            return 'high';
        }
        if ($significantChanges > 2) {
            return 'moderate';
        }

        return 'low';
    }

    /**
     * Assess implementation complexity
     */
    protected function assessImplementationComplexity(array $categories): string
    {
        $complexityScore = 0;

        foreach ($categories as $category => $changes) {
            if ($category === 'governance_structure') {
                $complexityScore += count($changes) * 3;
            } elseif ($category === 'investment_limits') {
                $complexityScore += count($changes) * 2;
            } else {
                $complexityScore += count($changes);
            }
        }

        if ($complexityScore > 20) {
            return 'very_high';
        }
        if ($complexityScore > 10) {
            return 'high';
        }
        if ($complexityScore > 5) {
            return 'moderate';
        }

        return 'low';
    }

    /**
     * Estimate transition timeline
     */
    protected function estimateTransitionTimeline(array $categories): string
    {
        $complexity = $this->assessImplementationComplexity($categories);

        return match ($complexity) {
            'very_high' => '24-36 months',
            'high' => '18-24 months',
            'moderate' => '12-18 months',
            default => '6-12 months',
        };
    }
}

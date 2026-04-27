<?php

namespace Tests\LegislationAnalysis\Validators;

/**
 * Findings Completeness Validator
 * Validates completeness of all findings with required fields
 */
class FindingsCompletenessValidator
{
    private array $missingFields = [];
    private array $fieldCoverage = [];

    /**
     * Validate completeness of all findings
     */
    public function validateCompleteness(array $findings): array
    {
        $this->resetValidationState();

        $requiredFieldsBySource = [
            'swarm/researcher/cmn-4963' => [
                'notification_id', 'title', 'state', 'year', 'legislation_type',
                'bill_number', 'status', 'effective_date', 'compliance_deadline',
                'key_requirements', 'affected_entities', 'reporting_requirements',
                'penalties', 'agency', 'metadata',
            ],
            'swarm/researcher/cmn-5272' => [
                'notification_id', 'title', 'state', 'year', 'legislation_type',
                'bill_number', 'status', 'effective_date', 'compliance_deadline',
                'key_requirements', 'affected_entities', 'reporting_requirements',
                'penalties', 'agency', 'metadata',
            ],
            'swarm/coder/comparison-results' => [
                'comparison_id', 'compared_notifications', 'comparison_date',
                'differences', 'similarities', 'metrics', 'metadata',
            ],
            'swarm/analyst/regulatory-impact' => [
                'analysis_id', 'analysis_date', 'assessments', 'recommendations',
                'compliance_score', 'metadata',
            ],
        ];

        $totalRequiredFields = 0;
        $totalPresentFields = 0;

        foreach ($requiredFieldsBySource as $source => $requiredFields) {
            if (!isset($findings[$source])) {
                foreach ($requiredFields as $field) {
                    $this->missingFields[] = [
                        'source' => $source,
                        'field' => $field,
                        'reason' => 'source_not_found',
                    ];
                }
                continue;
            }

            $data = $findings[$source];
            $sourceFieldCoverage = [];

            foreach ($requiredFields as $field) {
                $totalRequiredFields++;

                if (isset($data[$field])) {
                    $totalPresentFields++;
                    $sourceFieldCoverage[$field] = 'present';
                } else {
                    $this->missingFields[] = [
                        'source' => $source,
                        'field' => $field,
                        'reason' => 'field_missing',
                    ];
                    $sourceFieldCoverage[$field] = 'missing';
                }
            }

            $this->fieldCoverage[$source] = [
                'coverage' => $sourceFieldCoverage,
                'coverage_percentage' => $this->calculateFieldCoverage($sourceFieldCoverage),
                'required_count' => count($requiredFields),
                'present_count' => count(array_filter($sourceFieldCoverage, fn($s) => $s === 'present')),
            ];
        }

        $overallCoverage = $totalRequiredFields > 0
            ? round(($totalPresentFields / $totalRequiredFields) * 100, 2)
            : 0;

        $dataIntegrity = $this->validateDataIntegrity($findings);

        return [
            'is_complete' => empty($this->missingFields),
            'missing_fields' => $this->missingFields,
            'field_coverage' => $this->fieldCoverage,
            'overall_coverage' => $overallCoverage,
            'total_required_fields' => $totalRequiredFields,
            'total_present_fields' => $totalPresentFields,
            'data_integrity' => $dataIntegrity,
            'metadata' => [
                'sources_checked' => count($requiredFieldsBySource),
                'sources_present' => count(array_filter(array_keys($requiredFieldsBySource), fn($s) => isset($findings[$s]))),
                'missing_fields_count' => count($this->missingFields),
            ],
        ];
    }

    /**
     * Validate data integrity
     */
    private function validateDataIntegrity(array $findings): array
    {
        $integrityChecks = [
            'has_metadata' => true,
            'valid_structure' => true,
            'no_empty_required' => true,
            'consistent_types' => true,
        ];

        foreach ($findings as $source => $data) {
            // Check metadata presence
            if (!isset($data['metadata'])) {
                $integrityChecks['has_metadata'] = false;
            }

            // Check valid structure
            if (!is_array($data)) {
                $integrityChecks['valid_structure'] = false;
            }

            // Check for empty required fields
            if (isset($data['notification_id']) && empty($data['notification_id'])) {
                $integrityChecks['no_empty_required'] = false;
            }

            // Check consistent types
            if (isset($data['key_requirements']) && !is_array($data['key_requirements'])) {
                $integrityChecks['consistent_types'] = false;
            }
        }

        return [
            'passed' => count(array_filter($integrityChecks, fn($v) => $v)) === count($integrityChecks),
            'checks' => $integrityChecks,
            'integrity_score' => round(
                (count(array_filter($integrityChecks, fn($v) => $v)) / count($integrityChecks)) * 100,
                2
            ),
        ];
    }

    /**
     * Calculate field coverage percentage
     */
    private function calculateFieldCoverage(array $coverage): float
    {
        if (empty($coverage)) {
            return 0.0;
        }

        $presentCount = count(array_filter($coverage, fn($s) => $s === 'present'));
        return round(($presentCount / count($coverage)) * 100, 2);
    }

    /**
     * Reset validation state
     */
    private function resetValidationState(): void
    {
        $this->missingFields = [];
        $this->fieldCoverage = [];
    }
}

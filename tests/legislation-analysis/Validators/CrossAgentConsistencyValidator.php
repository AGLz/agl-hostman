<?php

namespace Tests\LegislationAnalysis\Validators;

/**
 * Cross-Agent Consistency Validator
 * Validates consistency of findings across all agents
 */
class CrossAgentConsistencyValidator
{
    private array $inconsistencies = [];
    private array $crossReferences = [];

    /**
     * Validate consistency across all agents
     */
    public function validateConsistency(array $findings): array
    {
        $this->resetValidationState();

        $consistencyChecks = [];

        // Check CMN-4963 consistency between researcher and coder
        if (isset($findings['swarm/researcher/cmn-4963']) &&
            isset($findings['swarm/coder/comparison-results'])) {
            $consistencyChecks['cmn4963_researcher_coder'] = $this->validateCMN4963Consistency(
                $findings['swarm/researcher/cmn-4963'],
                $findings['swarm/coder/comparison-results']
            );
        }

        // Check CMN-5272 consistency between researcher and coder
        if (isset($findings['swarm/researcher/cmn-5272']) &&
            isset($findings['swarm/coder/comparison-results'])) {
            $consistencyChecks['cmn5272_researcher_coder'] = $this->validateCMN5272Consistency(
                $findings['swarm/researcher/cmn-5272'],
                $findings['swarm/coder/comparison-results']
            );
        }

        // Check regulatory impact alignment with research findings
        if (isset($findings['swarm/analyst/regulatory-impact'])) {
            $consistencyChecks['regulatory_research_alignment'] = $this->validateRegulatoryAlignment(
                $findings['swarm/analyst/regulatory-impact'],
                $findings['swarm/researcher/cmn-4963'] ?? [],
                $findings['swarm/researcher/cmn-5272'] ?? []
            );
        }

        // Check data integrity across all findings
        $consistencyChecks['data_integrity'] = $this->validateDataIntegrity($findings);

        $consistencyScore = $this->calculateConsistencyScore($consistencyChecks);

        return [
            'consistency_score' => $consistencyScore,
            'consistency_checks' => $consistencyChecks,
            'inconsistencies' => $this->inconsistencies,
            'cross_references' => $this->crossReferences,
            'data_integrity' => $consistencyChecks['data_integrity'] ?? [],
            'alignment_score' => $this->calculateAlignmentScore($consistencyChecks),
            'total_checks' => count($consistencyChecks),
            'passed_checks' => count(array_filter($consistencyChecks, fn($c) => $c['passed'] ?? false)),
        ];
    }

    /**
     * Validate CMN-4963 consistency between researcher and coder
     */
    private function validateCMN4963Consistency(array $researchData, array $comparisonData): array
    {
        $passed = true;
        $issues = [];

        // Check that CMN-4963 is referenced in comparison
        if (isset($comparisonData['compared_notifications'])) {
            if (!in_array('CMN-4963', $comparisonData['compared_notifications'])) {
                $issues[] = 'CMN-4963 not found in comparison notifications';
                $passed = false;
            }
        }

        // Check key field consistency
        if (isset($researchData['notification_id']) && $researchData['notification_id'] !== 'CMN-4963') {
            $issues[] = 'CMN-4963 notification_id mismatch';
            $passed = false;
        }

        // Check state consistency
        if (isset($comparisonData['similarities'])) {
            $stateMatch = false;
            foreach ($comparisonData['similarities'] as $similarity) {
                if (isset($similarity['field']) && $similarity['field'] === 'state' &&
                    isset($similarity['value']) && $similarity['value'] === 'California') {
                    $stateMatch = true;
                    break;
                }
            }

            if (!$stateMatch && isset($researchData['state']) && $researchData['state'] === 'California') {
                $issues[] = 'State field not properly captured in comparison';
                $passed = false;
            }
        }

        $this->crossReferences[] = [
            'source' => 'researcher/cmn-4963',
            'target' => 'coder/comparison-results',
            'type' => 'field_consistency',
            'status' => $passed ? 'consistent' : 'inconsistent',
        ];

        if (!$passed) {
            foreach ($issues as $issue) {
                $this->inconsistencies[] = [
                    'source' => 'cmn4963',
                    'type' => 'consistency_error',
                    'message' => $issue,
                ];
            }
        }

        return [
            'passed' => $passed,
            'issues' => $issues,
            'checked_fields' => ['notification_id', 'state', 'title'],
        ];
    }

    /**
     * Validate CMN-5272 consistency between researcher and coder
     */
    private function validateCMN5272Consistency(array $researchData, array $comparisonData): array
    {
        $passed = true;
        $issues = [];

        // Check that CMN-5272 is referenced in comparison
        if (isset($comparisonData['compared_notifications'])) {
            if (!in_array('CMN-5272', $comparisonData['compared_notifications'])) {
                $issues[] = 'CMN-5272 not found in comparison notifications';
                $passed = false;
            }
        }

        // Check key field consistency
        if (isset($researchData['notification_id']) && $researchData['notification_id'] !== 'CMN-5272') {
            $issues[] = 'CMN-5272 notification_id mismatch';
            $passed = false;
        }

        // Check legislation type consistency
        if (isset($comparisonData['similarities'])) {
            $typeMatch = false;
            foreach ($comparisonData['similarities'] as $similarity) {
                if (isset($similarity['field']) && $similarity['field'] === 'legislation_type' &&
                    isset($similarity['value']) && $similarity['value'] === 'Senate Bill') {
                    $typeMatch = true;
                    break;
                }
            }

            if (!$typeMatch && isset($researchData['legislation_type']) &&
                $researchData['legislation_type'] === 'Senate Bill') {
                $issues[] = 'Legislation type not properly captured in comparison';
                $passed = false;
            }
        }

        $this->crossReferences[] = [
            'source' => 'researcher/cmn-5272',
            'target' => 'coder/comparison-results',
            'type' => 'field_consistency',
            'status' => $passed ? 'consistent' : 'inconsistent',
        ];

        if (!$passed) {
            foreach ($issues as $issue) {
                $this->inconsistencies[] = [
                    'source' => 'cmn5272',
                    'type' => 'consistency_error',
                    'message' => $issue,
                ];
            }
        }

        return [
            'passed' => $passed,
            'issues' => $issues,
            'checked_fields' => ['notification_id', 'legislation_type', 'bill_number'],
        ];
    }

    /**
     * Validate regulatory impact alignment with research findings
     */
    private function validateRegulatoryAlignment(array $regulatoryData, array $cmn4963Data, array $cmn5272Data): array
    {
        $passed = true;
        $issues = [];

        // Check that assessments reference both notifications
        if (isset($regulatoryData['assessments'])) {
            $referencedNotifications = array_column($regulatoryData['assessments'], 'notification');

            if (!in_array('CMN-4963', $referencedNotifications)) {
                $issues[] = 'CMN-4963 not found in regulatory assessments';
                $passed = false;
            }

            if (!in_array('CMN-5272', $referencedNotifications)) {
                $issues[] = 'CMN-5272 not found in regulatory assessments';
                $passed = false;
            }
        }

        // Check impact level consistency
        if (!empty($cmn4963Data) && isset($regulatoryData['assessments'])) {
            foreach ($regulatoryData['assessments'] as $assessment) {
                if (isset($assessment['notification']) && $assessment['notification'] === 'CMN-4963') {
                    if (isset($assessment['impact_level']) && $assessment['impact_level'] !== 'high' &&
                        $assessment['impact_level'] !== 'medium') {
                        $issues[] = 'CMN-4963 impact level should be high or medium';
                        $passed = false;
                    }
                }
            }
        }

        $this->crossReferences[] = [
            'source' => 'analyst/regulatory-impact',
            'target' => 'researcher/cmn-4963,researcher/cmn-5272',
            'type' => 'alignment_check',
            'status' => $passed ? 'aligned' : 'misaligned',
        ];

        if (!$passed) {
            foreach ($issues as $issue) {
                $this->inconsistencies[] = [
                    'source' => 'regulatory',
                    'type' => 'alignment_error',
                    'message' => $issue,
                ];
            }
        }

        return [
            'passed' => $passed,
            'issues' => $issues,
            'checked_alignments' => ['assessment_references', 'impact_levels', 'recommendations'],
        ];
    }

    /**
     * Validate data integrity across all findings
     */
    private function validateDataIntegrity(array $findings): array
    {
        $passed = true;
        $issues = [];

        // Check that all findings have required metadata
        foreach ($findings as $key => $data) {
            if (!isset($data['metadata'])) {
                $issues[] = "{$key} missing metadata";
                $passed = false;
            }
        }

        // Check for data type consistency
        foreach ($findings as $key => $data) {
            if (!is_array($data)) {
                $issues[] = "{$key} is not an array";
                $passed = false;
            }
        }

        return [
            'passed' => $passed,
            'issues' => $issues,
            'total_sources' => count($findings),
            'validated_sources' => count(array_filter($findings, fn($d) => isset($d['metadata']))),
        ];
    }

    /**
     * Calculate overall consistency score
     */
    private function calculateConsistencyScore(array $consistencyChecks): float
    {
        if (empty($consistencyChecks)) {
            return 0.0;
        }

        $totalChecks = count($consistencyChecks);
        $passedChecks = count(array_filter($consistencyChecks, fn($c) => $c['passed'] ?? false));

        return round(($passedChecks / $totalChecks) * 100, 2);
    }

    /**
     * Calculate alignment score
     */
    private function calculateAlignmentScore(array $consistencyChecks): float
    {
        if (empty($consistencyChecks)) {
            return 0.0;
        }

        $totalScore = 0;
        $count = 0;

        foreach ($consistencyChecks as $check) {
            if (isset($check['passed'])) {
                $totalScore += $check['passed'] ? 100 : 0;
                $count++;
            }
        }

        return $count > 0 ? round($totalScore / $count, 2) : 0.0;
    }

    /**
     * Reset validation state
     */
    private function resetValidationState(): void
    {
        $this->inconsistencies = [];
        $this->crossReferences = [];
    }
}

<?php

namespace Tests\LegislationAnalysis\Validators;

/**
 * Data Accuracy Validator
 * Validates accuracy of data across all legislation analysis components
 */
class DataAccuracyValidator
{
    private array $errors = [];
    private array $warnings = [];
    private int $verifiedFields = 0;

    /**
     * Validate CMN-4963 data accuracy
     */
    public function validateCMN4963(array $data): array
    {
        $this->resetValidationState();

        $requiredFields = [
            'notification_id',
            'title',
            'state',
            'year',
            'legislation_type',
            'bill_number',
            'status',
            'effective_date',
            'compliance_deadline',
            'key_requirements',
            'affected_entities',
            'reporting_requirements',
            'penalties',
            'agency',
        ];

        foreach ($requiredFields as $field) {
            $this->validateFieldPresence($data, $field, 'CMN-4963');
        }

        $this->validateSpecificCMN4963Fields($data);

        return [
            'is_accurate' => empty($this->errors),
            'verified_fields' => $this->verifiedFields,
            'errors' => $this->errors,
            'warnings' => $this->warnings,
            'validation_summary' => $this->generateValidationSummary(),
        ];
    }

    /**
     * Validate CMN-5272 data accuracy
     */
    public function validateCMN5272(array $data): array
    {
        $this->resetValidationState();

        $requiredFields = [
            'notification_id',
            'title',
            'state',
            'year',
            'legislation_type',
            'bill_number',
            'status',
            'effective_date',
            'compliance_deadline',
            'key_requirements',
            'affected_entities',
            'reporting_requirements',
            'penalties',
            'agency',
        ];

        foreach ($requiredFields as $field) {
            $this->validateFieldPresence($data, $field, 'CMN-5272');
        }

        $this->validateSpecificCMN5272Fields($data);

        return [
            'is_accurate' => empty($this->errors),
            'verified_fields' => $this->verifiedFields,
            'errors' => $this->errors,
            'warnings' => $this->warnings,
            'validation_summary' => $this->generateValidationSummary(),
        ];
    }

    /**
     * Validate comparison results accuracy
     */
    public function validateComparisonResults(array $data): array
    {
        $this->resetValidationState();

        $requiredFields = [
            'comparison_id',
            'compared_notifications',
            'comparison_date',
            'differences',
            'similarities',
            'metrics',
        ];

        foreach ($requiredFields as $field) {
            $this->validateFieldPresence($data, $field, 'comparison-results');
        }

        $this->validateComparisonStructure($data);

        return [
            'is_accurate' => empty($this->errors),
            'verified_fields' => $this->verifiedFields,
            'errors' => $this->errors,
            'warnings' => $this->warnings,
            'differences' => $data['differences'] ?? [],
            'similarities' => $data['similarities'] ?? [],
            'metrics' => $data['metrics'] ?? [],
            'validation_summary' => $this->generateValidationSummary(),
        ];
    }

    /**
     * Validate regulatory impact accuracy
     */
    public function validateRegulatoryImpact(array $data): array
    {
        $this->resetValidationState();

        $requiredFields = [
            'analysis_id',
            'analysis_date',
            'assessments',
            'recommendations',
            'compliance_score',
        ];

        foreach ($requiredFields as $field) {
            $this->validateFieldPresence($data, $field, 'regulatory-impact');
        }

        $this->validateRegulatoryStructure($data);

        return [
            'is_accurate' => empty($this->errors),
            'verified_fields' => $this->verifiedFields,
            'errors' => $this->errors,
            'warnings' => $this->warnings,
            'assessments' => $data['assessments'] ?? [],
            'recommendations' => $data['recommendations'] ?? [],
            'compliance_score' => $data['compliance_score'] ?? [],
            'validation_summary' => $this->generateValidationSummary(),
        ];
    }

    /**
     * Validate data integrity across all components
     */
    public function validateDataIntegrity(array $findings): array
    {
        $this->resetValidationState();

        $violations = [];
        $checksums = [];

        foreach ($findings as $key => $data) {
            if (!is_array($data)) {
                $violations[] = [
                    'source' => $key,
                    'type' => 'invalid_data_type',
                    'message' => 'Data must be an array',
                ];
                continue;
            }

            // Generate checksum for data integrity
            $checksums[$key] = $this->generateChecksum($data);

            // Check for required metadata
            if (isset($data['metadata'])) {
                $this->validateMetadata($data['metadata'], $key);
            } else {
                $violations[] = [
                    'source' => $key,
                    'type' => 'missing_metadata',
                    'message' => 'Metadata is required for data integrity tracking',
                ];
            }

            // Check for data consistency
            $this->validateDataConsistency($data, $key);
        }

        return [
            'integrity_valid' => empty($violations),
            'violations' => $violations,
            'checksums' => $checksums,
            'consistency_checks' => [
                'total_sources' => count($findings),
                'validated_sources' => count($checksums),
                'validation_rate' => count($findings) > 0 ? (count($checksums) / count($findings)) * 100 : 0,
            ],
        ];
    }

    /**
     * Validate edge cases and boundary conditions
     */
    public function validateEdgeCases(array $findings): array
    {
        $emptyValues = [];
        $nullValues = [];
        $formatViolations = [];

        foreach ($findings as $key => $data) {
            if (!is_array($data)) {
                continue;
            }

            $this->scanForEmptyValues($data, $key, $emptyValues);
            $this->scanForNullValues($data, $key, $nullValues);
            $this->scanForFormatViolations($data, $key, $formatViolations);
        }

        $boundaryViolations = array_merge($emptyValues, $nullValues, $formatViolations);

        return [
            'boundary_violations' => $boundaryViolations,
            'empty_values' => $emptyValues,
            'null_values' => $nullValues,
            'format_violations' => $formatViolations,
            'total_violations' => count($boundaryViolations),
        ];
    }

    /**
     * Validate specific CMN-4963 fields
     */
    private function validateSpecificCMN4963Fields(array $data): void
    {
        // Validate notification ID format
        if (isset($data['notification_id'])) {
            if ($data['notification_id'] !== 'CMN-4963') {
                $this->errors[] = 'CMN-4963: notification_id must be "CMN-4963"';
            }
        }

        // Validate year
        if (isset($data['year'])) {
            if (!is_numeric($data['year']) || $data['year'] < 2000 || $data['year'] > 2100) {
                $this->errors[] = 'CMN-4963: year must be a valid year between 2000 and 2100';
            }
        }

        // Validate date format
        $this->validateDateFormat($data, 'effective_date', 'CMN-4963');
        $this->validateDateFormat($data, 'compliance_deadline', 'CMN-4963');

        // Validate key_requirements is array
        if (isset($data['key_requirements']) && !is_array($data['key_requirements'])) {
            $this->errors[] = 'CMN-4963: key_requirements must be an array';
        }

        // Validate penalties structure
        if (isset($data['penalties'])) {
            if (!is_array($data['penalties'])) {
                $this->errors[] = 'CMN-4963: penalties must be an array';
            } else {
                if (!isset($data['penalties']['type'])) {
                    $this->warnings[] = 'CMN-4963: penalties.type is recommended';
                }
                if (!isset($data['penalties']['maximum'])) {
                    $this->warnings[] = 'CMN-4963: penalties.maximum is recommended';
                }
            }
        }
    }

    /**
     * Validate specific CMN-5272 fields
     */
    private function validateSpecificCMN5272Fields(array $data): void
    {
        // Validate notification ID format
        if (isset($data['notification_id'])) {
            if ($data['notification_id'] !== 'CMN-5272') {
                $this->errors[] = 'CMN-5272: notification_id must be "CMN-5272"';
            }
        }

        // Validate year
        if (isset($data['year'])) {
            if (!is_numeric($data['year']) || $data['year'] < 2000 || $data['year'] > 2100) {
                $this->errors[] = 'CMN-5272: year must be a valid year between 2000 and 2100';
            }
        }

        // Validate date format
        $this->validateDateFormat($data, 'effective_date', 'CMN-5272');
        $this->validateDateFormat($data, 'compliance_deadline', 'CMN-5272');

        // Validate key_requirements is array
        if (isset($data['key_requirements']) && !is_array($data['key_requirements'])) {
            $this->errors[] = 'CMN-5272: key_requirements must be an array';
        }

        // Validate penalties structure
        if (isset($data['penalties'])) {
            if (!is_array($data['penalties'])) {
                $this->errors[] = 'CMN-5272: penalties must be an array';
            }
        }
    }

    /**
     * Validate comparison structure
     */
    private function validateComparisonStructure(array $data): void
    {
        if (isset($data['differences']) && !is_array($data['differences'])) {
            $this->errors[] = 'comparison: differences must be an array';
        }

        if (isset($data['similarities']) && !is_array($data['similarities'])) {
            $this->errors[] = 'comparison: similarities must be an array';
        }

        if (isset($data['metrics'])) {
            if (!is_array($data['metrics'])) {
                $this->errors[] = 'comparison: metrics must be an array';
            } else {
                // Validate metrics contains expected fields
                $expectedMetricFields = ['similarity_score', 'difference_count', 'similarity_count'];
                foreach ($expectedMetricFields as $field) {
                    if (!isset($data['metrics'][$field])) {
                        $this->warnings[] = "comparison: metrics.{$field} is recommended";
                    }
                }
            }
        }

        if (isset($data['compared_notifications']) && !is_array($data['compared_notifications'])) {
            $this->errors[] = 'comparison: compared_notifications must be an array';
        }
    }

    /**
     * Validate regulatory structure
     */
    private function validateRegulatoryStructure(array $data): void
    {
        if (isset($data['assessments']) && !is_array($data['assessments'])) {
            $this->errors[] = 'regulatory: assessments must be an array';
        }

        if (isset($data['recommendations']) && !is_array($data['recommendations'])) {
            $this->errors[] = 'regulatory: recommendations must be an array';
        }

        if (isset($data['compliance_score'])) {
            if (!is_array($data['compliance_score'])) {
                $this->errors[] = 'regulatory: compliance_score must be an array';
            } else {
                // Validate compliance scores are within 0-100 range
                foreach ($data['compliance_score'] as $key => $score) {
                    if (!is_numeric($score) || $score < 0 || $score > 100) {
                        $this->errors[] = "regulatory: compliance_score.{$key} must be between 0 and 100";
                    }
                }
            }
        }
    }

    /**
     * Validate metadata structure
     */
    private function validateMetadata(array $metadata, string $source): void
    {
        $recommendedFields = ['source_url', 'last_updated', 'confidence_score'];

        foreach ($recommendedFields as $field) {
            if (!isset($metadata[$field])) {
                $this->warnings[] = "{$source}: metadata.{$field} is recommended";
            }
        }

        if (isset($metadata['confidence_score'])) {
            if (!is_numeric($metadata['confidence_score']) ||
                $metadata['confidence_score'] < 0 ||
                $metadata['confidence_score'] > 1) {
                $this->errors[] = "{$source}: confidence_score must be between 0 and 1";
            }
        }
    }

    /**
     * Validate data consistency
     */
    private function validateDataConsistency(array $data, string $source): void
    {
        // Check for consistent date formats
        if (isset($data['effective_date']) && isset($data['compliance_deadline'])) {
            $effectiveDate = strtotime($data['effective_date']);
            $deadlineDate = strtotime($data['compliance_deadline']);

            if ($effectiveDate && $deadlineDate) {
                if ($deadlineDate < $effectiveDate) {
                    $this->errors[] = "{$source}: compliance_deadline must be after effective_date";
                }
            }
        }
    }

    /**
     * Scan for empty values
     */
    private function scanForEmptyValues(array $data, string $source, array &$results): void
    {
        foreach ($data as $key => $value) {
            if ($value === '') {
                $results[] = [
                    'source' => $source,
                    'field' => $key,
                    'type' => 'empty_string',
                ];
            } elseif (is_array($value)) {
                $this->scanForEmptyValues($value, "{$source}.{$key}", $results);
            }
        }
    }

    /**
     * Scan for null values
     */
    private function scanForNullValues(array $data, string $source, array &$results): void
    {
        foreach ($data as $key => $value) {
            if ($value === null) {
                $results[] = [
                    'source' => $source,
                    'field' => $key,
                    'type' => 'null_value',
                ];
            } elseif (is_array($value)) {
                $this->scanForNullValues($value, "{$source}.{$key}", $results);
            }
        }
    }

    /**
     * Scan for format violations
     */
    private function scanForFormatViolations(array $data, string $source, array &$results): void
    {
        foreach ($data as $key => $value) {
            if (is_string($value)) {
                // Check date fields
                if (strpos($key, 'date') !== false || strpos($key, 'deadline') !== false) {
                    if (strtotime($value) === false) {
                        $results[] = [
                            'source' => $source,
                            'field' => $key,
                            'type' => 'invalid_date_format',
                            'value' => $value,
                        ];
                    }
                }
            } elseif (is_array($value)) {
                $this->scanForFormatViolations($value, "{$source}.{$key}", $results);
            }
        }
    }

    /**
     * Validate field presence
     */
    private function validateFieldPresence(array $data, string $field, string $source): void
    {
        if (!isset($data[$field])) {
            $this->errors[] = "{$source}: Required field '{$field}' is missing";
        } else {
            $this->verifiedFields++;
        }
    }

    /**
     * Validate date format
     */
    private function validateDateFormat(array $data, string $field, string $source): void
    {
        if (isset($data[$field])) {
            if (strtotime($data[$field]) === false) {
                $this->errors[] = "{$source}: {$field} has invalid date format";
            }
        }
    }

    /**
     * Generate checksum for data integrity
     */
    private function generateChecksum(array $data): string
    {
        return hash('sha256', json_encode($data));
    }

    /**
     * Generate validation summary
     */
    private function generateValidationSummary(): array
    {
        return [
            'verified_fields' => $this->verifiedFields,
            'error_count' => count($this->errors),
            'warning_count' => count($this->warnings),
            'validation_rate' => $this->verifiedFields > 0
                ? round((1 - (count($this->errors) / $this->verifiedFields)) * 100, 2)
                : 0,
        ];
    }

    /**
     * Reset validation state
     */
    private function resetValidationState(): void
    {
        $this->errors = [];
        $this->warnings = [];
        $this->verifiedFields = 0;
    }
}

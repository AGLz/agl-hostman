<?php

namespace Tests\LegislationAnalysis\Fixtures;

/**
 * Test Data Fixtures for Legislation Analysis
 * Provides sample data for testing legislation analysis components
 */
class LegislationTestData
{
    /**
     * Get CMN-4963 test data
     * Contains California Mandate Notification data for 4963
     */
    public function getCMN4963Data(): array
    {
        return [
            'notification_id' => 'CMN-4963',
            'title' => 'California Climate Corporate Data Accountability Act',
            'state' => 'California',
            'year' => 2023,
            'legislation_type' => 'Senate Bill',
            'bill_number' => 'SB 253',
            'status' => 'Enacted',
            'effective_date' => '2024-01-01',
            'compliance_deadline' => '2025-01-01',
            'key_requirements' => [
                'Greenhouse gas emissions reporting',
                'Scope 1, 2, and 3 emissions tracking',
                'Third-party verification required',
                'Annual public disclosure',
            ],
            'affected_entities' => [
                'Publicly traded corporations',
                'Private companies with > $1B revenue',
                'Businesses operating in California',
            ],
            'reporting_requirements' => [
                'frequency' => 'annual',
                'format' => 'standardized electronic format',
                'verification' => 'third-party',
                'disclosure' => 'public',
            ],
            'penalties' => [
                'type' => 'civil penalties',
                'maximum' => '$500,000 per violation',
            ],
            'agency' => 'California Air Resources Board (CARB)',
            'metadata' => [
                'source_url' => 'https://leginfo.legislature.ca.gov',
                'last_updated' => '2024-01-15',
                'researcher' => 'research-agent-1',
                'confidence_score' => 0.95,
            ],
        ];
    }

    /**
     * Get CMN-5272 test data
     * Contains California Mandate Notification data for 5272
     */
    public function getCMN5272Data(): array
    {
        return [
            'notification_id' => 'CMN-5272',
            'title' => 'California Climate-Related Financial Risk Act',
            'state' => 'California',
            'year' => 2023,
            'legislation_type' => 'Senate Bill',
            'bill_number' => 'SB 261',
            'status' => 'Enacted',
            'effective_date' => '2024-01-01',
            'compliance_deadline' => '2026-01-01',
            'key_requirements' => [
                'Climate-related financial risk disclosure',
                'Risk mitigation strategy documentation',
                'Biennial reporting requirement',
                'Board-level oversight required',
            ],
            'affected_entities' => [
                'Publicly traded corporations',
                'Private companies with > $500M revenue',
                'Businesses operating in California',
            ],
            'reporting_requirements' => [
                'frequency' => 'biennial',
                'format' => 'standardized format',
                'verification' => 'internal',
                'disclosure' => 'public',
            ],
            'penalties' => [
                'type' => 'civil penalties',
                'maximum' => '$250,000 per violation',
            ],
            'agency' => 'California Air Resources Board (CARB)',
            'metadata' => [
                'source_url' => 'https://leginfo.legislature.ca.gov',
                'last_updated' => '2024-01-15',
                'researcher' => 'research-agent-2',
                'confidence_score' => 0.92,
            ],
        ];
    }

    /**
     * Get comparison results from coder agent
     * Contains detailed comparison between CMN-4963 and CMN-5272
     */
    public function getComparisonResults(): array
    {
        return [
            'comparison_id' => 'comp-cmn-4963-5272',
            'compared_notifications' => ['CMN-4963', 'CMN-5272'],
            'comparison_date' => '2024-01-20',
            'differences' => [
                [
                    'field' => 'compliance_deadline',
                    'cmn4963' => '2025-01-01',
                    'cmn5272' => '2026-01-01',
                    'significance' => 'high',
                ],
                [
                    'field' => 'reporting_frequency',
                    'cmn4963' => 'annual',
                    'cmn5272' => 'biennial',
                    'significance' => 'medium',
                ],
                [
                    'field' => 'revenue_threshold',
                    'cmn4963' => '$1B',
                    'cmn5272' => '$500M',
                    'significance' => 'high',
                ],
                [
                    'field' => 'penalty_maximum',
                    'cmn4963' => '$500,000',
                    'cmn5272' => '$250,000',
                    'significance' => 'medium',
                ],
            ],
            'similarities' => [
                [
                    'field' => 'state',
                    'value' => 'California',
                ],
                [
                    'field' => 'legislation_type',
                    'value' => 'Senate Bill',
                ],
                [
                    'field' => 'agency',
                    'value' => 'California Air Resources Board (CARB)',
                ],
                [
                    'field' => 'penalty_type',
                    'value' => 'civil penalties',
                ],
                [
                    'field' => 'disclosure',
                    'value' => 'public',
                ],
            ],
            'metrics' => [
                'similarity_score' => 0.68,
                'difference_count' => 4,
                'similarity_count' => 5,
                'overall_alignment' => 'moderate',
            ],
            'metadata' => [
                'coder_agent' => 'coder-agent-1',
                'comparison_method' => 'field-by-field',
                'timestamp' => '2024-01-20T10:30:00Z',
            ],
        ];
    }

    /**
     * Get regulatory impact analysis from analyst agent
     * Contains comprehensive regulatory impact assessment
     */
    public function getRegulatoryImpact(): array
    {
        return [
            'analysis_id' => 'reg-impact-2024-01',
            'analysis_date' => '2024-01-22',
            'assessments' => [
                [
                    'notification' => 'CMN-4963',
                    'impact_level' => 'high',
                    'affected_businesses' => 'approximately 5,300',
                    'compliance_cost_estimate' => '$1.2M - $4.8M per company',
                    'implementation_timeline' => '12-24 months',
                    'key_impacts' => [
                        'Data infrastructure investment required',
                        'Third-party verification costs',
                        'Ongoing reporting expenses',
                        'Legal compliance resources',
                    ],
                ],
                [
                    'notification' => 'CMN-5272',
                    'impact_level' => 'medium',
                    'affected_businesses' => 'approximately 10,000',
                    'compliance_cost_estimate' => '$500K - $2M per company',
                    'implementation_timeline' => '24-36 months',
                    'key_impacts' => [
                        'Risk assessment process development',
                        'Board governance changes',
                        'Biennial reporting systems',
                        'Financial risk modeling',
                    ],
                ],
            ],
            'recommendations' => [
                [
                    'priority' => 'high',
                    'action' => 'Begin emissions data collection immediately',
                    'target_audience' => 'Affected businesses',
                    'deadline' => 'Q2 2024',
                ],
                [
                    'priority' => 'high',
                    'action' => 'Implement ESG reporting infrastructure',
                    'target_audience' => 'Corporate leadership',
                    'deadline' => 'Q3 2024',
                ],
                [
                    'priority' => 'medium',
                    'action' => 'Conduct gap analysis of current practices',
                    'target_audience' => 'Compliance teams',
                    'deadline' => 'Q2 2024',
                ],
                [
                    'priority' => 'medium',
                    'action' => 'Engage with CARB for guidance',
                    'target_audience' => 'Regulatory affairs',
                    'deadline' => 'Q1 2024',
                ],
            ],
            'compliance_score' => [
                'overall' => 72,
                'preparedness' => 65,
                'resources_available' => 78,
                'timeline_feasibility' => 74,
            ],
            'risk_factors' => [
                [
                    'factor' => 'Data availability',
                    'likelihood' => 'high',
                    'impact' => 'high',
                    'mitigation' => 'Implement data collection systems early',
                ],
                [
                    'factor' => 'Third-party verification capacity',
                    'likelihood' => 'medium',
                    'impact' => 'high',
                    'mitigation' => 'Secure verification partners in advance',
                ],
                [
                    'factor' => 'Regulatory changes',
                    'likelihood' => 'medium',
                    'impact' => 'medium',
                    'mitigation' => 'Monitor CARB updates closely',
                ],
            ],
            'metadata' => [
                'analyst_agent' => 'analyst-agent-1',
                'analysis_methodology' => 'comprehensive regulatory assessment',
                'data_sources' => [
                    'CARB guidelines',
                    'Industry benchmarks',
                    'Legal precedents',
                    'Stakeholder input',
                ],
                'confidence_level' => 0.88,
                'timestamp' => '2024-01-22T14:45:00Z',
            ],
        ];
    }

    /**
     * Get validation test cases
     * Provides edge cases and boundary conditions for testing
     */
    public function getValidationTestCases(): array
    {
        return [
            'empty_values' => [
                ['notification_id' => '', 'title' => 'Test'],
                ['notification_id' => 'TEST-001', 'title' => null],
            ],
            'boundary_values' => [
                ['revenue_threshold' => 0],
                ['revenue_threshold' => 999999999],
                ['compliance_cost' => -1], // Invalid
                ['compliance_cost' => 0],
                ['compliance_cost' => 10000000],
            ],
            'format_violations' => [
                ['effective_date' => 'invalid-date'],
                ['effective_date' => '2024-13-01'], // Invalid month
                ['bill_number' => ''],
            ],
            'consistency_checks' => [
                'same_notification_different_sources',
                'overlapping_requirements',
                'conflicting_deadlines',
            ],
        ];
    }
}

# Legislation Analysis Test Suite

Comprehensive test suite for validating findings from the legislation analysis workflow.

## Test Structure

```
tests/legislation-analysis/
├── LegislationAnalysisTestSuite.php      # Main test suite
├── Fixtures/
│   └── LegislationTestData.php          # Test data fixtures
├── Validators/
│   ├── DataAccuracyValidator.php        # Data accuracy validation
│   ├── CoverageValidator.php            # Coverage completeness validation
│   ├── CrossAgentConsistencyValidator.php # Cross-agent consistency validation
│   └── FindingsCompletenessValidator.php # Findings completeness validation
├── phpunit.xml                          # PHPUnit configuration
├── validation-report.json               # Generated validation report
└── README.md                            # This file
```

## Running Tests

### Run All Tests
```bash
cd /mnt/overpower/apps/dev/agl/agl-hostman
./vendor/bin/phpunit tests/legislation-analysis/LegislationAnalysisTestSuite.php
```

### Run with Coverage
```bash
./vendor/bin/phpunit --coverage-html coverage tests/legislation-analysis/LegislationAnalysisTestSuite.php
```

### Run Specific Test
```bash
./vendor/bin/phpunit --filter testCMN4963ResearchDataAccuracy tests/legislation-analysis/LegislationAnalysisTestSuite.php
```

## Test Categories

### 1. Data Accuracy Tests
- `testCMN4963ResearchDataAccuracy()` - Validates CMN-4963 research data
- `testCMN5272ResearchDataAccuracy()` - Validates CMN-5272 research data
- `testComparisonResultsAccuracy()` - Validates comparison results
- `testRegulatoryImpactAccuracy()` - Validates regulatory impact analysis

### 2. Coverage Completeness Tests
- `testCoverageCompleteness()` - Ensures all components are analyzed
- `testPerformanceMetrics()` - Validates performance characteristics

### 3. Cross-Agent Consistency Tests
- `testCrossAgentConsistency()` - Validates findings consistency across agents

### 4. Findings Completeness Tests
- `testFindingsCompleteness()` - Ensures all required fields are present

### 5. Data Integrity Tests
- `testDataIntegrity()` - Validates data integrity across components
- `testEdgeCasesAndBoundaries()` - Tests edge cases and boundary conditions

### 6. Report Generation Tests
- `testGenerateValidationReport()` - Validates report generation

## Validation Report

The test suite generates a comprehensive validation report saved to `validation-report.json`:

```json
{
  "summary": {
    "overall_score": 95.5,
    "total_tests": 10,
    "passed_tests": 9,
    "failed_tests": 1
  },
  "data_accuracy": {
    "cmn4963": { "is_accurate": true, "verified_fields": 14 },
    "cmn5272": { "is_accurate": true, "verified_fields": 14 },
    "comparison": { "is_accurate": true },
    "regulatory": { "is_accurate": true }
  },
  "coverage_completeness": {
    "coverage_percentage": 100,
    "covered_sections": ["CMN-4963", "CMN-5272", "Comparison", "Regulatory"]
  },
  "cross_agent_consistency": {
    "consistency_score": 92.5
  },
  "issues": [],
  "recommendations": []
}
```

## Memory Coordination

This test suite integrates with the legislation analysis workflow through memory coordination:

### Memory Keys Checked
- `swarm/researcher/cmn-4963` - CMN-4963 research findings
- `swarm/researcher/cmn-5272` - CMN-5272 research findings
- `swarm/coder/comparison-results` - Comparison results
- `swarm/analyst/regulatory-impact` - Regulatory impact analysis

### Memory Keys Written
- `swarm/tester/validation-report` - Comprehensive validation report
- `swarm/tester/status` - Test execution status
- `swarm/tester/progress` - Test progress updates

## Requirements

- PHP 8.1+
- PHPUnit 9.5+
- Composer dependencies installed

## Installation

```bash
composer install --dev
```

## Coverage Requirements

- Statements: >80%
- Branches: >75%
- Functions: >80%
- Lines: >80%

## Task Information

- **Task ID**: 0f94812a-d4b3-4654-a4d9-3a0e5e9c9ead
- **Agent**: tester
- **Purpose**: Validate findings from researcher, coder, and analyst agents

## Best Practices

1. Run tests before committing changes
2. Maintain test coverage above 80%
3. Update test data fixtures when legislation changes
4. Review validation reports regularly
5. Address failed tests immediately

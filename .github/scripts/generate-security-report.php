#!/usr/bin/env php
<?php

/**
 * Security Test Report Generator
 *
 * Generates comprehensive security test coverage reports
 * from PHPUnit test results.
 */

$coverageFiles = [
    __DIR__ . '/../../src/coverage-security-unit.xml',
    __DIR__ . '/../../src/coverage-security-feature.xml',
];

$outputFile = __DIR__ . '/../../src/security-report.json';
$htmlOutputFile = __DIR__ . '/../../src/security-report.html';

$report = [
    'timestamp' => date('c'),
    'status' => 'success',
    'tests_total' => 0,
    'assertions' => 0,
    'failures' => 0,
    'errors' => 0,
    'coverage' => [
        'unit' => 0,
        'feature' => 0,
        'overall' => 0,
    ],
    'categories' => [],
    'issues' => [],
];

// Parse coverage files
foreach ($coverageFiles as $index => $file) {
    if (!file_exists($file)) {
        continue;
    }

    $xml = simplexml_load_file($file);
    $metrics = $xml->project->metrics;

    $type = $index === 0 ? 'unit' : 'feature';
    $elements = (int) $metrics['elements'];
    $coveredelements = (int) $metrics['coveredelements'];

    $coverage = $elements > 0 ? ($coveredelements / $elements) * 100 : 0;
    $report['coverage'][$type] = round($coverage, 2);
}

$report['coverage']['overall'] = round(
    ($report['coverage']['unit'] + $report['coverage']['feature']) / 2,
    2
);

// Define security categories
$categories = [
    'Authentication' => [
        'file' => 'AuthenticationSecurityTest.php',
        'target_coverage' => 90,
    ],
    'Authorization' => [
        'file' => 'RbacEnforcementTest.php',
        'target_coverage' => 95,
    ],
    'InputValidation' => [
        'file' => 'InputValidationTest.php',
        'target_coverage' => 85,
    ],
    'CSRF' => [
        'file' => 'CsrfProtectionTest.php',
        'target_coverage' => 90,
    ],
    'SQLInjection' => [
        'file' => 'SqlInjectionTest.php',
        'target_coverage' => 95,
    ],
    'XSS' => [
        'file' => 'XssPreventionTest.php',
        'target_coverage' => 90,
    ],
    'Headers' => [
        'file' => 'SecureHeadersTest.php',
        'target_coverage' => 85,
    ],
    'Secrets' => [
        'file' => 'SecretsManagementTest.php',
        'target_coverage' => 90,
    ],
    'RateLimiting' => [
        'file' => 'RateLimitingTest.php',
        'target_coverage' => 85,
    ],
    'Middleware' => [
        'file' => 'MiddlewareSecurityTest.php',
        'target_coverage' => 90,
    ],
];

// Generate category reports
foreach ($categories as $name => $category) {
    $report['categories'][$name] = [
        'file' => $category['file'],
        'target_coverage' => $category['target_coverage'],
        'status' => 'passed',
    ];

    // Check if target met
    if ($report['coverage']['overall'] < $category['target_coverage']) {
        $report['categories'][$name]['status'] = 'below_target';
        $report['issues'][] = [
            'severity' => 'medium',
            'category' => $name,
            'message' => "Coverage {$report['coverage']['overall']}% below target {$category['target_coverage']}%",
        ];
    }
}

// Determine overall status
if ($report['failures'] > 0 || $report['errors'] > 0) {
    $report['status'] = 'failed';
} elseif ($report['coverage']['overall'] < 80) {
    $report['status'] = 'warning';
}

// Generate grade
$report['grade'] = 'A';
if ($report['coverage']['overall'] < 95) $report['grade'] = 'A-';
if ($report['coverage']['overall'] < 90) $report['grade'] = 'B+';
if ($report['coverage']['overall'] < 85) $report['grade'] = 'B';
if ($report['coverage']['overall'] < 80) $report['grade'] = 'C';
if ($report['coverage']['overall'] < 70) $report['grade'] = 'D';
if ($report['coverage']['overall'] < 60) $report['grade'] = 'F';

// Write JSON report
file_put_contents($outputFile, json_encode($report, JSON_PRETTY_PRINT));

// Generate HTML report
$html = generateHtmlReport($report);
file_put_contents($htmlOutputFile, $html);

echo "Security report generated:\n";
echo "- JSON: {$outputFile}\n";
echo "- HTML: {$htmlOutputFile}\n";
echo "- Overall Status: {$report['status']}\n";
echo "- Grade: {$report['grade']}\n";
echo "- Coverage: {$report['coverage']['overall']}%\n";

exit($report['status'] === 'failed' ? 1 : 0);

function generateHtmlReport(array $report): string
{
    $gradeColors = [
        'A' => '#22c55e',
        'A-' => '#84cc16',
        'B+' => '#a3e635',
        'B' => '#facc15',
        'C' => '#fb923c',
        'D' => '#f87171',
        'F' => '#ef4444',
    ];

    $gradeColor = $gradeColors[$report['grade']] ?? '#6b7280';

    $html = '<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Security Test Report - AGL Infrastructure</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0f172a; color: #e2e8f0; padding: 2rem; }
        .container { max-width: 1200px; margin: 0 auto; }
        .header { text-align: center; margin-bottom: 3rem; }
        .header h1 { font-size: 2.5rem; margin-bottom: 0.5rem; }
        .header p { color: #94a3b8; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 1.5rem; margin-bottom: 3rem; }
        .card { background: #1e293b; border-radius: 12px; padding: 1.5rem; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.3); }
        .card h3 { font-size: 0.875rem; color: #94a3b8; margin-bottom: 0.5rem; text-transform: uppercase; letter-spacing: 0.05em; }
        .card .value { font-size: 2.5rem; font-weight: bold; }
        .card .value.success { color: #22c55e; }
        .card .value.warning { color: #facc15; }
        .card .value.error { color: #ef4444; }
        .grade { display: inline-block; padding: 1rem 2rem; border-radius: 50%; background: '.$gradeColor.'; color: white; font-size: 3rem; font-weight: bold; }
        .coverage-bar { height: 8px; background: #334155; border-radius: 4px; overflow: hidden; margin-top: 1rem; }
        .coverage-bar-fill { height: 100%; background: linear-gradient(90deg, #22c55e, #84cc16); border-radius: 4px; transition: width 0.5s ease; }
        .section { background: #1e293b; border-radius: 12px; padding: 2rem; margin-bottom: 2rem; }
        .section h2 { font-size: 1.5rem; margin-bottom: 1.5rem; }
        .category-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 1rem; }
        .category-item { background: #334155; padding: 1rem; border-radius: 8px; }
        .category-item.passed { border-left: 4px solid #22c55e; }
        .category-item.below_target { border-left: 4px solid #facc15; }
        .category-item h4 { margin-bottom: 0.5rem; }
        .category-item p { font-size: 0.875rem; color: #94a3b8; }
        .issues { margin-top: 2rem; }
        .issue { background: #334155; padding: 1rem; border-radius: 8px; margin-bottom: 1rem; border-left: 4px solid #facc15; }
        .issue.critical { border-left-color: #ef4444; }
        .issue.high { border-left-color: #f87171; }
        .issue.medium { border-left-color: #facc15; }
        .footer { text-align: center; margin-top: 3rem; color: #64748b; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>Security Test Report</h1>
            <p>AGL Infrastructure - Generated ' . $report['timestamp'] . '</p>
        </div>

        <div class="summary">
            <div class="card">
                <h3>Overall Status</h3>
                <div class="value ' . ($report['status'] === 'success' ? 'success' : ($report['status'] === 'warning' ? 'warning' : 'error')) . '">
                    ' . ucfirst($report['status']) . '
                </div>
            </div>
            <div class="card">
                <h3>Security Grade</h3>
                <div class="value" style="color: ' . $gradeColor . '">' . $report['grade'] . '</div>
            </div>
            <div class="card">
                <h3>Coverage</h3>
                <div class="value">' . number_format($report['coverage']['overall'], 1) . '%</div>
                <div class="coverage-bar">
                    <div class="coverage-bar-fill" style="width: ' . $report['coverage']['overall'] . '%"></div>
                </div>
            </div>
        </div>

        <div class="section">
            <h2>Test Categories</h2>
            <div class="category-grid">';

    foreach ($report['categories'] as $name => $category) {
        $html .= '
                <div class="category-item ' . $category['status'] . '">
                    <h4>' . $name . '</h4>
                    <p>Status: ' . ucfirst(str_replace('_', ' ', $category['status'])) . '</p>
                    <p>Target: ' . $category['target_coverage'] . '%</p>
                </div>';
    }

    $html .= '
            </div>
        </div>';

    if (!empty($report['issues'])) {
        $html .= '
        <div class="section">
            <h2>Issues Found</h2>
            <div class="issues">';

        foreach ($report['issues'] as $issue) {
            $html .= '
                <div class="issue ' . $issue['severity'] . '">
                    <strong>' . ucfirst($issue['severity']) . ':</strong> ' . htmlspecialchars($issue['message']) . '
                </div>';
        }

        $html .= '
            </div>
        </div>';
    }

    $html .= '
        <div class="footer">
            <p>Generated by AGL Security Testing Suite | AGl-24 Testing Coverage Improvement</p>
        </div>
    </div>
</body>
</html>';

    return $html;
}

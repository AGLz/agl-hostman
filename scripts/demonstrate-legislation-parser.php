#!/usr/bin/env php
<?php

declare(strict_types=1);

/**
 * Demonstration script for Legislation Parser and Comparison Engine
 *
 * This script demonstrates the functionality of the Brazilian CMN legislation
 * parser and comparison engine for CMN Resolution 4.963 vs 5.272.
 */

// Load Composer autoloader
require_once __DIR__ . '/../src/vendor/autoload.php';

use App\Services\Legislation\LegislationParserService;
use App\Services\Legislation\LegislationComparisonService;
use App\Services\Legislation\CMNResolutionDataProvider;
use App\Services\Legislation\LegislationAnalysisOrchestrator;

// ANSI color codes for terminal output
const COLOR_GREEN = "\033[32m";
const COLOR_BLUE = "\033[34m";
const COLOR_YELLOW = "\033[33m";
const COLOR_RED = "\033[31m";
const COLOR_CYAN = "\033[36m";
const COLOR_RESET = "\033[0m";

function printHeader(string $title): void
{
    echo "\n" . COLOR_CYAN . str_repeat('=', 80) . COLOR_RESET . "\n";
    echo COLOR_CYAN . "  {$title}" . COLOR_RESET . "\n";
    echo COLOR_CYAN . str_repeat('=', 80) . COLOR_RESET . "\n\n";
}

function printSection(string $title): void
{
    echo "\n" . COLOR_BLUE . str_repeat('-', 80) . COLOR_RESET . "\n";
    echo COLOR_BLUE . "  {$title}" . COLOR_RESET . "\n";
    echo COLOR_BLUE . str_repeat('-', 80) . COLOR_RESET . "\n\n";
}

function printSuccess(string $message): void
{
    echo COLOR_GREEN . "✓ {$message}" . COLOR_RESET . "\n";
}

function printInfo(string $message): void
{
    echo COLOR_YELLOW . "ℹ {$message}" . COLOR_RESET . "\n";
}

function printError(string $message): void
{
    echo COLOR_RED . "✗ {$message}" . COLOR_RESET . "\n";
}

function printArray(array $data, int $indent = 0): void
{
    $prefix = str_repeat('  ', $indent);
    foreach ($data as $key => $value) {
        if (is_array($value)) {
            echo $prefix . COLOR_CYAN . $key . COLOR_RESET . ":\n";
            printArray($value, $indent + 1);
        } else {
            echo $prefix . COLOR_CYAN . $key . COLOR_RESET . ": " . (is_bool($value) ? ($value ? 'true' : 'false') : $value) . "\n";
        }
    }
}

// Main execution
try {
    printHeader("Brazilian CMN Legislation Parser and Comparison Engine");
    echo "Task ID: 38b38ad9-013a-433e-b1fc-2bf74360b341\n";
    echo "Agent: coder\n";
    echo "Date: " . date('c') . "\n";

    // Initialize services
    printSection("Step 1: Initializing Services");

    $parser = new LegislationParserService();
    $comparison = new LegislationComparisonService($parser);
    $dataProvider = new CMNResolutionDataProvider();
    $orchestrator = new LegislationAnalysisOrchestrator($parser, $comparison, $dataProvider);

    printSuccess("LegislationParserService initialized");
    printSuccess("LegislationComparisonService initialized");
    printSuccess("CMNResolutionDataProvider initialized");
    printSuccess("LegislationAnalysisOrchestrator initialized");

    // Load CMN data
    printSection("Step 2: Loading CMN Resolutions");

    $cmn4963 = $dataProvider->getCMN4963Data();
    $cmn5272 = $dataProvider->getCMN5272Data();

    printInfo("CMN 4.963 loaded (" . strlen($cmn4963['raw_text']) . " characters)");
    printInfo("CMN 5.272 loaded (" . strlen($cmn5272['raw_text']) . " characters)");

    // Parse resolutions
    printSection("Step 3: Parsing Resolutions");

    $parsed4963 = $parser->parseCMNResolution($cmn4963['raw_text'], '4.963', '2018-01-17');
    printSuccess("CMN 4.963 parsed successfully");
    printInfo("Articles found: " . $parsed4963['structure']['total_articles']);
    printInfo("Requirements extracted: " . count($parsed4963['content']['requirements']));
    printInfo("Limits identified: " . count($parsed4963['content']['limits']));

    $parsed5272 = $parser->parseCMNResolution($cmn5272['raw_text'], '5.272', '2024-02-29');
    printSuccess("CMN 5.272 parsed successfully");
    printInfo("Articles found: " . $parsed5272['structure']['total_articles']);
    printInfo("Requirements extracted: " . count($parsed5272['content']['requirements']));
    printInfo("Limits identified: " . count($parsed5272['content']['limits']));
    printInfo("Governance tiers: " . count($parsed5272['governance']['tiers'] ?? []));

    // Perform comparison
    printSection("Step 4: Comparing Resolutions");

    $comparisonResult = $comparison->compareCMN($parsed4963, $parsed5272);
    printSuccess("Comparison completed successfully");

    printInfo("Differences found: " . count($comparisonResult['differences']));
    printInfo("Similarities found: " . count($comparisonResult['similarities']));
    printInfo("Additions: " . count($comparisonResult['additions']));
    printInfo("Removals: " . count($comparisonResult['removals']));
    printInfo("Modifications: " . count($comparisonResult['modifications']));

    // Display metrics
    printSection("Step 5: Comparison Metrics");

    printArray($comparisonResult['metrics']);

    // Display governance analysis
    printSection("Step 6: Governance Analysis");

    printArray($comparisonResult['governance_analysis']);

    // Display investment analysis
    printSection("Step 7: Investment Analysis");

    printArray($comparisonResult['investment_analysis']);

    // Display compliance analysis
    printSection("Step 8: Compliance Analysis");

    printArray($comparisonResult['compliance_analysis']);

    // Display impact assessment
    printSection("Step 9: Impact Assessment");

    printArray($comparisonResult['impact_assessment']);

    // Display categorized changes
    printSection("Step 10: Categorized Changes");

    foreach ($comparisonResult['categorization'] as $category => $changes) {
        if (!empty($changes)) {
            echo "\n" . COLOR_YELLOW . strtoupper(str_replace('_', ' ', $category)) . " (" . count($changes) . " changes):" . COLOR_RESET . "\n";
            foreach (array_slice($changes, 0, 3) as $change) {
                echo "  • " . ($change['description'] ?? $change['field'] ?? json_encode($change)) . "\n";
            }
            if (count($changes) > 3) {
                echo "  ... and " . (count($changes) - 3) . " more\n";
            }
        }
    }

    // Store results in memory
    printSection("Step 11: Storing Results in Memory");

    // Use absolute path for standalone execution
    $memoryPath = __DIR__ . '/../src/storage/app/memory/swarm/coder';
    if (!is_dir($memoryPath)) {
        mkdir($memoryPath, 0755, true);
    }

    $results = $orchestrator->executeCMNAnalysis(false);
    $memoryFile = $memoryPath . '/comparison-results.json';

    file_put_contents(
        $memoryFile,
        json_encode($results, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE)
    );

    printSuccess("Results stored in memory at: {$memoryFile}");
    printInfo("File size: " . number_format(strlen(json_encode($results))) . " bytes");

    // Generate executive summary
    printSection("Step 12: Executive Summary");

    $summary = $orchestrator->generateExecutiveSummary($results);

    echo "\n" . COLOR_GREEN . "KEY CHANGES:" . COLOR_RESET . "\n";
    foreach ($summary['key_changes'] as $area => $change) {
        echo "  • " . ucwords(str_replace('_', ' ', $area)) . ": {$change}\n";
    }

    echo "\n" . COLOR_GREEN . "STRATEGIC RECOMMENDATIONS:" . COLOR_RESET . "\n";
    foreach ($summary['strategic_recommendations'] as $timeframe => $recommendation) {
        echo "  • " . ucwords(str_replace('_', ' ', $timeframe)) . ": {$recommendation}\n";
    }

    echo "\n" . COLOR_GREEN . "IMPLEMENTATION:" . COLOR_RESET . "\n";
    echo "  • Timeline: " . ($summary['implementation_timeline'] ?? 'N/A') . "\n";
    echo "  • Complexity: " . strtoupper($summary['complexity'] ?? 'N/A') . "\n";
    echo "  • Overall Impact: " . strtoupper($summary['overall_impact'] ?? 'N/A') . "\n";

    // Final summary
    printSection("Summary");

    printSuccess("Analysis completed successfully!");
    printInfo("Total differences: " . count($comparisonResult['differences']));
    printInfo("Total similarities: " . count($comparisonResult['similarities']));
    printInfo("Similarity score: " . round($comparisonResult['metrics']['similarity_score'] * 100, 1) . "%");
    printInfo("Overall alignment: " . strtoupper($comparisonResult['metrics']['overall_alignment'] ?? 'N/A'));

    echo "\n" . COLOR_CYAN . str_repeat('=', 80) . COLOR_RESET . "\n";
    echo COLOR_GREEN . "  Legislation Parser and Comparison Engine Demo Complete!" . COLOR_RESET . "\n";
    echo COLOR_CYAN . str_repeat('=', 80) . COLOR_RESET . "\n\n";

    exit(0);

} catch (Throwable $e) {
    printError("Error: " . $e->getMessage());
    printError("File: " . $e->getFile() . ":" . $e->getLine());
    echo "\nStack trace:\n" . $e->getTraceAsString() . "\n";
    exit(1);
}

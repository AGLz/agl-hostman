<?php

/**
 * Archon MCP Integration Test Script
 *
 * Tests all major MCP tools and verifies integration
 */

require __DIR__.'/vendor/autoload.php';

$app = require_once __DIR__.'/bootstrap/app.php';
$app->make(\Illuminate\Contracts\Console\Kernel::class)->bootstrap();

use App\Services\Archon\ArchonMcpClient;
use App\Services\ArchonMcpService;

echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║        Archon MCP Integration Test Suite                  ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n\n";

$archon = app(ArchonMcpService::class);
$client = app(ArchonMcpClient::class);

$testsPassed = 0;
$testsFailed = 0;

// Test 1: Health Check
echo "Test 1: Health Check\n";
echo str_repeat('-', 60)."\n";
try {
    $health = $archon->healthCheck();
    echo "✓ Health check successful\n";
    echo '  Status: '.($health['status'] ?? 'unknown')."\n";
    echo '  Message: '.($health['message'] ?? 'N/A')."\n";
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Health check failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 2: System Status
echo "Test 2: System Status\n";
echo str_repeat('-', 60)."\n";
try {
    $status = $archon->getStatus();
    echo "✓ Status check successful\n";
    echo '  Service: '.($status['service'] ?? 'unknown')."\n";
    echo '  Version: '.($status['version'] ?? 'unknown')."\n";
    if (isset($status['features'])) {
        echo "  Features:\n";
        foreach ($status['features'] as $feature => $enabled) {
            $icon = $enabled ? '✓' : '✗';
            echo "    {$icon} {$feature}\n";
        }
    }
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Status check failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 3: Knowledge Base - Available Sources
echo "Test 3: Knowledge Base - Available Sources\n";
echo str_repeat('-', 60)."\n";
try {
    $sources = $archon->getAvailableSources();
    echo "✓ Got available sources\n";
    echo '  Count: '.count($sources)."\n";
    if (! empty($sources)) {
        foreach (array_slice($sources, 0, 3) as $source) {
            echo '  - '.($source['title'] ?? $source['id'] ?? 'unknown')."\n";
        }
    }
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Get sources failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 4: Knowledge Base Search
echo "Test 4: Knowledge Base Search\n";
echo str_repeat('-', 60)."\n";
try {
    $results = $archon->searchKnowledgeBase('Laravel', matchCount: 3);
    echo "✓ Knowledge base search successful\n";
    echo '  Results: '.$results->count()."\n";
    foreach ($results->take(2) as $result) {
        echo '  - Title: '.($result->title ?? 'N/A')."\n";
        echo '    Similarity: '.($result->similarity ?? 'N/A')."\n";
    }
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Search failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 5: Get Projects
echo "Test 5: Get Projects\n";
echo str_repeat('-', 60)."\n";
try {
    $projects = $archon->getProjects();
    echo "✓ Got projects\n";
    echo '  Count: '.$projects->count()."\n";
    foreach ($projects->take(3) as $project) {
        echo "  - {$project->title}\n";
        echo "    ID: {$project->id}\n";
        echo "    Created: {$project->createdAt->format('Y-m-d')}\n";
    }
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Get projects failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 6: Get Tasks
echo "Test 6: Get Tasks\n";
echo str_repeat('-', 60)."\n";
try {
    $tasks = $archon->getTasks();
    echo "✓ Got tasks\n";
    echo '  Count: '.$tasks->count()."\n";
    foreach ($tasks->take(3) as $task) {
        echo "  - {$task->title}\n";
        echo "    Status: {$task->status}\n";
        echo '    Assignee: '.($task->assignee ?? 'N/A')."\n";
    }
    $testsPassed++;
} catch (Exception $e) {
    echo '✗ Get tasks failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Test 7: Create Test Project
echo "Test 7: Create Test Project\n";
echo str_repeat('-', 60)."\n";
try {
    $project = $archon->createProject(
        'Test Project - '.date('Y-m-d H:i:s'),
        'Automated test project from Laravel integration',
        'https://github.com/agl/agl-hostman'
    );
    echo "✓ Project created\n";
    echo "  ID: {$project->id}\n";
    echo "  Title: {$project->title}\n";
    $testsPassed++;

    // Test 8: Create Test Task
    echo "\nTest 8: Create Test Task\n";
    echo str_repeat('-', 60)."\n";
    try {
        $task = $archon->createTask(
            $project->id,
            'Test Task - '.date('H:i:s'),
            [
                'description' => 'Automated test task',
                'status' => 'todo',
                'assignee' => 'Test Agent',
            ]
        );
        echo "✓ Task created\n";
        echo "  ID: {$task->id}\n";
        echo "  Title: {$task->title}\n";
        echo "  Status: {$task->status}\n";
        $testsPassed++;

        // Test 9: Update Task Status
        echo "\nTest 9: Update Task Status\n";
        echo str_repeat('-', 60)."\n";
        try {
            $updated = $archon->updateTaskStatus($task->id, 'doing');
            echo "✓ Task status updated\n";
            echo "  New status: {$updated->status}\n";
            $testsPassed++;

            // Cleanup - mark task as done
            $archon->updateTaskStatus($task->id, 'done');
        } catch (Exception $e) {
            echo '✗ Update task failed: '.$e->getMessage()."\n";
            $testsFailed++;
        }
    } catch (Exception $e) {
        echo '✗ Create task failed: '.$e->getMessage()."\n";
        $testsFailed++;
    }

    // Cleanup - delete test project
    echo "\nCleaning up test project...\n";
    try {
        $archon->deleteProject($project->id);
        echo "✓ Test project deleted\n";
    } catch (Exception $e) {
        echo '✗ Cleanup failed: '.$e->getMessage()."\n";
    }
} catch (Exception $e) {
    echo '✗ Create project failed: '.$e->getMessage()."\n";
    $testsFailed++;
}
echo "\n";

// Summary
echo "\n";
echo "╔════════════════════════════════════════════════════════════╗\n";
echo "║                      Test Summary                          ║\n";
echo "╚════════════════════════════════════════════════════════════╝\n";
echo "  ✓ Tests Passed: {$testsPassed}\n";
echo "  ✗ Tests Failed: {$testsFailed}\n";
echo '  Total Tests: '.($testsPassed + $testsFailed)."\n\n";

if ($testsFailed === 0) {
    echo "  🎉 All tests passed! Archon MCP integration is working!\n\n";
    exit(0);
} else {
    echo "  ⚠️  Some tests failed. Check configuration and connectivity.\n\n";
    exit(1);
}

#!/usr/bin/env php
<?php
/**
 * Harbor Image Cleanup Script
 *
 * Removes old Docker images from Harbor registry based on retention policy
 * Supports dry-run mode and selective cleanup
 *
 * Usage: ./cleanup-images.php [options]
 *   --project=NAME         Project name (required)
 *   --repository=NAME      Repository name (optional, all if not specified)
 *   --keep-tags=N          Keep N most recent tags (default: 10)
 *   --keep-days=N          Keep tags from last N days (default: 30)
 *   --keep-latest          Keep latest tag always
 *   --untagged-only        Only remove untagged artifacts
 *   --dry-run              Show what would be deleted without deleting
 *   --min-size=MB          Minimum artifact size in MB (default: 100)
 */

$baseDir = dirname(__DIR__, 5);
require_once $baseDir . '/vendor/autoload.php';

use App\Services\HarborApiClient;

// Parse arguments
$options = getopt('', [
    'project:',
    'repository:',
    'keep-tags:',
    'keep-days:',
    'keep-latest',
    'untagged-only',
    'dry-run',
    'min-size:',
]);

// Validate required options
if (!isset($options['project'])) {
    fwrite(STDERR, "Error: --project is required\n");
    exit(1);
}

// Extract options
$projectName = $options['project'];
$repositoryName = $options['repository'] ?? null;
$keepTags = (int) ($options['keep-tags'] ?? 10);
$keepDays = (int) ($options['keep-days'] ?? 30);
$keepLatest = isset($options['keep-latest']);
$untaggedOnly = isset($options['untagged-only']);
$dryRun = isset($options['dry-run']);
$minSizeMB = (int) ($options['min-size'] ?? 100);

echo "Harbor Image Cleanup Script\n";
echo "============================\n";
echo "Project: $projectName\n";
if ($repositoryName) {
    echo "Repository: $repositoryName\n";
}
echo "Keep tags: $keepTags\n";
echo "Keep days: $keepDays\n";
echo "Keep latest: " . ($keepLatest ? 'Yes' : 'No') . "\n";
echo "Untagged only: " . ($untaggedOnly ? 'Yes' : 'No') . "\n";
echo "Min size: {$minSizeMB}MB\n";
echo "Dry run: " . ($dryRun ? 'Yes' : 'No') . "\n";
echo "\n";

try {
    $harbor = new HarborApiClient();

    // Get project
    $response = $harbor->get('/projects', ['name' => $projectName]);
    if (!$response->isSuccess() || empty($response->data)) {
        fwrite(STDERR, "Error: Project not found: $projectName\n");
        exit(1);
    }

    $projectId = $response->data[0]['project_id'];
    echo "Project ID: $projectId\n";

    // Get repositories
    $endpoint = "/projects/$projectId/repositories";
    $response = $harbor->get($endpoint);

    if (!$response->isSuccess()) {
        fwrite(STDERR, "Error: Cannot list repositories\n");
        exit(1);
    }

    $repositories = $response->data;

    // Filter by repository if specified
    if ($repositoryName) {
        $repositories = array_filter($repositories, function($repo) use ($repositoryName) {
            return $repo['name'] === $repositoryName || str_ends_with($repo['name'], "/$repositoryName");
        });

        if (empty($repositories)) {
            fwrite(STDERR, "Error: Repository not found: $repositoryName\n");
            exit(1);
        }
    }

    echo "Found " . count($repositories) . " repositories\n\n";

    $totalSize = 0;
    $totalDeleted = 0;

    foreach ($repositories as $repository) {
        $repoName = $repository['name'];
        $repoProject = $repository['project_id'];
        echo "Repository: $repoName\n";

        // Get artifacts
        $artifactResponse = $harbor->get("/projects/$repoProject/repositories/" . urlencode($repoName) . '/artifacts');

        if (!$artifactResponse->isSuccess()) {
            echo "  Error: Cannot fetch artifacts\n";
            continue;
        }

        $artifacts = $artifactResponse->data;
        echo "  Artifacts: " . count($artifacts) . "\n";

        // Filter and sort artifacts
        $toDelete = [];
        $toKeep = [];

        foreach ($artifacts as $artifact) {
            $tags = $artifact['tags'] ?? [];
            $pushedAt = new \DateTime($artifact['pushed_at']);
            $sizeBytes = $artifact['size'] ?? 0;
            $sizeMB = $sizeBytes / (1024 * 1024);

            // Skip if too small
            if ($sizeMB < $minSizeMB) {
                continue;
            }

            // Determine if should keep
            $keep = false;
            $reason = '';

            // Keep latest tag if requested
            if ($keepLatest && in_array('latest', array_column($tags, 'name'))) {
                $keep = true;
                $reason = 'latest tag';
            }

            // Keep if within days window
            $daysOld = (new \DateTime())->diff($pushedAt)->days;
            if ($daysOld <= $keepDays) {
                $keep = true;
                $reason = "within {$keepDays} days";
            }

            // Keep if has tags (unless untagged-only mode)
            if (!$untaggedOnly && !empty($tags)) {
                $keep = true;
                $reason = 'has tags';
            }

            if ($keep) {
                $toKeep[] = [
                    'digest' => $artifact['digest'],
                    'tags' => array_column($tags, 'name'),
                    'size_mb' => round($sizeMB, 2),
                    'reason' => $reason,
                ];
            } else {
                $toDelete[] = [
                    'digest' => $artifact['digest'],
                    'tags' => array_column($tags, 'name'),
                    'size_mb' => round($sizeMB, 2),
                    'pushed_at' => $artifact['pushed_at'],
                ];
            }
        }

        // Sort to keep by tags (most recent first)
        usort($toKeep, function($a, $b) {
            return count($a['tags']) <=> count($b['tags']);
        });

        // Keep only N tags
        if (count($toKeep) > $keepTags) {
            $excess = array_slice($toKeep, $keepTags);
            $toDelete = array_merge($toDelete, $excess);
            $toKeep = array_slice($toKeep, 0, $keepTags);
        }

        echo "  Keeping: " . count($toKeep) . "\n";
        echo "  Deleting: " . count($toDelete) . "\n";

        // Delete artifacts
        foreach ($toDelete as $artifact) {
            $digest = $artifact['digest'];
            $sizeMB = $artifact['size_mb'];
            $tags = $artifact['tags'] ?? ['untagged'];

            echo "    - $digest ($sizeMB MB) [" . implode(', ', $tags) . "]";

            if ($dryRun) {
                echo " [DRY-RUN]\n";
            } else {
                $response = $harbor->delete("/projects/$repoProject/repositories/" . urlencode($repoName) . "/artifacts/$digest");

                if ($response->isSuccess()) {
                    echo " [DELETED]\n";
                    $totalDeleted++;
                    $totalSize += $sizeMB;
                } else {
                    echo " [FAILED: {$response->error}]\n";
                }
            }
        }

        echo "\n";
    }

    echo "========================================\n";
    echo "Summary:\n";
    echo "  Total deleted: $totalDeleted\n";
    echo "  Total space freed: " . round($totalSize, 2) . " MB\n";
    echo "========================================\n";

    if ($dryRun) {
        echo "\n[DRY RUN] No actual deletions performed\n";
    }

    exit(0);
} catch (\Exception $e) {
    fwrite(STDERR, "Error: {$e->getMessage()}\n");
    exit(1);
}

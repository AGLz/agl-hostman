<?php

declare(strict_types=1);

namespace App\Jobs\Archon;

use App\Services\ArchonMcpService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\File;
use Illuminate\Support\Facades\Log;

/**
 * Index this application's documentation to Archon knowledge base
 */
class IndexKnowledgeBaseJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $timeout = 300;

    public function __construct(
        private readonly string $documentationPath = '/docs',
        private readonly array $options = []
    ) {}

    public function handle(ArchonMcpService $archon): void
    {
        try {
            $docsPath = base_path('docs');

            if (!File::isDirectory($docsPath)) {
                Log::warning('Documentation directory not found', ['path' => $docsPath]);
                return;
            }

            // Get list of markdown files
            $files = File::glob($docsPath . '/*.md');

            if (empty($files)) {
                Log::info('No markdown files found to index');
                return;
            }

            Log::info('Starting documentation indexing', [
                'path' => $docsPath,
                'files_count' => count($files),
            ]);

            // For now, we'll index the main docs URL if available
            // In production, you'd want to deploy these docs to a web server first
            $webUrl = config('app.url');
            $docsUrl = $webUrl . '/docs';

            $result = $archon->addKnowledgeSource($docsUrl, array_merge([
                'name' => 'AGL-HostMan Laravel Application Docs',
                'description' => 'Infrastructure management platform documentation',
                'knowledge_type' => 'technical',
                'tags' => ['laravel', 'infrastructure', 'api', 'documentation'],
                'max_depth' => 2,
            ], $this->options));

            Log::info('Documentation indexing initiated', [
                'url' => $docsUrl,
                'progress_id' => $result['progressId'] ?? null,
            ]);

        } catch (\Exception $e) {
            Log::error('Documentation indexing failed', [
                'error' => $e->getMessage(),
                'path' => $this->documentationPath,
            ]);
            throw $e;
        }
    }
}

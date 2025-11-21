<?php

declare(strict_types=1);

namespace App\Console\Commands;

use App\Services\ArchonMcpService;
use Illuminate\Console\Command;

/**
 * Check Archon MCP server health and connectivity
 */
class ArchonHealthCheckCommand extends Command
{
    protected $signature = 'archon:health
                          {--detailed : Show detailed information}';

    protected $description = 'Check Archon MCP server health and connectivity';

    public function handle(ArchonMcpService $archon): int
    {
        $this->info('Archon MCP Health Check');
        $this->info('======================');
        $this->newLine();

        // Configuration
        $this->info('Configuration:');
        $this->line('  Enabled: ' . (config('archon.enabled') ? '✓ Yes' : '✗ No'));
        $this->line('  MCP URL: ' . config('archon.mcp_url'));
        $this->line('  Web URL: ' . config('archon.web_url'));
        $this->line('  Timeout: ' . config('archon.timeout') . 's');
        $this->line('  Cache Enabled: ' . (config('archon.cache_enabled') ? 'Yes' : 'No'));
        $this->line('  Sync Enabled: ' . (config('archon.sync_enabled') ? 'Yes' : 'No'));
        $this->newLine();

        if (!config('archon.enabled')) {
            $this->warn('Archon integration is disabled');
            return self::SUCCESS;
        }

        // Connectivity Test
        $this->info('Connectivity Test:');
        try {
            $startTime = microtime(true);
            $pingResult = $archon->ping();
            $duration = round((microtime(true) - $startTime) * 1000, 2);

            if ($pingResult) {
                $this->line("  ✓ Connection successful ({$duration}ms)");
            } else {
                $this->error('  ✗ Connection failed');
                return self::FAILURE;
            }
        } catch (\Exception $e) {
            $this->error('  ✗ Connection failed: ' . $e->getMessage());
            return self::FAILURE;
        }
        $this->newLine();

        // Health Check
        $this->info('Health Check:');
        try {
            $health = $archon->healthCheck();
            $this->line('  Status: ' . ($health['status'] ?? 'unknown'));
            $this->line('  Message: ' . ($health['message'] ?? 'N/A'));

            if ($this->option('detailed') && isset($health['details'])) {
                $this->newLine();
                $this->line('  Details:');
                foreach ($health['details'] as $key => $value) {
                    $this->line("    - {$key}: {$value}");
                }
            }
        } catch (\Exception $e) {
            $this->error('  ✗ Health check failed: ' . $e->getMessage());
        }
        $this->newLine();

        // System Status
        $this->info('System Status:');
        try {
            $status = $archon->getStatus();
            $this->line('  Service: ' . ($status['service'] ?? 'unknown'));
            $this->line('  Version: ' . ($status['version'] ?? 'unknown'));

            if (isset($status['features'])) {
                $this->newLine();
                $this->line('  Available Features:');
                foreach ($status['features'] as $feature => $enabled) {
                    $icon = $enabled ? '✓' : '✗';
                    $this->line("    {$icon} {$feature}");
                }
            }

            if ($this->option('detailed') && isset($status['knowledge_base'])) {
                $this->newLine();
                $this->line('  Knowledge Base:');
                $kb = $status['knowledge_base'];
                $this->line('    - Sources: ' . ($kb['sources_count'] ?? 0));
                $this->line('    - Documents: ' . ($kb['documents_count'] ?? 0));
                $this->line('    - Chunks: ' . ($kb['chunks_count'] ?? 0));
            }
        } catch (\Exception $e) {
            $this->error('  ✗ Status check failed: ' . $e->getMessage());
        }
        $this->newLine();

        // Available Tools
        $this->info('Available MCP Tools:');
        $tools = config('archon.tools', []);
        foreach ($tools as $category => $categoryTools) {
            $this->line("  {$category} (" . count($categoryTools) . ' tools)');
            if ($this->option('detailed')) {
                foreach ($categoryTools as $tool) {
                    $this->line("    - {$tool}");
                }
            }
        }

        $this->newLine();
        $this->info('✓ Health check completed');

        return self::SUCCESS;
    }
}

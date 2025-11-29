<?php

namespace App\Console\Commands;

use App\Services\Health\HealthCheckService;
use Illuminate\Console\Command;

class HealthCheck extends Command
{
    protected $signature = 'health:check {--json : Output as JSON}';
    protected $description = 'Run comprehensive health checks on the application';

    public function handle(HealthCheckService $healthCheck): int
    {
        $this->info('Running health checks...');
        $this->newLine();

        $results = $healthCheck->checkAll();

        if ($this->option('json')) {
            $this->line(json_encode($results, JSON_PRETTY_PRINT));
            return $results['healthy'] ? 0 : 1;
        }

        // Display results in table format
        $rows = array_map(function ($check) {
            $statusIcon = match ($check['status']) {
                'healthy' => '<fg=green>✓</>',
                'warning' => '<fg=yellow>⚠</>',
                'unhealthy' => '<fg=red>✗</>',
                default => '?',
            };

            $severityBadge = match ($check['severity']) {
                'critical' => '<fg=red>[CRITICAL]</>',
                'important' => '<fg=yellow>[IMPORTANT]</>',
                'optional' => '<fg=gray>[OPTIONAL]</>',
                default => '',
            };

            return [
                $statusIcon,
                $check['name'],
                $check['message'],
                $severityBadge,
            ];
        }, $results['checks']);

        $this->table(
            ['Status', 'Check', 'Message', 'Severity'],
            $rows
        );

        $this->newLine();

        if ($results['healthy']) {
            $this->info('✅ All health checks passed!');
            return 0;
        } else {
            $this->error('❌ Some health checks failed');

            $critical = array_filter($results['checks'], fn($c) =>
                $c['status'] === 'unhealthy' && $c['severity'] === 'critical'
            );

            if (!empty($critical)) {
                $this->newLine();
                $this->error('Critical Issues:');
                foreach ($critical as $issue) {
                    $this->error("  - {$issue['name']}: {$issue['message']}");
                }
            }

            return 1;
        }
    }
}

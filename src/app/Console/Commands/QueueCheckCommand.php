<?php

namespace App\Console\Commands;

use App\Services\QueueMonitoringService;
use Illuminate\Console\Command;

class QueueCheckCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'queue:check
                            {--alert : Send alerts if issues found}
                            {--snapshot : Create queue health snapshot}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Check queue health and metrics';

    /**
     * The queue monitoring service.
     */
    protected QueueMonitoringService $monitoring;

    /**
     * Create a new command instance.
     */
    public function __construct(QueueMonitoringService $monitoring)
    {
        parent::__construct();
        $this->monitoring = $monitoring;
    }

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $this->info('Checking queue health...');

        // Get queue health
        $health = $this->monitoring->checkQueueHealth();

        // Display metrics
        $this->displayMetrics($health['metrics']);

        // Display issues
        if (!empty($health['issues'])) {
            $this->newLine();
            $this->warn('Issues Found:');
            foreach ($health['issues'] as $issue) {
                $this->displayIssue($issue);
            }
        } else {
            $this->newline();
            $this->info('No issues detected.');
        }

        // Create snapshot if requested
        if ($this->option('snapshot')) {
            $this->monitoring->takeQueueHealthSnapshot();
            $this->info('Queue health snapshot created.');
        }

        // Send alerts if requested and issues found
        if ($this->option('alert') && !empty($health['issues'])) {
            $this->monitoring->sendQueueAlert($health['issues']);
            $this->info('Alerts sent for detected issues.');
        }

        // Return exit code based on health status
        return $health['status'] === 'critical' ? 1 : 0;
    }

    /**
     * Display queue metrics.
     */
    protected function displayMetrics(array $metrics): void
    {
        $this->table(
            ['Metric', 'Value'],
            [
                ['Status', ucfirst($this->monitoring->checkQueueHealth()['status'])],
                ['Pending Jobs', number_format($metrics['pending_jobs'] ?? 0)],
                ['Processing Jobs', number_format($metrics['processing_jobs'] ?? 0)],
                ['Failed Jobs', number_format($metrics['failed_jobs'] ?? 0)],
                ['Completed Today', number_format($metrics['completed_jobs_today'] ?? 0)],
                ['Avg Wait Time', number_format($metrics['avg_wait_time'] ?? 0, 2) . 's'],
            ]
        );
    }

    /**
     * Display individual issue.
     */
    protected function displayIssue(array $issue): void
    {
        switch ($issue['type']) {
            case 'high_failed_count':
                $this->error(
                    "High Failed Job Count: {$issue['count']} (threshold: {$issue['threshold']})"
                );
                break;

            case 'queue_backlog':
                $this->warn('Queue Backlog:');
                foreach ($issue['queues'] as $queue) {
                    $this->line(
                        "  - {$queue['queue']}: {$queue['pending_count']} " .
                        "(threshold: {$queue['threshold']})"
                    );
                }
                break;

            case 'long_running_jobs':
                $this->warn('Long Running Jobs:');
                foreach ($issue['jobs'] as $job) {
                    $this->line(
                        "  - {$job['job']} on queue '{$job['queue']}': " .
                        "{$job['duration_minutes']} minutes"
                    );
                }
                break;
        }
    }
}

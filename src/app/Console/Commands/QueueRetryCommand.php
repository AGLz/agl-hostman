<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;

class QueueRetryCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'queue:retry-failed
                            {--queue= : Filter by queue}
                            {--job= : Filter by job type}
                            {--limit=10 : Maximum number of jobs to retry}
                            {--all : Retry all failed jobs}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Retry failed queue jobs with filtering options';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $queueFilter = $this->option('queue');
        $jobFilter = $this->option('job');
        $limit = $this->option('all') ? null : (int) $this->option('limit');

        $this->info('Finding failed jobs to retry...');

        // Build query
        $query = DB::table('failed_jobs');

        if ($queueFilter) {
            $query->where('queue', $queueFilter);
            $this->info("Filtering by queue: {$queueFilter}");
        }

        // Get failed jobs
        $failedJobs = $query->orderBy('failed_at', 'desc')->get();

        if ($jobFilter) {
            $this->info("Filtering by job type: {$jobFilter}");
            $failedJobs = $failedJobs->filter(function ($job) use ($jobFilter) {
                $payload = json_decode($job->payload, true);
                $displayName = $payload['displayName'] ?? '';

                return str_contains($displayName, $jobFilter);
            });
        }

        if ($limit) {
            $failedJobs = $failedJobs->take($limit);
        }

        $count = $failedJobs->count();

        if ($count === 0) {
            $this->warn('No failed jobs found matching criteria.');

            return 0;
        }

        $this->info("Found {$count} failed job(s) to retry.");

        if (! $this->confirm('Proceed with retry?')) {
            $this->info('Cancelled.');

            return 0;
        }

        // Retry each job
        $retried = 0;
        $failed = 0;

        foreach ($failedJobs as $job) {
            $payload = json_decode($job->payload, true);
            $displayName = $payload['displayName'] ?? 'Unknown';

            $this->line("Retrying: {$displayName}");

            try {
                // Retry using Laravel's queue retry command
                Artisan::call('queue:retry', ['id' => $job->id]);
                $retried++;
            } catch (\Exception $e) {
                $this->error("Failed to retry job {$job->id}: {$e->getMessage()}");
                $failed++;
            }
        }

        $this->newLine();
        $this->info("Successfully retried: {$retried}");
        if ($failed > 0) {
            $this->error("Failed to retry: {$failed}");
        }

        return $failed > 0 ? 1 : 0;
    }
}

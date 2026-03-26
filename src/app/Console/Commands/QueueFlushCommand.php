<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;

class QueueFlushCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'queue:flush
                            {queue? : Specific queue to flush (default: all)}
                            {--force : Force flush without confirmation}
                            {--failed : Flush failed jobs}
                            {--pending : Flush pending jobs}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Flush queue jobs (pending or failed)';

    /**
     * Execute the console command.
     */
    public function handle(): int
    {
        $queue = $this->argument('queue');
        $flushFailed = $this->option('failed');
        $flushPending = $this->option('pending');

        // Default to flushing both if no specific option
        if (! $flushFailed && ! $flushPending) {
            $flushFailed = true;
            $flushPending = true;
        }

        $this->info('Flushing queue: '.($queue ?? 'all'));

        if ($flushFailed) {
            $this->flushFailedJobs($queue);
        }

        if ($flushPending) {
            $this->flushPendingJobs($queue);
        }

        return 0;
    }

    /**
     * Flush failed jobs.
     */
    protected function flushFailedJobs(?string $queue): void
    {
        $query = DB::table('failed_jobs');

        if ($queue) {
            $query->where('queue', $queue);
        }

        $count = $query->count();

        if ($count === 0) {
            $this->info('No failed jobs to flush.');

            return;
        }

        if (! $this->confirm("Delete {$count} failed jobs?", $this->option('force'))) {
            $this->info('Skipped failed jobs.');

            return;
        }

        $query->delete();
        $this->info("Deleted {$count} failed jobs.");
    }

    /**
     * Flush pending jobs from Redis.
     */
    protected function flushPendingJobs(?string $queue): void
    {
        $redis = Redis::connection();
        $queues = $queue ? [$queue] : $this->getAllQueues();
        $totalDeleted = 0;

        foreach ($queues as $q) {
            $key = 'queues:'.$q;
            $count = $redis->llen($key);

            if ($count > 0) {
                $this->info("Queue '{$q}' has {$count} pending jobs.");

                if ($this->option('force') || $this->confirm("Flush {$count} jobs from queue '{$q}'?")) {
                    $redis->del($key);
                    $totalDeleted += $count;
                    $this->info("Flushed {$count} jobs from queue '{$q}'.");
                }
            }
        }

        if ($totalDeleted === 0) {
            $this->info('No pending jobs to flush.');
        } else {
            $this->info("Flushed {$totalDeleted} pending jobs total.");
        }
    }

    /**
     * Get all configured queues.
     */
    protected function getAllQueues(): array
    {
        $queues = [];
        $environment = config('horizon.environments.'.config('app.env'), []);

        foreach ($environment as $supervisor) {
            $supervisorQueues = is_array($supervisor['queue'])
                ? $supervisor['queue']
                : [$supervisor['queue']];
            $queues = array_merge($queues, $supervisorQueues);
        }

        return array_unique($queues);
    }
}

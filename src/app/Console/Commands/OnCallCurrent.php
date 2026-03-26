<?php

namespace App\Console\Commands;

use App\Models\OnCallSchedule;
use Illuminate\Console\Command;

class OnCallCurrent extends Command
{
    protected $signature = 'oncall:current';

    protected $description = 'Display current on-call engineer';

    public function handle(): int
    {
        $current = OnCallSchedule::query()
            ->where('start_time', '<=', now())
            ->where('end_time', '>=', now())
            ->orderBy('is_override', 'desc')
            ->first();

        if (! $current) {
            $this->warn('No one is currently on-call');

            return self::SUCCESS;
        }

        $this->info('=== Current On-Call ===');
        $this->table(
            ['Field', 'Value'],
            [
                ['Engineer', $current->engineer_name],
                ['Email', $current->engineer_email],
                ['Started', $current->start_time->format('Y-m-d H:i:s')],
                ['Ends', $current->end_time->format('Y-m-d H:i:s')],
                ['Time Remaining', $current->end_time->diffForHumans()],
                ['Override', $current->is_override ? 'Yes' : 'No'],
            ]
        );

        // Next rotation
        $next = OnCallSchedule::query()
            ->where('start_time', '>', now())
            ->orderBy('start_time')
            ->first();

        if ($next) {
            $this->newLine();
            $this->info('=== Next Rotation ===');
            $this->line("Engineer: {$next->engineer_name}");
            $this->line("Starts: {$next->start_time->format('Y-m-d H:i:s')} ({$next->start_time->diffForHumans()})");
        }

        return self::SUCCESS;
    }
}

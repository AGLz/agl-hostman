<?php

namespace App\Console\Commands;

use App\Events\Notifications\OnCallRotation;
use App\Models\OnCallSchedule;
use Illuminate\Console\Command;

class OnCallRotate extends Command
{
    protected $signature = 'oncall:rotate {engineer} {email} {--hours=168}';
    protected $description = 'Manually trigger on-call rotation';

    public function handle(): int
    {
        $current = OnCallSchedule::query()
            ->where('start_time', '<=', now())
            ->where('end_time', '>=', now())
            ->first();

        $previousEngineer = $current?->engineer_name;

        if ($current) {
            $current->update(['end_time' => now()]);
            $this->info("Ended current shift for: {$current->engineer_name}");
        }

        $schedule = OnCallSchedule::create([
            'engineer_name' => $this->argument('engineer'),
            'engineer_email' => $this->argument('email'),
            'start_time' => now(),
            'end_time' => now()->addHours($this->option('hours')),
            'is_override' => false,
        ]);

        event(new OnCallRotation($schedule, $previousEngineer));

        $this->info("✅ On-call rotation completed");
        $this->info("Current on-call: {$schedule->engineer_name}");
        $this->info("Until: {$schedule->end_time->format('Y-m-d H:i:s')}");

        return self::SUCCESS;
    }
}

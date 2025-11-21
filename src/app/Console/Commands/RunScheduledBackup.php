<?php

namespace App\Console\Commands;

use App\Jobs\PerformBackup;
use Illuminate\Console\Command;

class RunScheduledBackup extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'backup:run 
                            {type=full : Type of backup (full, database, files, config)}
                            {--notify : Send notification on completion}
                            {--email= : Email address for notification}';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'Run a scheduled backup';

    /**
     * Execute the console command.
     */
    public function handle()
    {
        $type = $this->argument('type');
        $notify = $this->option('notify');
        $email = $this->option('email');
        
        $this->info("Starting {$type} backup...");
        
        dispatch(new PerformBackup($type, $notify, $email));
        
        $this->info("Backup job queued successfully.");
        
        return Command::SUCCESS;
    }
}
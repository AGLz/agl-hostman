<?php

use Illuminate\Support\Str;

return [

    /*
    |--------------------------------------------------------------------------
    | Horizon Domain
    |--------------------------------------------------------------------------
    |
    | This is the subdomain where Horizon will be accessible from. If this
    | setting is null, Horizon will reside under the same domain as the
    | application. Otherwise, this value will serve as the subdomain.
    |
    */

    'domain' => env('HORIZON_DOMAIN', null),

    /*
    |--------------------------------------------------------------------------
    | Horizon Path
    |--------------------------------------------------------------------------
    |
    | This is the URI path where Horizon will be accessible from. Feel free
    | to change this path to anything you like. Note that the URI will not
    | affect the paths of its internal API that aren't exposed to users.
    |
    */

    'path' => env('HORIZON_PATH', 'horizon'),

    /*
    |--------------------------------------------------------------------------
    | Horizon Redis Connection
    |--------------------------------------------------------------------------
    |
    | This is the name of the Redis connection where Horizon will store the
    | master information such as worker status, tag monitoring, job
    | payloads, failed jobs, metrics, and other queue state.
    |
    */

    'use' => 'default',

    /*
    |--------------------------------------------------------------------------
    | Queue Worker Configuration
    |--------------------------------------------------------------------------
    |
    | Here you may define the queue worker settings used by your application
    | in each environment. This includes the supervisor configuration with
    | the number of workers, balance settings, and queue priorities.
    |
    */

    'environments' => [
        'production' => [
            'supervisor-1' => [
                'connection' => 'redis',
                'queue' => ['critical', 'high', 'default'],
                'balance' => 'auto',
                'maxProcesses' => 10,
                'maxTime' => 0,
                'maxJobs' => 1000,
                'memory' => 256,
                'tries' => 3,
                'timeout' => 300,
            ],
            'supervisor-2' => [
                'connection' => 'redis',
                'queue' => ['health-checks', 'metrics-collection'],
                'balance' => 'auto',
                'maxProcesses' => 5,
                'maxTime' => 0,
                'maxJobs' => 500,
                'memory' => 128,
                'tries' => 3,
                'timeout' => 180,
            ],
            'supervisor-3' => [
                'connection' => 'redis',
                'queue' => ['security-scans', 'deployments', 'backups'],
                'balance' => 'auto',
                'maxProcesses' => 3,
                'maxTime' => 0,
                'maxJobs' => 100,
                'memory' => 512,
                'tries' => 2,
                'timeout' => 600,
            ],
            'supervisor-4' => [
                'connection' => 'redis',
                'queue' => ['cleanup', 'notifications'],
                'balance' => 'auto',
                'maxProcesses' => 2,
                'maxTime' => 0,
                'maxJobs' => 200,
                'memory' => 128,
                'tries' => 2,
                'timeout' => 600,
            ],
        ],

        'local' => [
            'supervisor-1' => [
                'connection' => 'redis',
                'queue' => ['default'],
                'balance' => 'auto',
                'maxProcesses' => 3,
                'maxTime' => 0,
                'maxJobs' => 100,
                'memory' => 128,
                'tries' => 3,
                'timeout' => 60,
            ],
        ],

        'staging' => [
            'supervisor-1' => [
                'connection' => 'redis',
                'queue' => ['critical', 'high', 'default', 'health-checks', 'metrics-collection'],
                'balance' => 'auto',
                'maxProcesses' => 5,
                'maxTime' => 0,
                'maxJobs' => 500,
                'memory' => 256,
                'tries' => 3,
                'timeout' => 300,
            ],
            'supervisor-2' => [
                'connection' => 'redis',
                'queue' => ['security-scans', 'deployments', 'backups', 'cleanup', 'notifications'],
                'balance' => 'auto',
                'maxProcesses' => 2,
                'maxTime' => 0,
                'maxJobs' => 100,
                'memory' => 256,
                'tries' => 2,
                'timeout' => 600,
            ],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Trim Settings
    |--------------------------------------------------------------------------
    |
    | Here you may configure how often Horizon should trim old job and
    | monitoring data from storage. This helps keep your database clean
    | and prevents it from growing too large over time.
    |
    */

    'trim' => [
        'recent' => 60,           // Keep recent jobs for 60 minutes
        'recent_failed' => 10080, // Keep failed jobs for 7 days (10080 minutes)
        'monitored' => 4320,      // Keep monitored jobs for 3 days (4320 minutes)
        'pending' => 60,          // Keep pending jobs for 60 minutes
        'completed' => 10080,     // Keep completed jobs for 7 days
        'failed' => 20160,        // Keep failed jobs for 14 days (20160 minutes)
    ],

    /*
    |--------------------------------------------------------------------------
    | Metrics Storage Duration
    |--------------------------------------------------------------------------
    |
    | Here you may configure how long (in minutes) Horizon metrics should
    | be stored. These metrics include job throughput, wait times, and
    | other performance indicators.
    |
    */

    'metrics' => [
        'trim_slugs' => 4320,     // 3 days in minutes
        'store_jobs' => 10080,    // 7 days in minutes
    ],

    /*
    |--------------------------------------------------------------------------
    | Fast Termination
    |--------------------------------------------------------------------------
    |
    | When this option is enabled, Horizon will immediately terminate workers
    | when the master process receives a termination signal. This can be
    | useful during deployment to ensure all workers stop promptly.
    |
    */

    'fast_termination' => false,

    /*
    |--------------------------------------------------------------------------
    | Middleware
    |--------------------------------------------------------------------------
    |
    | These middleware will get attached onto each Horizon route, giving you
    | the chance to add your own middleware to this list or change any of
    | the existing middleware. Or, you can simply stick with this list.
    |
    */

    'middleware' => [
        'web',
        'auth',
    ],

    /*
    |--------------------------------------------------------------------------
    | Authentication Guard
    |--------------------------------------------------------------------------
    |
    | Here you may define the authentication guard that Horizon will use
    | to authenticate users. This guards the Horizon dashboard and API.
    |
    */

    'auth' => true,

    /*
    |--------------------------------------------------------------------------
    | Authentication Policy
    |
    | Here you may define the authentication policy that should be used
    | to determine if a user can access Horizon. This is useful for
    | role-based access control.
    |
    */

    'auth_policy' => \App\Policies\HorizonPolicy::class,

    /*
    |--------------------------------------------------------------------------
    | Silent Workers
    |--------------------------------------------------------------------------
    |
    | When silent mode is enabled, workers will suppress output to the
    | console. This can be useful in production environments where you
    | want to minimize console output.
    |
    */

    'silent' => env('HORIZON_SILENT', false),

    /*
    |--------------------------------------------------------------------------
    | Only Redis Queue Drivers
    |--------------------------------------------------------------------------
    |
    | This option determines if Horizon should only work with Redis queue
    | drivers. When enabled, other queue drivers will be rejected.
    |
    */

    'only' => env('HORIZON_ONLY_REDIS', false),

    /*
    |--------------------------------------------------------------------------
    | Dark Mode
    |--------------------------------------------------------------------------
    |
    | This option controls the default theme for Horizon dashboard. You
    | may set this to 'true' to enable dark mode by default.
    |
    */

    'dark' => env('HORIZON_DARK_MODE', true),

    /*
    |--------------------------------------------------------------------------
    | Watching
    |--------------------------------------------------------------------------
    |
    | The following options configure which job tags and queues should be
    | monitored in the Horizon dashboard. This allows you to track
    | specific jobs for debugging and monitoring purposes.
    |
    */

    'watch' => [
        'tags' => ['critical', 'deploy', 'backup', 'security', 'health-check'],
        'queues' => ['critical', 'high', 'backups', 'deployments', 'security-scans'],
    ],

    /*
    |--------------------------------------------------------------------------
    | Notifications
    |--------------------------------------------------------------------------
    |
    | Here you may configure how you want to be notified when certain
    | events happen within your queue system, such as long waits or
    | high failed job counts.
    |
    */

    'notifications' => [
        'long_wait_detected' => [
            'threshold' => 300, // 5 minutes
            'enabled' => env('HORIZON_NOTIFICATION_LONG_WAIT', true),
        ],
        'high_failed_job_count' => [
            'threshold' => 100,
            'enabled' => env('HORIZON_NOTIFICATION_HIGH_FAILED', true),
        ],
        'queue_processing_slow' => [
            'threshold' => 100, // 100 seconds
            'enabled' => env('HORIZON_NOTIFICATION_SLOW_QUEUE', true),
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Redis Prefix
    |--------------------------------------------------------------------------
    |
    | This value may be used to prefix all Horizon keys stored in Redis.
    |
    */

    'prefix' => env('HORIZON_PREFIX', 'horizon'),

    /*
    |--------------------------------------------------------------------------
    | Master Switch
    |--------------------------------------------------------------------------
    |
    | This option may be used to disable Horizon entirely. This is useful
    | if you need to temporarily disable all queue monitoring.
    |
    */

    'enabled' => env('HORIZON_ENABLED', true),

];

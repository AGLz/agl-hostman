<?php

/**
 * Laravel Backup Configuration
 *
 * Place this file in config/backup.php
 * Use with spatie/laravel-backup package
 */

return [

    /*
    |--------------------------------------------------------------------------
    | Backup Name
    |--------------------------------------------------------------------------
    |
    | The name of the backup that will be used in the filename.
    |
    */
    'name' => env('APP_NAME', 'laravel') . '-backup',

    /*
    |--------------------------------------------------------------------------
    | Source
    |--------------------------------------------------------------------------
    |
    | The files and directories that should be backed up.
    |
    */
    'source' => [

        'files' => [
            /*
             * The list of directories and files that will be included in the backup.
             */
            'include' => [
                base_path('app'),
                base_path('config'),
                base_path('database'),
                base_path('resources'),
                base_path('routes'),
                base_path('.env'),
            ],

            /*
             * These directories and files will be excluded from the backup.
             */
            'exclude' => [
                base_path('vendor'),
                base_path('node_modules'),
                base_path('storage/app/public'), // Usually backed up separately
                base_path('storage/framework/cache'),
                base_path('storage/framework/sessions'),
                base_path('storage/framework/views'),
                base_path('storage/logs'),
            ],

            /*
             * These files will be excluded from the backup.
             */
            'exclude_files' => [
                '.git',
                '.idea',
                '.DS_Store',
            ],

            /*
             * Should links be followed?
             */
            'follow_links' => false,
        ],

        /*
         * The databases that should be backed up.
         *
         * MySQL, PostgreSQL, SQLite: Supported out of the box.
         */
        'databases' => [
            'mysql' => [
                'type' => 'mysql',
                'host' => env('DB_HOST', '127.0.0.1'),
                'port' => env('DB_PORT', '3306'),
                'user' => env('DB_USERNAME', 'root'),
                'password' => env('DB_PASSWORD', ''),
                'name' => env('DB_DATABASE', 'laravel'),
                'dump_command_path' => '/usr/bin/mysqldump',
                'use_single_transaction' => true,
                'timeout' => 60 * 5, // 5 minutes
            ],
            'postgresql' => [
                'type' => 'postgresql',
                'host' => env('DB_HOST', '127.0.0.1'),
                'port' => env('DB_PORT', '5432'),
                'user' => env('DB_USERNAME', 'postgres'),
                'password' => env('DB_PASSWORD', ''),
                'name' => env('DB_DATABASE', 'laravel'),
                'dump_command_path' => '/usr/bin/pg_dump',
                'use_single_transaction' => true,
                'timeout' => 60 * 5,
            ],
            'sqlite' => [
                'type' => 'sqlite',
                'path' => env('DB_DATABASE', database_path('database.sqlite')),
                'timeout' => 60 * 5,
            ],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Database Dump Compressor
    |--------------------------------------------------------------------------
    |
    | The compressor that should be used to compress the database dump.
    | Available: gzip, bzip2
    |
    */
    'database_dump_compressor' => null,

    /*
    |--------------------------------------------------------------------------
    | Destination
    |--------------------------------------------------------------------------
    |
    | The destination where backups should be stored.
    | Supports: local, s3, dropbox, ftp, sftp, gcs, azure, b2
    |
    */
    'destination' => [

        /*
         * The filename prefix used for the backup zip file.
         */
        'filename_prefix' => '',

        /*
         * The disk names that should be used for backups.
         * Defined in config/filesystems.php
         */
        'disks' => [
            'backups', // Local storage
            // 's3-backups', // S3 storage
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Temporary Directory
    |--------------------------------------------------------------------------
    |
    | The directory that will be used for temporary files while creating the backup.
    |
    */
    'temporary_directory' => storage_path('app/backup-temp'),

    /*
    |--------------------------------------------------------------------------
    | Password
    |--------------------------------------------------------------------------
    |
    | The password that should be used to encrypt the backup zip file.
    | Leave empty for no encryption.
    |
    */
    'password' => env('BACKUP_PASSWORD'),

    /*
    |--------------------------------------------------------------------------
    | Encryption
    |--------------------------------------------------------------------------
    |
    | The encryption algorithm that should be used for encrypting the backup zip file.
    | Available: AES-256, ZIPCrypto
    |
    */
    'encryption' => 'AES-256',

    /*
    |--------------------------------------------------------------------------
    | Checks
    |--------------------------------------------------------------------------
    |
    | The health checks that should be run when creating a backup.
    |
    */
    'checks' => [
        Spatie\Backup\Tasks\Backup\BackupStatusCheck::class,
        Spatie\Backup\Tasks\Backup\DiskSpaceCheck::class => [
            'threshold' => 5000, // MB
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Notifications
    |--------------------------------------------------------------------------
    |
    | The notifications that should be sent when a backup succeeds or fails.
    |
    */
    'notifications' => [

        /*
         * The Notifiable class that will receive notifications.
         */
        'notifiable' => \App\Notifications\BackupNotification::class,

        /*
         * The notification channels that should be used.
         * Available: mail, slack, discord, telegram
         */
        'channels' => [
            'mail' => [
                'to' => env('BACKUP_NOTIFICATION_EMAIL', 'ops@example.com'),
            ],
            'slack' => [
                'webhook_url' => env('BACKUP_SLACK_WEBHOOK'),
            ],
        ],

        /*
         * The time in minutes after which a backup is considered stale.
         */
        'health_check' => [
            'allowed_days_since_last_backup' => 1,
        ],

        /*
         * The time in minutes after which a backup health check will fail.
         */
        'backup_stale_status' => [
            'enabled' => true,
            'days_without_backup' => 2,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Cleanup
    |--------------------------------------------------------------------------
    |
    | The cleanup strategy that should be used.
    | Available: oldest, newest
    |
    */
    'cleanup' => [

        /*
         * The strategy that should be used.
         */
        'strategy' => \Spatie\Backup\Tasks\Cleanup\Strategies\DefaultStrategy::class,

        /*
         * The default strategy will keep:
         * - All backups for the specified number of days
         * - All backups of the last X days for each of the weekly periods
         * - All backups of the last X days for each of the monthly periods
         * - All backups of the last X years for each of the yearly periods
         */
        'default_strategy' => [
            'keep_all_backups_for_days' => 7,
            'keep_daily_backups_for_days' => 30,
            'keep_weekly_backups_for_weeks' => 12,
            'keep_monthly_backups_for_months' => 12,
            'keep_yearly_backups_for_years' => 7,
            'delete_oldest_backups_when_using_more_megabytes_than' => 5000,
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Monitoring
    |--------------------------------------------------------------------------
    |
    | The monitoring settings for the backup system.
    |
    */
    'monitoring' => [

        /*
         * The monitoring jobs that should be run.
         */
        'jobs' => [
            \Spatie\Backup\Tasks\Monitor\BackupsAreHealthyMonitor::class => [
                'allowed_days_since_last_backup' => 1,
            ],
            \Spatie\Backup\Tasks\Monitor\BackupSizeMonitor::class => [
                'max_backup_size_mb' => 5000,
            ],
        ],
    ],

    /*
    |--------------------------------------------------------------------------
    | Backup Job
    |--------------------------------------------------------------------------
    |
    | The settings for the backup job.
    |
    */
    'backup' => [

        /*
         * The command that should be used to create the backup.
         */
        'command' => 'backup:run',

        /*
         * The schedule that should be used to run the backup.
         */
        'schedule' => '0 2 * * *', // Daily at 2 AM

        /*
         * The schedule that should be used to run the cleanup.
         */
        'cleanup_schedule' => '0 6 * * *', // Daily at 6 AM

        /*
         * Should the backup be run without overwriting the previous one?
         */
        'without_overwriting' => false,

        /*
         * Should the backup be run with only the files?
         */
        'only_files' => false,

        /*
         * Should the backup be run with only the database?
         */
        'only_db' => false,

        /*
         * Should the backup be run with compression?
         */
        'compress' => true,

        /*
         * Should the backup be run with notifications?
         */
        'send_notification' => true,

        /*
         * Should the backup be run with monitoring?
         */
        'monitor' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Restore
    |--------------------------------------------------------------------------
    |
    | The settings for the restore process.
    |
    */
    'restore' => [

        /*
         * The command that should be used to restore the backup.
         */
        'command' => 'backup:restore',

        /*
         * The disk that should be used to restore the backup.
         */
        'disk' => 'backups',

        /*
         * Should the database be restored?
         */
        'restore_db' => true,

        /*
         * Should the files be restored?
         */
        'restore_files' => true,

        /*
         * Should the application be put in maintenance mode during restore?
         */
        'maintenance_mode' => true,
    ],

    /*
    |--------------------------------------------------------------------------
    | Compliance
    |--------------------------------------------------------------------------
    |
    | Compliance settings for regulatory requirements.
    |
    */
    'compliance' => [

        /*
         * Should backups be encrypted? (GDPR, HIPAA requirement)
         */
        'encrypt_backups' => env('BACKUP_ENCRYPT', true),

        /*
         * Minimum retention period in days (GDPR: varies, HIPAA: 6 years)
         */
        'minimum_retention_days' => env('BACKUP_MIN_RETENTION', 30),

        /*
         * Should backup access be logged? (SOC2 requirement)
         */
        'log_access' => env('BACKUP_LOG_ACCESS', true),

        /*
         * Should backups be replicated to multiple regions? (Disaster recovery)
         */
        'multi_region_replication' => env('BACKUP_MULTI_REGION', false),

        /*
         * Should backup integrity be verified regularly?
         */
        'verify_integrity' => env('BACKUP_VERIFY_INTEGRITY', true),

        /*
         * How often should restore tests be run? (in days)
         */
        'restore_test_frequency_days' => env('BACKUP_RESTORE_TEST_DAYS', 7),
    ],

];

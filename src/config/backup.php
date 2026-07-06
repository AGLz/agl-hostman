<?php

$defaultConnection = env('DB_CONNECTION', 'pgsql');

return [
    'databases' => array_values(array_filter([
        env('BACKUP_DB_CONNECTION', $defaultConnection),
    ])),
    'paths' => ['app', 'config', 'database', 'resources'],
    'exclude' => ['node_modules', 'vendor', '.git', 'storage/logs'],
    'retention' => (int) env('BACKUP_RETENTION_DAYS', 30),
    'compression' => env('BACKUP_COMPRESSION', true),
    'encrypt' => env('BACKUP_ENCRYPT', false),
    'encryption_password' => env('BACKUP_PASSWORD'),
    'notification_email' => env('BACKUP_NOTIFICATION_EMAIL'),
    'remote_storage' => env('BACKUP_REMOTE_STORAGE', false),
    'remote_disk' => env('BACKUP_REMOTE_DISK', 's3'),
];

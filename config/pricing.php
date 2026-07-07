<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Pricing Configuration
    |--------------------------------------------------------------------------
    |
    | These settings control the cost calculation for container usage.
    | All prices are in USD per month unless specified otherwise.
    |
    */

    'cache_ttl' => 3600, // 1 hour

    'container' => [
        'cpu_per_core_per_hour' => 0.05,
        'memory_per_gb_per_hour' => 0.02,
        'disk_per_gb_per_month' => 0.10,
        'network_per_gb' => 0.01,
        'snapshots_gb_per_month' => 0.05,
        'backups_gb_per_month' => 0.08,
    ],

    'migrations' => [
        'fixed_fee' => 10.00,
        'per_gb' => 0.05,
        'additional_fee_per_node' => 5.00,
    ],

    'cloning' => [
        'fixed_fee' => 5.00,
        'per_gb' => 0.03,
    ],

    'alerts' => [
        'free_alerts' => 100,
        'additional_cost_per_alert' => 0.001,
    ],

    'features' => [
        'gpu_support' => 0.10, // per hour
        'live_migration' => 0.05, // per GB
        'auto_scaling' => 0.20, // per hour
    ],

    'currency' => 'USD',

    'tax_rate' => 0.08, // 8%

    'rounding_precision' => 2,
];

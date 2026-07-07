<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Proxmox Configuration
    |--------------------------------------------------------------------------
    |
    | These settings control the connection and behavior with Proxmox API.
    |
    */

    'api_url' => env('PROXMOX_API_URL', 'https://pve-odio:8006/api2/json'),
    'username' => env('PROXMOX_USERNAME', 'root@pam'),
    'password' => env('PROXMOX_PASSWORD', ''),
    'api_token' => env('PROXMOX_API_TOKEN', ''),
    'realm' => env('PROXMOX_REALM', 'pam'),
    'use_api_token' => env('PROXMOX_USE_API_TOKEN', false),

    'timeout' => 30, // seconds
    'verify_ssl' => env('PROXMOX_VERIFY_SSL', true),
    'default_node' => 'pve-odio',

    'templates' => [
        'ubuntu-latest' => 'local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.gz',
        'debian-latest' => 'local:vztmpl/debian-12-standard_12.0-1_amd64.tar.gz',
        'centos-latest' => 'local:vztmpl/centos-stream-8-default_20230131_amd64.tar.gz',
    ],

    'storage' => [
        'default' => 'local',
        'rootfs' => 'local-lvm',
        'backup' => 'local-zfs',
    ],

    'defaults' => [
        'ostype' => 'ubuntu',
        'cores' => 2,
        'memory_mb' => 2048,
        'disk_size_gb' => 20,
        'swap_mb' => 512,
        'features' => ['nesting'],
        'network' => [
            'bridge' => 'vmbr0',
            'type' => 'veth',
        ],
    ],

    'migration' => [
        'bwlimit' => 0,
        'online' => true,
        'compress' => '0',
        'ssh' => 1,
    ],

    'backup' => [
        'mode' => 'snapshot',
        'compress' => '0',
        'storage' => 'local',
    ],

    'clone' => [
        'full' => 1,
        'compress' => '0',
    ],
];

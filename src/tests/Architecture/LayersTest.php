<?php

declare(strict_types=1);

// Presentation Layer (HTTP)
arch('presentation layer')
    ->expect('App\Http\Controllers')
    ->not->toUse([
        'Illuminate\Support\Facades\DB',
        'Illuminate\Database\Eloquent\Model',
    ])
    ->ignoring(['App\Models', 'App\Services']);

// Business Logic Layer (Services)
arch('business logic layer')
    ->expect('App\Services')
    ->not->toUse([
        'Illuminate\Http\Request',
        'Illuminate\Http\Response',
    ]);

// Data Access Layer (Repositories)
arch('data access layer')
    ->expect('App\Repositories')
    ->toBeSuffix('Repository')
    ->toOnlyBeUsedIn(['App\Services', 'App\Repositories']);

// Jobs should not use controllers
arch('jobs isolation')
    ->expect('App\Jobs')
    ->not->toUse('App\Http\Controllers');

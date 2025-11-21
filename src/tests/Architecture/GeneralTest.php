<?php

declare(strict_types=1);

arch('strict types')
    ->expect('App')
    ->toUseStrictTypes();

arch('no debugging functions')
    ->expect(['dd', 'dump', 'var_dump', 'print_r', 'ray'])
    ->not->toBeUsed()
    ->ignoring('App\Console\Commands'); // Allow in console commands

arch('no die or exit')
    ->expect(['die', 'exit'])
    ->not->toBeUsed();

arch('DTOs are readonly')
    ->expect('App\DTO')
    ->toBeReadonly()
    ->toHaveSuffix(''); // No suffix required for DTOs

arch('DTOs implement JsonSerializable')
    ->expect('App\DTO')
    ->toImplement('JsonSerializable');

arch('jobs')
    ->expect('App\Jobs')
    ->toHaveSuffix('Job')
    ->orToHaveSuffix('')
    ->toImplement('Illuminate\Contracts\Queue\ShouldQueue');

arch('events')
    ->expect('App\Events')
    ->toHaveSuffix('Event')
    ->orToHaveSuffix('');

arch('listeners')
    ->expect('App\Listeners')
    ->toHaveSuffix('Listener')
    ->toHaveMethod('handle');

arch('no circular dependencies')
    ->expect('App\Services')
    ->not->toDepend('App\Services');

arch('middleware')
    ->expect('App\Http\Middleware')
    ->toHaveSuffix('Middleware')
    ->orToHaveSuffix('')
    ->toHaveMethod('handle');

arch('providers extend service provider')
    ->expect('App\Providers')
    ->toExtend('Illuminate\Support\ServiceProvider')
    ->toHaveSuffix('ServiceProvider')
    ->orToHaveSuffix('Provider');

<?php

declare(strict_types=1);

arch('controllers')
    ->expect('App\Http\Controllers')
    ->toHaveSuffix('Controller')
    ->toExtend('App\Http\Controllers\Controller')
    ->toOnlyBeUsedIn(['App\Http\Controllers', 'Illuminate\Support\Facades\Route']);

arch('controllers use dependency injection')
    ->expect('App\Http\Controllers')
    ->not->toUse([
        'App\Models', // Should use services/repositories instead
    ])
    ->ignoring('App\Http\Controllers\Controller');

arch('API controllers are in correct namespace')
    ->expect('App\Http\Controllers\Api')
    ->toBeClasses()
    ->toHaveMethod('__invoke')
    ->orToHaveMethod('index')
    ->orToHaveMethod('show')
    ->orToHaveMethod('store')
    ->orToHaveMethod('update')
    ->orToHaveMethod('destroy');

arch('controllers have strict types')
    ->expect('App\Http\Controllers')
    ->toUseStrictTypes();

arch('controllers do not use facades directly')
    ->expect('App\Http\Controllers')
    ->not->toUse([
        'Illuminate\Support\Facades\Cache',
        'Illuminate\Support\Facades\Log',
        'Illuminate\Support\Facades\DB',
    ])
    ->ignoring('App\Http\Controllers\DashboardController'); // Exception for dashboard stats

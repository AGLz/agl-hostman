<?php

declare(strict_types=1);

arch('models')
    ->expect('App\Models')
    ->toExtend('Illuminate\Database\Eloquent\Model')
    ->toOnlyBeUsedIn([
        'App\Http\Controllers',
        'App\Services',
        'App\Repositories',
        'App\Jobs',
        'App\Livewire',
        'Database\Factories',
        'Database\Seeders',
    ])
    ->toHaveSuffix(''); // No suffix required

arch('models have proper namespace')
    ->expect('App\Models')
    ->toBeClasses()
    ->not->toBeInterfaces()
    ->not->toBeTraits();

arch('models use proper traits')
    ->expect('App\Models')
    ->toUse([
        'Illuminate\Database\Eloquent\Factories\HasFactory',
        'Illuminate\Database\Eloquent\SoftDeletes',
    ])
    ->when(fn ($class) => method_exists($class, 'factory') || property_exists($class, 'dates'));

arch('models define fillable or guarded')
    ->expect('App\Models')
    ->toHaveProperty('fillable')
    ->orToHaveProperty('guarded');

arch('models cast dates to Carbon')
    ->expect('App\Models')
    ->classes()
    ->toHaveProperty('casts')
    ->when(fn ($class) => property_exists($class, 'casts'));

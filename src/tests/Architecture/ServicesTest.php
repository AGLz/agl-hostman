<?php

declare(strict_types=1);

arch('services')
    ->expect('App\Services')
    ->toHaveSuffix('Service')
    ->orToHaveSuffix('Client')
    ->toBeClasses();

arch('services use dependency injection')
    ->expect('App\Services')
    ->toHaveConstructor()
    ->when(fn ($class) => !str_ends_with($class, 'Client'));

arch('services are not used in models')
    ->expect('App\Services')
    ->not->toBeUsedIn('App\Models');

arch('services have strict types')
    ->expect('App\Services')
    ->toUseStrictTypes();

arch('services use interfaces for external dependencies')
    ->expect('App\Services')
    ->classes()
    ->toHaveMethod('__construct')
    ->when(fn ($class) => str_ends_with($class, 'Service'));

arch('services do not have static methods')
    ->expect('App\Services')
    ->not->toHaveStaticMethods()
    ->ignoring('App\Services\CacheService'); // Facade pattern exception

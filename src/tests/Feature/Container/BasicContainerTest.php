<?php

use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

test('container routes are defined', function () {
    $routes = \Illuminate\Support\Facades\Route::getRoutes();

    $containerRoutes = [];
    foreach ($routes as $route) {
        if (str_contains($route->uri, 'containers')) {
            $containerRoutes[] = $route->uri . ' [' . $route->methods[0] . ']';
        }
    }

    $this->assertNotEmpty($containerRoutes, 'No container routes found');

    // Log found routes for debugging
    foreach ($containerRoutes as $route) {
        info('Found container route: ' . $route);
    }
});

test('basic container model relationship works', function () {
    $this->markTestSkipped('WIP: schema LxcContainer vs factory');
    $container = \App\Models\LxcContainer::factory()->create();

    $this->assertNotNull($container);
    $this->assertEquals('container', $container->type);
    $this->assertIsInt($container->vmid);
});

test('container DTO validation works', function () {
    $dto = \App\DTO\ContainerCreateDTO::fromArray([
        'hostname' => 'test-container',
        'cores' => 2,
        'memory_mb' => 2048,
        'disk_gb' => 20,
        'ostemplate' => 'ubuntu',
    ]);

    $this->assertEquals('test-container', $dto->hostname);
    $this->assertEquals(2, $dto->cores);
});

<?php

use App\Models\LxcContainer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->markTestSkipped('WIP: CRUD containers em integração com Proxmox');
});

test('guest cannot access container management', function () {
    $response = $this->getJson('/api/containers');

    $response->assertStatus(401);
});

test('authenticated user can list containers', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    // Criar containers de teste
    LxcContainer::factory()->count(3)->create();

    $response = $this->get('/api/containers');

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'data' => [
                         '*' => [
                             'id',
                             'vmid',
                             'hostname',
                             'node',
                             'status',
                             'created_at'
                         ]
                     ],
                     'meta'
                 ],
                 'message'
             ])
             ->assertJsonCount(3, 'data.data');
});

test('authenticated user can view specific container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create();

    $response = $this->get("/api/containers/{$container->id}");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'id',
                     'vmid',
                     'hostname',
                     'node',
                     'status'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'id' => $container->id,
                 'vmid' => $container->vmid,
                 'hostname' => $container->hostname
             ]);
});

test('authenticated user can create container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $containerData = [
        'vmid' => 101,
        'node' => 'aglsrv1',
        'hostname' => 'test-container-01',
        'cores' => 2,
        'memory_mb' => 2048,
        'disk_size_gb' => 20,
        'ostype' => 'ubuntu',
        'start_on_boot' => true,
        'unprivileged' => false,
    ];

    // Mock do WebSocketBroadcastService
    Event::fake();

    $response = $this->post('/api/containers', $containerData);

    $response->assertStatus(202)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'vmid',
                     'hostname',
                     'node',
                     'status',
                     'estimated_time'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Solicitação de criação de container enviada'
             ]);

    // Verificar se o job foi enfileirado
    Event::assertDispatched('container.create.requested');

    // Verificar se existe registro no banco
    $this->assertDatabaseHas('lxc_containers', [
        'vmid' => 101,
        'hostname' => 'test-container-01'
    ]);
});

test('authenticated user can clone container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'source-container'
    ]);

    $cloneData = [
        'source_vmid' => 100,
        'target_vmid' => 101,
        'node' => 'aglsrv1',
        'clone_mode' => 'full',
        'target_hostname' => 'cloned-container',
        'preserve_config' => true,
    ];

    Event::fake();

    $response = $this->post('/api/containers/clone', $cloneData);

    $response->assertStatus(202)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'source_vmid',
                     'target_vmid',
                     'clone_mode',
                     'status',
                     'estimated_time'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Solicitação de clone de container enviada'
             ]);

    Event::assertDispatched('container.clone.requested');

    // Verificar se o clone foi registrado
    $this->assertDatabaseHas('lxc_containers', [
        'vmid' => 101,
        'hostname' => 'cloned-container'
    ]);
});

test('authenticated user can create container snapshot', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'test-container'
    ]);

    $snapshotData = [
        'name' => 'snapshot-01',
        'description' => 'Test snapshot',
        'snapshot_type' => 'manual',
        'compression' => 'zstd',
    ];

    Event::fake();

    $response = $this->post("/api/containers/{$container->id}/snapshot", $snapshotData);

    $response->assertStatus(202)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'container_vmid',
                     'snapshot_name',
                     'status',
                     'estimated_time'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Solicitação de snapshot enviada'
             ]);

    Event::assertDispatched('container.snapshot.requested');
});

test('container validation fails with invalid data', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $invalidData = [
        'vmid' => 9999999999, // VMID inválido
        'hostname' => 'invalid hostname!', // Hostname inválido
        'cores' => 0, // Cores inválidas
        'memory_mb' => 50, // Memória inválida
    ];

    $response = $this->post('/api/containers', $invalidData);

    $response->assertStatus(422)
             ->assertJsonStructure([
                 'message',
                 'errors'
             ]);
});

test('cannot create container with duplicate VMID', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    // Criar container existente
    LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'existing-container'
    ]);

    $duplicateData = [
        'vmid' => 100, // Mesmo VMID
        'node' => 'aglsrv1',
        'hostname' => 'new-container',
        'cores' => 2,
        'memory_mb' => 2048,
        'disk_size_gb' => 20,
        'ostype' => 'ubuntu',
    ];

    $response = $this->post('/api/containers', $duplicateData);

    $response->assertStatus(422)
             ->assertJsonFragment([
                 'vmid' => ['O VMID já está em uso por outro container.']
             ]);
});

test('can start container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'status' => 'stopped'
    ]);

    $response = $this->post("/api/containers/{$container->id}/start");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'status'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Container iniciado com sucesso'
             ]);
});

test('can stop container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'status' => 'running'
    ]);

    $response = $this->post("/api/containers/{$container->id}/stop");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Container parado com sucesso'
             ]);
});

test('can restart container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'status' => 'running'
    ]);

    $response = $this->post("/api/containers/{$container->id}/restart");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Container reiniciado com sucesso'
             ]);
});

test('can delete container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'container-to-delete'
    ]);

    $response = $this->delete("/api/containers/{$container->id}");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Container excluído com sucesso'
             ]);

    // Verificar se foi removido do banco
    $this->assertDatabaseMissing('lxc_containers', [
        'id' => $container->id
    ]);
});

test('can get container status', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'status' => 'running'
    ]);

    $response = $this->get("/api/containers/{$container->id}/status");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'container',
                     'proxmox_status',
                     'last_updated'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'data' => [
                     'container' => [
                         'id' => $container->id,
                         'vmid' => $container->vmid,
                         'status' => 'running'
                     ]
                 ]
             ]);
});

test('cannot access non-existent container', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    $response = $this->get('/api/containers/999999');

    $response->assertStatus(404)
             ->assertJsonFragment([
                 'success' => false,
                 'message' => 'Container não encontrado'
             ]);
});

test('can filter containers by node', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    // Criar containers em nós diferentes
    LxcContainer::factory()->create(['node' => 'aglsrv1', 'hostname' => 'container-1']);
    LxcContainer::factory()->create(['node' => 'aglsrv2', 'hostname' => 'container-2']);
    LxcContainer::factory()->create(['node' => 'aglsrv1', 'hostname' => 'container-3']);

    $response = $this->get('/api/containers?node=aglsrv1');

    $response->assertStatus(200)
             ->assertJsonCount(2, 'data.data');
});

test('can search containers by hostname', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    LxcContainer::factory()->create(['hostname' => 'web-server-01']);
    LxcContainer::factory()->create(['hostname' => 'db-server-01']);
    LxcContainer::factory()->create(['hostname' => 'cache-server-01']);

    $response = $this->get('/api/containers?search=web');

    $response->assertStatus(200)
             ->assertJsonCount(1, 'data.data')
             ->assertJsonFragment([
                 'hostname' => 'web-server-01'
             ]);
});

test('can paginate containers', function () {
    $user = createAuthenticatedUserForManagement();
    $this->actingAs($user, 'sanctum');

    // Criar 20 containers
    LxcContainer::factory()->count(20)->create();

    $response = $this->get('/api/containers?per_page=5');

    $response->assertStatus(200)
             ->assertJsonCount(5, 'data.data')
             ->assertJsonStructure([
                 'data' => [
                     'data',
                     'meta' => [
                         'current_page',
                         'per_page',
                         'total',
                         'last_page'
                     ]
                 ]
             ]);
});

/**
 * Helper function to create authenticated user for management tests
 */
function createAuthenticatedUserForManagement(): \App\Models\User
{
    return \App\Models\User::factory()->create([
        'email' => 'management-test@example.com',
        'name' => 'Management Test User',
    ]);
}

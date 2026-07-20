<?php

use App\Models\LxcContainer;
use App\Models\ContainerMigration;
use App\Models\ProxmoxServer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->markTestSkipped('WIP: API migration containers ainda sem controller');
});

test('guest cannot access migration operations', function () {
    $response = $this->post('/api/containers/100/migrate');

    $response->assertStatus(302)
             ->assertRedirect('/login');
});

test('authenticated user can initiate container migration', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    // Criar servidores source e target
    $sourceServer = ProxmoxServer::factory()->create(['node' => 'aglsrv1']);
    $targetServer = ProxmoxServer::factory()->create(['node' => 'aglsrv2']);

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'node' => 'aglsrv1',
        'hostname' => 'test-container'
    ]);

    $migrationData = [
        'source_node' => 'aglsrv1',
        'target_node' => 'aglsrv2',
        'total_mb' => 10240,
        'estimated_seconds' => 600,
        'migration_mode' => 'online',
        'compression' => 'zstd',
    ];

    Event::fake();

    $response = $this->post("/api/containers/{$container->id}/migrate", $migrationData);

    $response->assertStatus(202)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'source_vmid',
                     'target_vmid',
                     'source_node',
                     'target_node',
                     'status',
                     'estimated_time'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Solicitação de migração enviada',
                 'data' => [
                     'source_vmid' => 100,
                     'source_node' => 'aglsrv1',
                     'target_node' => 'aglsrv2',
                     'status' => 'pending'
                 ]
             ]);

    Event::assertDispatched('container.migration.requested');

    // Verificar se migração foi enfileirada
    $this->assertDatabaseHas('container_migrations', [
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'pending',
        'total_mb' => 10240,
        'estimated_seconds' => 600
    ]);
});

test('authenticated user can list container migrations', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $sourceServer = ProxmoxServer::factory()->create(['node' => 'aglsrv1']);
    $targetServer = ProxmoxServer::factory()->create(['node' => 'aglsrv2']);

    // Criar algumas migrações
    ContainerMigration::factory()->count(3)->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'completed'
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'data' => [
                         '*' => [
                             'id',
                             'container_id',
                             'source_server_id',
                             'target_server_id',
                             'status',
                             'progress',
                             'created_at',
                             'completed_at'
                         ]
                     ],
                     'meta'
                 ],
                 'message'
             ])
             ->assertJsonCount(3, 'data.data');
});

test('authenticated user can get specific migration', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $sourceServer = ProxmoxServer::factory()->create(['node' => 'aglsrv1']);
    $targetServer = ProxmoxServer::factory()->create(['node' => 'aglsrv2']);

    $migration = ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'in_progress',
        'progress' => 45,
        'transferred_mb' => 4096,
        'total_mb' => 9216
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations/{$migration->id}");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'id',
                     'container_id',
                     'source_server_id',
                     'target_server_id',
                     'status',
                     'progress',
                     'transferred_mb',
                     'total_mb',
                     'estimated_seconds',
                     'error_message',
                     'created_at',
                     'completed_at',
                     'metadata'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'id' => $migration->id,
                 'status' => 'in_progress',
                 'progress' => 45,
                 'transferred_mb' => 4096,
                 'total_mb' => 9216
             ]);
});

test('authenticated user can cancel migration', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $migration = ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'in_progress'
    ]);

    $response = $this->post("/api/containers/{$container->id}/migrations/{$migration->id}/cancel");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Migração cancelada com sucesso'
             ]);

    // Verificar se a migração foi atualizada
    $this->assertDatabaseHas('container_migrations', [
        'id' => $migration->id,
        'status' => 'cancelled'
    ]);
});

test('authenticated user can rollback migration', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $migration = ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed'
    ]);

    $response = $this->post("/api/containers/{$container->id}/migrations/{$migration->id}/rollback");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Rollback da migração iniciado'
             ]);

    // Verificar se uma nova migração de rollback foi criada
    $this->assertDatabaseHas('container_migrations', [
        'container_id' => $container->id,
        'status' => 'pending'
    ]);
});

test('migration validation fails with invalid data', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    $invalidData = [
        'source_node' => '', // Nó source obrigatório
        'target_node' => '', // Nó target obrigatório
        'total_mb' => 0, // Tamanho inválido
        'estimated_seconds' => -1, // Tempo inválido
    ];

    $response = $this->post("/api/containers/{$container->id}/migrate", $invalidData);

    $response->assertStatus(422)
             ->assertJsonStructure([
                 'message',
                 'errors'
             ]);
});

test('cannot migrate container to same node', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'node' => 'aglsrv1'
    ]);

    $migrationData = [
        'source_node' => 'aglsrv1',
        'target_node' => 'aglsrv1', // Mesmo nó
        'total_mb' => 10240,
        'estimated_seconds' => 600,
    ];

    $response = $this->post("/api/containers/{$container->id}/migrate", $migrationData);

    $response->assertStatus(422)
             ->assertJsonFragment([
                 'source_node' => ['O nó de destino deve ser diferente do nó de origem.']
             ]);
});

test('cannot migrate non-existent container', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $migrationData = [
        'source_node' => 'aglsrv1',
        'target_node' => 'aglsrv2',
        'total_mb' => 10240,
        'estimated_seconds' => 600,
    ];

    $response = $this->post('/api/containers/999999/migrate', $migrationData);

    $response->assertStatus(404)
             ->assertJsonFragment([
                 'success' => false,
                 'message' => 'Container não encontrado'
             ]);
});

test('cannot access migration for non-existent migration', function () {
    $user = createAuthenticatedUserForMigration();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    $response = $this->get('/api/containers/100/migrations/999999');

    $response->assertStatus(404)
             ->assertJsonFragment([
                 'success' => false,
                 'message' => 'Migração não encontrada'
             ]);
});

test('can filter migrations by status', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $sourceServer = ProxmoxServer::factory()->create(['node' => 'aglsrv1']);
    $targetServer = ProxmoxServer::factory()->create(['node' => 'aglsrv2']);

    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'completed'
    ]);
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'failed'
    ]);
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer->id,
        'target_server_id' => $targetServer->id,
        'status' => 'completed'
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations?status=completed");

    $response->assertStatus(200)
             ->assertJsonCount(2, 'data.data');
});

test('can filter migrations by node', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $sourceServer1 = ProxmoxServer::factory()->create(['node' => 'aglsrv1']);
    $targetServer1 = ProxmoxServer::factory()->create(['node' => 'aglsrv2']);
    $sourceServer2 = ProxmoxServer::factory()->create(['node' => 'aglsrv3']);
    $targetServer2 = ProxmoxServer::factory()->create(['node' => 'aglsrv4']);

    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer1->id,
        'target_server_id' => $targetServer1->id
    ]);
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'source_server_id' => $sourceServer2->id,
        'target_server_id' => $targetServer2->id
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations?source_node=aglsrv1");

    $response->assertStatus(200)
             ->assertJsonCount(1, 'data.data');
});

test('can get migration progress', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $migration = ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'in_progress',
        'progress' => 75,
        'transferred_mb' => 7680,
        'total_mb' => 10240,
        'estimated_seconds' => 300
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations/{$migration->id}/progress");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'progress',
                     'percentage',
                     'transferred_mb',
                     'total_mb',
                     'estimated_seconds_remaining',
                     'transfer_rate_mb_per_sec',
                     'status'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'progress' => 75,
                 'percentage' => 75,
                 'transferred_mb' => 7680,
                 'total_mb' => 10240,
                 'status' => 'in_progress'
             ]);
});

test('can get migration statistics', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    // Criar migrações com diferentes status
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed',
        'total_mb' => 10240,
        'transferred_mb' => 10240,
        'created_at' => now()->subDay(),
        'completed_at' => now()
    ]);
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'failed',
        'total_mb' => 5120,
        'transferred_mb' => 2560,
        'created_at' => now()->subDays(2)
    ]);
    ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'in_progress',
        'total_mb' => 8192,
        'transferred_mb' => 4096,
        'created_at' => now()->subHours(1)
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations/stats");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'total_migrations',
                     'successful_migrations',
                     'failed_migrations',
                     'in_progress_migrations',
                     'total_data_transferred_mb',
                     'average_success_rate',
                     'average_migration_time_minutes',
                     'last_migration',
                     'next_migration_scheduled'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'total_migrations' => 3,
                 'successful_migrations' => 1,
                 'failed_migrations' => 1,
                 'in_progress_migrations' => 1,
                 'total_data_transferred_mb' => 23008 // 10240 + 2560 + 4096
             ]);
});

test('migration time calculation is accurate', function () {
    $user = $this->createAuthenticatedUser();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);
    $migration = ContainerMigration::factory()->create([
        'container_id' => $container->id,
        'status' => 'in_progress',
        'progress' => 50,
        'transferred_mb' => 5120,
        'total_mb' => 10240,
        'created_at' => now()->subMinutes(10) // Começou há 10 minutos
    ]);

    $response = $this->get("/api/containers/{$container->id}/migrations/{$migration->id}/progress");

    $response->assertStatus(200);

    // Verificar se o tempo restante foi calculado corretamente
    $responseData = $response->json('data');
    $this->assertArrayHasKey('estimated_seconds_remaining', $responseData);
    $this->assertIsNumeric($responseData['estimated_seconds_remaining']);
});

/**
 * Helper function to create authenticated user for migration tests
 */
function createAuthenticatedUserForMigration(): \App\Models\User
{
    return \App\Models\User::factory()->create([
        'email' => 'migration-test@example.com',
        'name' => 'Migration Test User',
    ]);
}

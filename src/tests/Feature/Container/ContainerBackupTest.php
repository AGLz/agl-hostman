<?php

use App\Models\LxcContainer;
use App\Models\ContainerBackup;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;

uses(RefreshDatabase::class);

beforeEach(function () {
    $this->markTestSkipped('WIP: API backup containers ainda sem controller');
});

test('guest cannot access backup operations', function () {
    $response = $this->post('/api/containers/100/backup');

    $response->assertStatus(302)
             ->assertRedirect('/login');
});

test('authenticated user can create container backup', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'test-container',
        'node' => 'aglsrv1'
    ]);

    $backupData = [
        'storage' => 'local-zfs',
        'mode' => 'snapshot',
        'compress' => 'zstd',
        'notes' => 'Test backup',
        'cleanup_after_days' => 30,
    ];

    Event::fake();

    $response = $this->post("/api/containers/{$container->id}/backup", $backupData);

    $response->assertStatus(202)
             ->assertJsonStructure([
                 'success',
                 'message',
                 'data' => [
                     'vmid',
                     'node',
                     'storage',
                     'mode',
                     'status',
                     'estimated_time'
                 ]
             ])
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Solicitação de backup enviada',
                 'data' => [
                     'vmid' => 100,
                     'node' => 'aglsrv1',
                     'status' => 'pending'
                 ]
             ]);

    Event::assertDispatched('container.backup.requested');

    // Verificar se backup foi enfileirado
    $this->assertDatabaseHas('container_backups', [
        'container_id' => $container->id,
        'storage' => 'local-zfs',
        'mode' => 'snapshot',
        'compress' => 'zstd',
        'status' => 'pending'
    ]);
});

test('authenticated user can list container backups', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'test-container'
    ]);

    // Criar alguns backups
    ContainerBackup::factory()->count(3)->create([
        'container_id' => $container->id,
        'status' => 'completed'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'data' => [
                         '*' => [
                             'id',
                             'container_id',
                             'storage',
                             'filename',
                             'size_mb',
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

test('authenticated user can get specific backup', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create();
    $backup = ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed',
        'size_mb' => 1024,
        'filename' => 'backup_2024_01_01_120000.vma.zst'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups/{$backup->id}");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'id',
                     'container_id',
                     'storage',
                     'filename',
                     'size_mb',
                     'status',
                     'created_at',
                     'metadata'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'id' => $backup->id,
                 'status' => 'completed',
                 'size_mb' => 1024
             ]);
});

test('authenticated user can delete backup', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create();
    $backup = ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed'
    ]);

    $response = $this->delete("/api/containers/{$container->id}/backups/{$backup->id}");

    $response->assertStatus(200)
             ->assertJsonFragment([
                 'success' => true,
                 'message' => 'Backup excluído com sucesso'
             ]);

    // Verificar se foi removido do banco
    $this->assertDatabaseMissing('container_backups', [
        'id' => $backup->id
    ]);
});

test('backup validation fails with invalid data', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    $invalidData = [
        'storage' => '', // Storage obrigatório
        'mode' => 'invalid_mode', // Mode inválido
        'compress' => 'invalid_compression', // Compressão inválida
    ];

    $response = $this->post("/api/containers/{$container->id}/backup", $invalidData);

    $response->assertStatus(422)
             ->assertJsonStructure([
                 'message',
                 'errors'
             ]);
});

test('cannot create backup for non-existent container', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $backupData = [
        'storage' => 'local-zfs',
        'mode' => 'snapshot',
        'compress' => 'zstd',
    ];

    $response = $this->post('/api/containers/999999/backup', $backupData);

    $response->assertStatus(404)
             ->assertJsonFragment([
                 'success' => false,
                 'message' => 'Container não encontrado'
             ]);
});

test('cannot access backup for non-existent backup', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    $response = $this->get('/api/containers/100/backups/999999');

    $response->assertStatus(404)
             ->assertJsonFragment([
                 'success' => false,
                 'message' => 'Backup não encontrado'
             ]);
});

test('can filter backups by status', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'status' => 'failed'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'status' => 'completed'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups?status=completed");

    $response->assertStatus(200)
             ->assertJsonCount(2, 'data.data');
});

test('can filter backups by storage', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'storage' => 'local-zfs'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'storage' => 'nfs'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'storage' => 'local-zfs'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups?storage=local-zfs");

    $response->assertStatus(200)
             ->assertJsonCount(2, 'data.data');
});

test('can search backups by filename', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'filename' => 'backup_web_2024_01_01.vma.zst'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'filename' => 'backup_db_2024_01_02.vma.zst'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups?search=web");

    $response->assertStatus(200)
             ->assertJsonCount(1, 'data.data')
             ->assertJsonFragment([
                 'filename' => 'backup_web_2024_01_01.vma.zst'
             ]);
});

test('can paginate backups', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    // Criar 15 backups
    ContainerBackup::factory()->count(15)->create([
        'container_id' => $container->id
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups?per_page=5");

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

test('can get backup statistics', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create(['vmid' => 100]);

    // Criar backups com diferentes tamanhos
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'size_mb' => 1024,
        'status' => 'completed'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'size_mb' => 2048,
        'status' => 'completed'
    ]);
    ContainerBackup::factory()->create([
        'container_id' => $container->id,
        'size_mb' => 512,
        'status' => 'failed'
    ]);

    $response = $this->get("/api/containers/{$container->id}/backups/stats");

    $response->assertStatus(200)
             ->assertJsonStructure([
                 'success',
                 'data' => [
                     'total_backups',
                     'successful_backups',
                     'failed_backups',
                     'total_size_mb',
                     'average_size_mb',
                     'oldest_backup',
                     'newest_backup'
                 ],
                 'message'
             ])
             ->assertJsonFragment([
                 'total_backups' => 3,
                 'successful_backups' => 2,
                 'failed_backups' => 1,
                 'total_size_mb' => 3072, // 1024 + 2048
                 'average_size_mb' => 1024 // (1024 + 2048 + 512) / 3
             ]);
});

test('backup filename generation follows correct format', function () {
    $user = $this->createAuthenticatedUserForBackup();
    $this->actingAs($user);

    $container = LxcContainer::factory()->create([
        'vmid' => 100,
        'hostname' => 'test-container'
    ]);

    $backupData = [
        'storage' => 'local-zfs',
        'mode' => 'snapshot',
        'compress' => 'zstd',
    ];

    // Mock the service to control filename generation
    \Mockery::mock(\App\Services\Container\ContainerLifecycleService::class)
        ->shouldReceive('backupContainer')
        ->andReturn([
            'filename' => 'backup_test-container_2024-01-01_12-00-00.vma.zst',
            'size_mb' => 1024,
            'task_id' => 'task-12345'
        ]);

    $response = $this->post("/api/containers/{$container->id}/backup", $backupData);

    $response->assertStatus(202);

    // Verificar se o backup foi criado com o nome correto
    $this->assertDatabaseHas('container_backups', [
        'container_id' => $container->id,
        'filename' => 'backup_test-container_2024-01-01_12-00-00.vma.zst'
    ]);
});

/**
 * Helper function to create authenticated user
 */
function createAuthenticatedUserForBackup(): \App\Models\User
{
    return \App\Models\User::factory()->create([
        'email' => 'test@example.com',
        'name' => 'Test User',
    ]);
}

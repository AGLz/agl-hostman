<?php

declare(strict_types=1);

use App\Http\Controllers\DailyMemoryController;
use App\Models\DailySessionLog;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;

uses(RefreshDatabase::class);

covers(DailyMemoryController::class);

beforeEach(function () {
    $this->withoutVite();
    $this->user = User::factory()->create();
});

test('dashboard renders for authenticated user', function () {
    $this->actingAs($this->user);

    $response = $this->get(route('daily-memory.index'));

    $response->assertOk();
    $response->assertInertia(fn ($page) => $page
        ->component('Memory/Dashboard')
        ->has('logs')
        ->has('filters')
        ->has('stats')
    );
});

test('can store a daily session log', function () {
    $this->actingAs($this->user);

    $response = $this->post(route('daily-memory.store'), [
        'occurred_on' => '2026-03-20',
        'title' => 'Sessão teste',
        'summary' => 'Resumo do dia.',
        'topics' => 'laravel, infra',
        'project_tags' => 'agl-hostman',
    ]);

    $response->assertRedirect(route('daily-memory.index'));
    $this->assertDatabaseHas('daily_session_logs', [
        'user_id' => $this->user->id,
        'title' => 'Sessão teste',
    ]);
});

test('cannot view another users log', function () {
    $other = User::factory()->create();
    $log = DailySessionLog::factory()->create(['user_id' => $other->id]);

    $this->actingAs($this->user);

    $response = $this->get(route('daily-memory.show', $log));

    $response->assertForbidden();
});

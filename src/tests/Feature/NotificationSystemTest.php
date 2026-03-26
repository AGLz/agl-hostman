<?php

namespace Tests\Feature;

use App\Events\Notifications\DeploymentStarted;
use App\Models\Deployment;
use App\Models\NotificationChannel;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Event;
use Tests\TestCase;

class NotificationSystemTest extends TestCase
{
    use RefreshDatabase;

    /** @test */
    public function it_can_create_notification_channel()
    {
        $response = $this->postJson('/api/notifications/channels', [
            'name' => 'Test Slack Channel',
            'type' => 'slack',
            'config' => [
                'webhook_url' => 'https://hooks.slack.com/test',
                'channel' => '#test',
            ],
            'enabled' => true,
        ]);

        $response->assertStatus(201)
            ->assertJsonStructure(['message', 'channel']);

        $this->assertDatabaseHas('notification_channels', [
            'name' => 'Test Slack Channel',
            'type' => 'slack',
        ]);
    }

    /** @test */
    public function it_can_create_notification_rule()
    {
        $channel = NotificationChannel::factory()->create();

        $response = $this->postJson('/api/notifications/rules', [
            'name' => 'Critical Deployment Failures',
            'event_type' => 'deployment',
            'conditions' => [
                ['field' => 'status', 'operator' => '==', 'value' => 'failed'],
            ],
            'actions' => [
                [
                    'type' => 'notify',
                    'channel_id' => $channel->id,
                ],
            ],
            'priority' => 100,
            'enabled' => true,
        ]);

        $response->assertStatus(201);
        $this->assertDatabaseHas('notification_rules', [
            'name' => 'Critical Deployment Failures',
        ]);
    }

    /** @test */
    public function it_dispatches_deployment_started_event()
    {
        Event::fake();

        $deployment = Deployment::factory()->create();

        event(new DeploymentStarted($deployment));

        Event::assertDispatched(DeploymentStarted::class);
    }

    /** @test */
    public function it_handles_slack_interaction()
    {
        $payload = json_encode([
            'type' => 'block_actions',
            'actions' => [
                [
                    'type' => 'button',
                    'value' => json_encode(['action' => 'approve', 'pr' => 123]),
                ],
            ],
            'user' => ['name' => 'testuser'],
        ]);

        $response = $this->postJson('/api/webhooks/slack', [
            'payload' => $payload,
        ]);

        $response->assertStatus(200);
    }

    /** @test */
    public function it_can_get_current_oncall()
    {
        $response = $this->getJson('/api/notifications/on-call/current');

        $response->assertStatus(200)
            ->assertJsonStructure(['current']);
    }
}

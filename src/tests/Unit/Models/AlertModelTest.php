<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\Alert;
use App\Models\LxcContainer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Alert Model Test
 *
 * Tests for the Alert model.
 *
 * @package Tests\Unit\Models
 */
class AlertModelTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test creating an alert
     */
    public function test_create_alert(): void
    {
        $alert = Alert::factory()->create([
            'severity' => 'critical',
            'title' => 'Test Alert',
            'message' => 'This is a test alert',
        ]);

        $this->assertDatabaseHas('alerts', [
            'id' => $alert->id,
            'severity' => 'critical',
            'title' => 'Test Alert',
        ]);
    }

    /**
     * Test alert polymorphic relationship to container
     */
    public function test_alert_polymorphic_relationship(): void
    {
        $container = LxcContainer::factory()->create();
        $alert = Alert::factory()->create([
            'resource_type' => 'container',
            'resource_id' => $container->id,
        ]);

        $this->assertEquals('container', $alert->resource_type);
        $this->assertEquals($container->id, $alert->resource_id);
    }

    /**
     * Test scope critical
     */
    public function test_scope_critical(): void
    {
        Alert::factory()->create(['severity' => 'critical']);
        Alert::factory()->create(['severity' => 'high']);

        $critical = Alert::critical()->get();

        $this->assertCount(1, $critical);
        $this->assertEquals('critical', $critical->first()->severity);
    }

    /**
     * Test scope high
     */
    public function test_scope_high(): void
    {
        Alert::factory()->create(['severity' => 'high']);
        Alert::factory()->create(['severity' => 'low']);

        $high = Alert::high()->get();

        $this->assertCount(1, $high);
        $this->assertEquals('high', $high->first()->severity);
    }

    /**
     * Test scope unresolved
     */
    public function test_scope_unresolved(): void
    {
        Alert::factory()->create(['is_resolved' => false]);
        Alert::factory()->create(['is_resolved' => true]);

        $unresolved = Alert::unresolved()->get();

        $this->assertCount(1, $unresolved);
        $this->assertFalse($unresolved->first()->is_resolved);
    }

    /**
     * Test scope resolved
     */
    public function test_scope_resolved(): void
    {
        Alert::factory()->create(['is_resolved' => true]);
        Alert::factory()->create(['is_resolved' => false]);

        $resolved = Alert::resolved()->get();

        $this->assertCount(1, $resolved);
        $this->assertTrue($resolved->first()->is_resolved);
    }

    /**
     * Test scope recent
     */
    public function test_scope_recent(): void
    {
        Alert::factory()->create(['created_at' => now()->subHours(2)]);
        Alert::factory()->create(['created_at' => now()->subDays(2)]);

        $recent = Alert::recent(24)->get();

        $this->assertCount(1, $recent);
    }

    /**
     * Test scope by resource
     */
    public function test_scope_by_resource(): void
    {
        $container = LxcContainer::factory()->create();

        Alert::factory()->create([
            'resource_type' => 'container',
            'resource_id' => $container->id,
        ]);

        Alert::factory()->create([
            'resource_type' => 'server',
            'resource_id' => 1,
        ]);

        $alerts = Alert::byResource('container', $container->id)->get();

        $this->assertCount(1, $alerts);
        $this->assertEquals('container', $alerts->first()->resource_type);
    }

    /**
     * Test resolve method
     */
    public function test_resolve_method(): void
    {
        $alert = Alert::factory()->create(['is_resolved' => false]);

        $alert->resolve('Fixed by restarting the container');

        $this->assertTrue($alert->is_resolved);
        $this->assertEquals('Fixed by restarting the container', $alert->resolution_notes);
        $this->assertNotNull($alert->resolved_at);
    }

    /**
     * Test reopen method
     */
    public function test_reopen_method(): void
    {
        $alert = Alert::factory()->create([
            'is_resolved' => true,
            'resolved_at' => now(),
        ]);

        $alert->reopen();

        $this->assertFalse($alert->is_resolved);
        $this->assertNull($alert->resolved_at);
    }

    /**
     * Test severity levels
     */
    public function test_severity_levels(): void
    {
        $critical = Alert::factory()->create(['severity' => 'critical']);
        $high = Alert::factory()->create(['severity' => 'high']);
        $medium = Alert::factory()->create(['severity' => 'medium']);
        $low = Alert::factory()->create(['severity' => 'low']);

        $this->assertEquals('critical', $critical->severity);
        $this->assertEquals('high', $high->severity);
        $this->assertEquals('medium', $medium->severity);
        $this->assertEquals('low', $low->severity);
    }

    /**
     * Test fillable attributes
     */
    public function test_fillable_attributes(): void
    {
        $alert = new Alert();

        $expectedFillable = [
            'severity',
            'title',
            'message',
            'resource_type',
            'resource_id',
            'is_resolved',
            'resolution_notes',
            'resolved_at',
            'resolved_by',
        ];

        foreach ($expectedFillable as $attribute) {
            $this->assertContains($attribute, $alert->getFillable());
        }
    }

    /**
     * Test casts configuration
     */
    public function test_casts_configuration(): void
    {
        $alert = new Alert();

        $expectedCasts = [
            'is_resolved' => 'boolean',
            'resolved_at' => 'datetime',
            'created_at' => 'datetime',
            'updated_at' => 'datetime',
        ];

        foreach ($expectedCasts as $key => $type) {
            $this->assertArrayHasKey($key, $alert->getCasts());
        }
    }

    /**
     * Test scope by severity
     */
    public function test_scope_by_severity(): void
    {
        Alert::factory()->count(3)->create(['severity' => 'critical']);
        Alert::factory()->count(2)->create(['severity' => 'high']);

        $criticalAlerts = Alert::bySeverity('critical')->get();
        $highAlerts = Alert::bySeverity('high')->get();

        $this->assertCount(3, $criticalAlerts);
        $this->assertCount(2, $highAlerts);
    }

    /**
     * Test scope by type
     */
    public function test_scope_by_type(): void
    {
        Alert::factory()->count(3)->create(['alert_type' => 'performance']);
        Alert::factory()->count(2)->create(['alert_type' => 'security']);

        $performanceAlerts = Alert::byType('performance')->get();
        $securityAlerts = Alert::byType('security')->get();

        $this->assertCount(3, $performanceAlerts);
        $this->assertCount(2, $securityAlerts);
    }

    /**
     * Test auto-resolution after TTL
     */
    public function test_auto_resolution_after_ttl(): void
    {
        $alert = Alert::factory()->create([
            'auto_resolve_after_hours' => 24,
            'created_at' => now()->subHours(25),
        ]);

        $this->assertTrue($alert->shouldAutoResolve());
    }

    /**
     * Test alert priority calculation
     */
    public function test_alert_priority_calculation(): void
    {
        $critical = Alert::factory()->create(['severity' => 'critical', 'is_resolved' => false]);
        $high = Alert::factory()->create(['severity' => 'high', 'is_resolved' => false]);
        $resolved = Alert::factory()->create(['severity' => 'critical', 'is_resolved' => true]);

        $this->assertEquals(100, $critical->priority);
        $this->assertEquals(80, $high->priority);
        $this->assertEquals(0, $resolved->priority);
    }
}

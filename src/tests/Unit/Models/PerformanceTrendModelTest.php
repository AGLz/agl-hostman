<?php

declare(strict_types=1);

namespace Tests\Unit\Models;

use App\Models\PerformanceTrend;
use App\Models\LxcContainer;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Performance Trend Model Test
 *
 * Tests for the PerformanceTrend model.
 *
 * @package Tests\Unit\Models
 */
class PerformanceTrendModelTest extends TestCase
{
    use RefreshDatabase;

    /**
     * Test creating a performance trend
     */
    public function test_create_performance_trend(): void
    {
        $trend = PerformanceTrend::factory()->create([
            'resource_type' => 'container',
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'value' => 45.5,
            'unit' => '%',
        ]);

        $this->assertDatabaseHas('performance_trends', [
            'id' => $trend->id,
            'resource_type' => 'container',
            'metric_type' => 'cpu',
            'value' => 45.5,
        ]);
    }

    /**
     * Test scope by resource
     */
    public function test_scope_by_resource(): void
    {
        PerformanceTrend::factory()->count(5)->create([
            'resource_type' => 'container',
            'resource_id' => '101',
        ]);

        PerformanceTrend::factory()->count(3)->create([
            'resource_type' => 'container',
            'resource_id' => '102',
        ]);

        $trends = PerformanceTrend::byResource('container', '101')->get();

        $this->assertCount(5, $trends);
        $this->assertEquals('101', $trends->first()->resource_id);
    }

    /**
     * Test scope by metric type
     */
    public function test_scope_by_metric_type(): void
    {
        PerformanceTrend::factory()->count(5)->create(['metric_type' => 'cpu']);
        PerformanceTrend::factory()->count(3)->create(['metric_type' => 'memory']);

        $cpuTrends = PerformanceTrend::byMetricType('cpu')->get();
        $memoryTrends = PerformanceTrend::byMetricType('memory')->get();

        $this->assertCount(5, $cpuTrends);
        $this->assertCount(3, $memoryTrends);
    }

    /**
     * Test scope recent
     */
    public function test_scope_recent(): void
    {
        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(2),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subDays(2),
        ]);

        $recent = PerformanceTrend::recent(24)->get();

        $this->assertCount(1, $recent);
    }

    /**
     * Test scope between dates
     */
    public function test_scope_between_dates(): void
    {
        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(2),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subDays(2),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subDays(5),
        ]);

        $start = now()->subDays(3);
        $end = now();

        $trends = PerformanceTrend::betweenDates($start, $end)->get();

        $this->assertCount(1, $trends);
    }

    /**
     * Test scope ordered
     */
    public function test_scope_ordered(): void
    {
        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(3),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(1),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(2),
        ]);

        $trends = PerformanceTrend::ordered()->get();

        $this->assertEquals(
            now()->subHours(3)->format('Y-m-d H:i:s'),
            $trends->last()->recorded_at->format('Y-m-d H:i:s')
        );
    }

    /**
     * Test aggregation methods
     */
    public function test_aggregation_methods(): void
    {
        PerformanceTrend::factory()->create([
            'metric_type' => 'cpu',
            'value' => 30.0,
            'recorded_at' => now()->subHours(3),
        ]);

        PerformanceTrend::factory()->create([
            'metric_type' => 'cpu',
            'value' => 50.0,
            'recorded_at' => now()->subHours(2),
        ]);

        PerformanceTrend::factory()->create([
            'metric_type' => 'cpu',
            'value' => 70.0,
            'recorded_at' => now()->subHours(1),
        ]);

        $container = LxcContainer::factory()->create(['vmid' => '101']);

        $avg = PerformanceTrend::where('resource_id', $container->id)
            ->where('metric_type', 'cpu')
            ->avg('value');

        $min = PerformanceTrend::where('resource_id', $container->id)
            ->where('metric_type', 'cpu')
            ->min('value');

        $max = PerformanceTrend::where('resource_id', $container->id)
            ->where('metric_type', 'cpu')
            ->max('value');

        $this->assertEquals(50.0, $avg);
        $this->assertEquals(30.0, $min);
        $this->assertEquals(70.0, $max);
    }

    /**
     * Test metric value range calculation
     */
    public function test_metric_value_range_calculation(): void
    {
        $container = LxcContainer::factory()->create();

        PerformanceTrend::factory()->create([
            'resource_id' => $container->id,
            'metric_type' => 'cpu',
            'value' => 20.0,
        ]);

        PerformanceTrend::factory()->create([
            'resource_id' => $container->id,
            'metric_type' => 'cpu',
            'value' => 80.0,
        ]);

        $range = PerformanceTrend::where('resource_id', $container->id)
            ->where('metric_type', 'cpu')
            ->selectRaw('MAX(value) - MIN(value) as range')
            ->value('range');

        $this->assertEquals(60.0, $range);
    }

    /**
     * Test fillable attributes
     */
    public function test_fillable_attributes(): void
    {
        $trend = new PerformanceTrend();

        $expectedFillable = [
            'resource_type',
            'resource_id',
            'metric_type',
            'value',
            'unit',
            'metadata',
            'recorded_at',
        ];

        foreach ($expectedFillable as $attribute) {
            $this->assertContains($attribute, $trend->getFillable());
        }
    }

    /**
     * Test casts configuration
     */
    public function test_casts_configuration(): void
    {
        $trend = new PerformanceTrend();

        $this->assertArrayHasKey('metadata', $trend->getCasts());
        $this->assertArrayHasKey('recorded_at', $trend->getCasts());
        $this->assertArrayHasKey('created_at', $trend->getCasts());
    }

    /**
     * Test scope latest per resource
     */
    public function test_scope_latest_per_resource(): void
    {
        PerformanceTrend::factory()->create([
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'recorded_at' => now()->subHours(2),
        ]);

        PerformanceTrend::factory()->create([
            'resource_id' => '101',
            'metric_type' => 'cpu',
            'recorded_at' => now()->subHours(1),
        ]);

        PerformanceTrend::factory()->create([
            'resource_id' => '102',
            'metric_type' => 'cpu',
            'recorded_at' => now()->subHours(1),
        ]);

        $latestTrends = PerformanceTrend::latestPerResource(['101', '102'], 'cpu')->get();

        $this->assertCount(2, $latestTrends);
    }

    /**
     * Test metric types
     */
    public function test_valid_metric_types(): void
    {
        $cpu = PerformanceTrend::factory()->create(['metric_type' => 'cpu']);
        $memory = PerformanceTrend::factory()->create(['metric_type' => 'memory']);
        $disk = PerformanceTrend::factory()->create(['metric_type' => 'disk']);
        $network = PerformanceTrend::factory()->create(['metric_type' => 'network']);

        $this->assertEquals('cpu', $cpu->metric_type);
        $this->assertEquals('memory', $memory->metric_type);
        $this->assertEquals('disk', $disk->metric_type);
        $this->assertEquals('network', $network->metric_type);
    }

    /**
     * Test scope for time range
     */
    public function test_scope_for_time_range(): void
    {
        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(1),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(5),
        ]);

        PerformanceTrend::factory()->create([
            'recorded_at' => now()->subHours(10),
        ]);

        $trends = PerformanceTrend::forTimeRange(2, 8)->get();

        $this->assertCount(1, $trends);
        $this->assertEquals(5, $trends->first()->recorded_at->diffInHours(now()));
    }

    /**
     * Test percentiles calculation
     */
    public function test_percentiles_calculation(): void
    {
        PerformanceTrend::factory()->create(['value' => 10]);
        PerformanceTrend::factory()->create(['value' => 20]);
        PerformanceTrend::factory()->create(['value' => 30]);
        PerformanceTrend::factory()->create(['value' => 40]);
        PerformanceTrend::factory()->create(['value' => 50]);

        $p50 = PerformanceTrend::selectRaw('PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY value) as p50')
            ->value('p50');

        $this->assertEquals(30.0, $p50);
    }
}

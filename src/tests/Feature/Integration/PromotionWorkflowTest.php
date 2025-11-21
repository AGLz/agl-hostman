<?php

declare(strict_types=1);

namespace Tests\Feature\Integration;

use App\Models\User;
use App\Models\Environment;
use App\Models\Promotion;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * Promotion Workflow Integration Tests
 *
 * Tests the complete promotion workflow:
 * - QA → UAT promotion request creation
 * - Approval gate enforcement
 * - Smoke test execution during promotion
 * - Automatic rollback on smoke test failure
 * - Promotion status tracking
 * - Unauthorized promotion prevention
 *
 * @group integration
 * @group promotion
 */
class PromotionWorkflowTest extends TestCase
{
    use RefreshDatabase;

    private User $adminUser;
    private User $regularUser;
    private Environment $qaEnv;
    private Environment $uatEnv;

    protected function setUp(): void
    {
        parent::setUp();

        // Create test users
        $this->adminUser = User::factory()->create([
            'name' => 'Admin User',
            'email' => 'admin@test.com',
            'role' => 'admin',
            'is_admin' => true,
        ]);

        $this->regularUser = User::factory()->create([
            'name' => 'Regular User',
            'email' => 'user@test.com',
            'role' => 'developer',
            'is_admin' => false,
        ]);

        // Create test environments
        $this->qaEnv = Environment::factory()->create([
            'name' => 'QA Environment',
            'type' => 'qa',
            'git_branch' => 'develop',
            'auto_deploy' => true,
            'auto_test' => true,
        ]);

        $this->uatEnv = Environment::factory()->create([
            'name' => 'UAT Environment',
            'type' => 'uat',
            'git_branch' => 'release',
            'auto_deploy' => false,
            'auto_test' => true,
        ]);
    }

    /**
     * Test QA to UAT promotion request creation
     *
     * @test
     */
    public function can_create_qa_to_uat_promotion_request(): void
    {
        $response = $this->actingAs($this->regularUser)
            ->postJson('/api/promotion/qa-to-uat', [
                'source_version' => 'qa-1a2b3c4',
                'notes' => 'Promoting build qa-1a2b3c4 to UAT',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Promotion request created successfully',
            ])
            ->assertJsonStructure([
                'success',
                'message',
                'data' => [
                    'promotion_id',
                    'status',
                    'source_environment',
                    'target_environment',
                    'source_version',
                ],
            ]);

        $this->assertDatabaseHas('promotions', [
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_PENDING,
        ]);
    }

    /**
     * Test approval gate enforcement
     *
     * @test
     */
    public function regular_user_cannot_approve_promotion(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_PENDING,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        $response = $this->actingAs($this->regularUser)
            ->postJson("/api/promotion/{$promotion->id}/approve", [
                'approval_notes' => 'Attempting to approve',
            ]);

        $response->assertStatus(403)
            ->assertJson([
                'success' => false,
                'message' => 'Insufficient permissions to approve promotions',
            ]);

        $this->assertDatabaseHas('promotions', [
            'id' => $promotion->id,
            'status' => Promotion::STATUS_PENDING,
            'approved_by' => null,
        ]);
    }

    /**
     * Test admin can approve promotion
     *
     * @test
     */
    public function admin_can_approve_promotion(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_PENDING,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        $response = $this->actingAs($this->adminUser)
            ->postJson("/api/promotion/{$promotion->id}/approve", [
                'approval_notes' => 'Approved for UAT deployment',
            ]);

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
                'message' => 'Promotion approved successfully',
            ]);

        $this->assertDatabaseHas('promotions', [
            'id' => $promotion->id,
            'status' => Promotion::STATUS_APPROVED,
            'approved_by' => $this->adminUser->id,
        ]);

        $promotion->refresh();
        $this->assertNotNull($promotion->approved_at);
        $this->assertEquals('Approved for UAT deployment', $promotion->approval_notes);
    }

    /**
     * Test cannot approve non-pending promotion
     *
     * @test
     */
    public function cannot_approve_non_pending_promotion(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_COMPLETED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
            'completed_at' => now(),
        ]);

        $response = $this->actingAs($this->adminUser)
            ->postJson("/api/promotion/{$promotion->id}/approve", [
                'approval_notes' => 'Attempting to approve completed',
            ]);

        $response->assertStatus(400)
            ->assertJson([
                'success' => false,
                'message' => 'Promotion is not in pending state',
            ]);
    }

    /**
     * Test promotion status tracking
     *
     * @test
     */
    public function can_get_promotion_status(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_APPROVED,
            'requested_by' => $this->regularUser->id,
            'approved_by' => $this->adminUser->id,
            'requested_at' => now()->subHour(),
            'approved_at' => now()->subMinutes(30),
        ]);

        $response = $this->getJson("/api/promotion/{$promotion->id}/status");

        $response->assertStatus(200)
            ->assertJson([
                'success' => true,
            ])
            ->assertJsonStructure([
                'success',
                'data' => [
                    'id',
                    'status',
                    'source_environment',
                    'target_environment',
                    'source_version',
                    'requested_by',
                    'requested_at',
                    'approved_by',
                    'approved_at',
                ],
            ]);
    }

    /**
     * Test promotion model helper methods
     *
     * @test
     */
    public function promotion_model_helper_methods_work(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_PENDING,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        $this->assertTrue($promotion->isPending());
        $this->assertFalse($promotion->isApproved());
        $this->assertFalse($promotion->isCompleted());
        $this->assertFalse($promotion->isFailed());

        // Approve it
        $promotion->approve($this->adminUser->id, 'Test approval');

        $this->assertFalse($promotion->isPending());
        $this->assertTrue($promotion->isApproved());

        // Complete it
        $promotion->complete('uat-1a2b3c4', [
            'total' => 10,
            'passed' => 10,
            'failed' => 0,
        ]);

        $this->assertTrue($promotion->isCompleted());
        $this->assertEquals('uat-1a2b3c4', $promotion->target_version);
    }

    /**
     * Test smoke test results storage
     *
     * @test
     */
    public function can_store_smoke_test_results(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_APPROVED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        $smokeTestResults = [
            'total' => 12,
            'passed' => 11,
            'failed' => 1,
            'duration' => 87.5,
            'success_rate' => 91.67,
            'tests' => [
                ['name' => 'health_check', 'status' => 'passed'],
                ['name' => 'database_connection', 'status' => 'passed'],
                ['name' => 'redis_connection', 'status' => 'failed'],
            ],
        ];

        $promotion->complete('uat-1a2b3c4', $smokeTestResults);

        $this->assertEquals($smokeTestResults, $promotion->smoke_test_results);

        $summary = $promotion->getSmokeTestSummary();
        $this->assertEquals(12, $summary['total']);
        $this->assertEquals(11, $summary['passed']);
        $this->assertEquals(1, $summary['failed']);
        $this->assertEquals(91.67, $summary['success_rate']);
    }

    /**
     * Test automatic rollback on smoke test failure
     *
     * @test
     */
    public function marks_promotion_as_failed_when_smoke_tests_fail(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_APPROVED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        $smokeTestResults = [
            'total' => 10,
            'passed' => 5,
            'failed' => 5,
            'duration' => 120.0,
            'success_rate' => 50.0,
        ];

        $promotion->markFailed($smokeTestResults);

        $this->assertTrue($promotion->isFailed());
        $this->assertEquals($smokeTestResults, $promotion->smoke_test_results);
        $this->assertNotNull($promotion->completed_at);
    }

    /**
     * Test promotion duration calculation
     *
     * @test
     */
    public function can_calculate_promotion_duration(): void
    {
        $requestedAt = now()->subMinutes(30);
        $completedAt = now();

        $promotion = Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-1a2b3c4',
            'status' => Promotion::STATUS_COMPLETED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => $requestedAt,
            'completed_at' => $completedAt,
        ]);

        $duration = $promotion->getDuration();
        $this->assertNotNull($duration);
        $this->assertEquals(1800, $duration); // 30 minutes = 1800 seconds
    }

    /**
     * Test scope filters
     *
     * @test
     */
    public function scope_filters_work_correctly(): void
    {
        // Create promotions with different statuses
        Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-pending',
            'status' => Promotion::STATUS_PENDING,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-approved',
            'status' => Promotion::STATUS_APPROVED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
        ]);

        Promotion::create([
            'source_environment_id' => $this->qaEnv->id,
            'target_environment_id' => $this->uatEnv->id,
            'source_version' => 'qa-completed',
            'status' => Promotion::STATUS_COMPLETED,
            'requested_by' => $this->regularUser->id,
            'requested_at' => now(),
            'completed_at' => now(),
        ]);

        $this->assertCount(1, Promotion::pending()->get());
        $this->assertCount(1, Promotion::approved()->get());
        $this->assertCount(1, Promotion::completed()->get());
        $this->assertCount(3, Promotion::all());
    }
}

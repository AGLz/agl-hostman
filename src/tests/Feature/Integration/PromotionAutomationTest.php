<?php

declare(strict_types=1);

namespace Tests\Feature\Integration;

use Tests\TestCase;
use App\Models\Environment;
use App\Models\Promotion;
use App\Models\User;
use App\Services\Deployment\PromotionWorkflowService;
use App\Services\Deployment\PromotionApprovalService;
use Illuminate\Foundation\Testing\RefreshDatabase;

class PromotionAutomationTest extends TestCase
{
    use RefreshDatabase;

    private PromotionWorkflowService $workflowService;
    private PromotionApprovalService $approvalService;

    protected function setUp(): void
    {
        parent::setUp();
        
        $this->workflowService = $this->app->make(PromotionWorkflowService::class);
        $this->approvalService = $this->app->make(PromotionApprovalService::class);

        // Create test environments
        Environment::create(['type' => 'development', 'status' => 'active', 'current_version' => 'v1.0.0']);
        Environment::create(['type' => 'qa', 'status' => 'active', 'current_version' => 'v1.0.0']);
        Environment::create(['type' => 'uat', 'status' => 'active', 'current_version' => 'v1.0.0']);
        Environment::create(['type' => 'production', 'status' => 'active', 'current_version' => 'v1.0.0']);
    }

    /** @test */
    public function auto_promotes_from_dev_to_qa_on_develop_branch_push(): void
    {
        $payload = [
            'ref' => 'refs/heads/develop',
            'after' => 'abc123def456',
            'pusher' => ['name' => 'test-user'],
        ];

        $result = $this->workflowService->autoPromoteDevToQA($payload);

        $this->assertTrue($result['success']);
        $this->assertArrayHasKey('promotion_id', $result);

        $promotion = Promotion::find($result['promotion_id']);
        $this->assertNotNull($promotion);
        $this->assertTrue($promotion->is_automatic);
        $this->assertEquals('abc123d', $promotion->source_version);
    }

    /** @test */
    public function requires_1_approval_for_qa_to_uat_promotion(): void
    {
        $leadDeveloper = User::factory()->create();
        $leadDeveloper->assignRole('lead-developer');

        $promotion = $this->workflowService->promoteQAtoUAT('v1.2.3', 'test@example.com');

        $this->assertEquals('pending_approval', $promotion->status);
        $this->assertEquals(1, $promotion->requires_approvals);

        // Approve
        $this->approvalService->approve($promotion, $leadDeveloper, 'Approved for UAT');

        $promotion->refresh();
        $this->assertEquals('approved', $promotion->status);
        $this->assertContains($leadDeveloper->id, $promotion->approved_by);
    }

    /** @test */
    public function requires_2_approvals_for_uat_to_production_promotion(): void
    {
        $leadDeveloper = User::factory()->create();
        $leadDeveloper->assignRole('lead-developer');

        $admin = User::factory()->create();
        $admin->assignRole('admin');

        $promotion = $this->workflowService->promoteUATtoProduction('v1.2.3', 'test@example.com');

        $this->assertEquals('pending_approval', $promotion->status);
        $this->assertEquals(2, $promotion->requires_approvals);

        // First approval
        $this->approvalService->approve($promotion, $leadDeveloper);

        $promotion->refresh();
        $this->assertEquals('pending_approval', $promotion->status); // Still pending
        $this->assertEquals(1, $promotion->getRemainingApprovals());

        // Second approval
        $this->approvalService->approve($promotion, $admin);

        $promotion->refresh();
        $this->assertEquals('approved', $promotion->status);
        $this->assertEquals(0, $promotion->getRemainingApprovals());
    }

    /** @test */
    public function checks_promotion_eligibility(): void
    {
        $eligibility = $this->workflowService->checkPromotionEligibility('qa', 'uat');

        $this->assertArrayHasKey('eligible', $eligibility);
        $this->assertArrayHasKey('reasons', $eligibility);
        $this->assertArrayHasKey('checks', $eligibility);
    }

    /** @test */
    public function tracks_promotion_metrics_correctly(): void
    {
        // Create sample promotions
        Promotion::factory()->count(5)->create([
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        Promotion::factory()->count(2)->create([
            'status' => 'failed',
        ]);

        $controller = new \App\Http\Controllers\PromotionDashboardController();
        $response = $controller->getPromotionMetrics();

        $data = $response->getData(true);

        $this->assertArrayHasKey('dev_to_qa', $data);
        $this->assertArrayHasKey('success_rate', $data['dev_to_qa']);
    }

    /** @test */
    public function handles_approval_expiration(): void
    {
        $promotion = Promotion::factory()->create([
            'status' => 'pending_approval',
            'approval_deadline' => now()->subHour(),
        ]);

        $expired = $this->approvalService->cancelExpiredApprovals();

        $this->assertGreaterThan(0, $expired);
    }

    /** @test */
    public function gets_pending_approvals_for_user(): void
    {
        $approver = User::factory()->create();
        $approver->assignRole('lead-developer');

        $promotion = Promotion::factory()->create([
            'status' => 'pending_approval',
            'requires_approvals' => 1,
        ]);

        $this->approvalService->requestApproval($promotion, ['lead-developer'], 1);

        $pending = $this->approvalService->getPendingApprovals($approver);

        $this->assertNotEmpty($pending);
        $this->assertEquals($promotion->id, $pending[0]['promotion_id']);
    }

    /** @test */
    public function creates_promotion_with_workflow_fields(): void
    {
        $promotion = Promotion::create([
            'source_environment_id' => Environment::where('type', 'qa')->first()->id,
            'target_environment_id' => Environment::where('type', 'uat')->first()->id,
            'source_version' => 'v1.2.3',
            'status' => 'pending_approval',
            'requested_by' => 'test@example.com',
            'is_automatic' => false,
            'requires_approvals' => 1,
            'deployment_logs' => [],
        ]);

        $this->assertNotNull($promotion->id);
        $this->assertFalse($promotion->is_automatic);
        $this->assertEquals(1, $promotion->requires_approvals);
        $this->assertIsArray($promotion->deployment_logs);
    }

    /** @test */
    public function validates_github_webhook_signature(): void
    {
        $payload = json_encode(['ref' => 'refs/heads/develop']);
        $secret = 'test-secret';

        config(['deployment.github_webhook_secret' => $secret]);

        $signature = 'sha256=' . hash_hmac('sha256', $payload, $secret);

        $response = $this->postJson('/api/webhooks/github/push', json_decode($payload, true), [
            'X-Hub-Signature-256' => $signature,
        ]);

        $response->assertSuccessful();
    }

    /** @test */
    public function promotion_model_has_helper_methods(): void
    {
        $user = User::factory()->create();

        $promotion = Promotion::factory()->create([
            'requires_approvals' => 2,
            'approved_by' => [$user->id],
        ]);

        $this->assertTrue($promotion->isApprovedBy($user));
        $this->assertEquals(1, $promotion->getRemainingApprovals());
    }
}

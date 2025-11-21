<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Promotion;
use App\Models\Environment;
use App\Services\Deployment\DeploymentWorkflowService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;
use Exception;

/**
 * Promotion Controller
 *
 * Handles manual promotion workflow between environments:
 * - QA → UAT
 * - UAT → Production
 *
 * Includes approval gates, smoke tests, and rollback capabilities
 */
class PromotionController extends Controller
{
    public function __construct(
        private readonly DeploymentWorkflowService $workflowService
    ) {}

    /**
     * Promote from QA to UAT
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function promoteQAtoUAT(Request $request): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'source_version' => 'required|string|max:255',
                'notes' => 'nullable|string|max:1000',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors(),
                ], 422);
            }

            // Get environments
            $qaEnv = Environment::where('type', 'qa')->firstOrFail();
            $uatEnv = Environment::where('type', 'uat')->firstOrFail();

            // Create promotion request
            $promotion = Promotion::create([
                'source_environment_id' => $qaEnv->id,
                'target_environment_id' => $uatEnv->id,
                'source_version' => $request->input('source_version'),
                'status' => Promotion::STATUS_PENDING,
                'requested_by' => $request->user()?->id,
                'requested_at' => now(),
            ]);

            Log::info('QA to UAT promotion requested', [
                'promotion_id' => $promotion->id,
                'source_version' => $request->input('source_version'),
                'requested_by' => $request->user()?->name,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Promotion request created successfully',
                'data' => [
                    'promotion_id' => $promotion->id,
                    'status' => $promotion->status,
                    'source_environment' => $qaEnv->type,
                    'target_environment' => $uatEnv->type,
                    'source_version' => $promotion->source_version,
                    'requested_at' => $promotion->requested_at,
                ],
            ]);

        } catch (Exception $e) {
            Log::error('QA to UAT promotion failed', [
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to create promotion request: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Approve UAT promotion
     *
     * @param Request $request
     * @param string $promotionId
     * @return JsonResponse
     */
    public function approveUATPromotion(Request $request, string $promotionId): JsonResponse
    {
        try {
            $validator = Validator::make($request->all(), [
                'approval_notes' => 'nullable|string|max:1000',
                'auto_deploy' => 'boolean',
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors(),
                ], 422);
            }

            $promotion = Promotion::findOrFail($promotionId);

            // Check if user has approval rights
            if (!$this->canApprovePromotion($request->user())) {
                return response()->json([
                    'success' => false,
                    'message' => 'Insufficient permissions to approve promotions',
                ], 403);
            }

            // Check if promotion is in pending state
            if (!$promotion->isPending()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Promotion is not in pending state',
                    'current_status' => $promotion->status,
                ], 400);
            }

            // Approve promotion
            $promotion->approve(
                $request->user()->id,
                $request->input('approval_notes')
            );

            Log::info('UAT promotion approved', [
                'promotion_id' => $promotion->id,
                'approved_by' => $request->user()->name,
            ]);

            // Auto-deploy if requested
            if ($request->boolean('auto_deploy', false)) {
                try {
                    $deployment = $this->workflowService->deployToUAT([
                        'promotion_id' => $promotion->id,
                        'source_version' => $promotion->source_version,
                    ]);

                    return response()->json([
                        'success' => true,
                        'message' => 'Promotion approved and deployment started',
                        'data' => [
                            'promotion_id' => $promotion->id,
                            'deployment_id' => $deployment->id,
                            'status' => $promotion->status,
                        ],
                    ]);
                } catch (Exception $e) {
                    return response()->json([
                        'success' => true,
                        'message' => 'Promotion approved but deployment failed: ' . $e->getMessage(),
                        'data' => [
                            'promotion_id' => $promotion->id,
                            'status' => $promotion->status,
                        ],
                    ]);
                }
            }

            return response()->json([
                'success' => true,
                'message' => 'Promotion approved successfully',
                'data' => [
                    'promotion_id' => $promotion->id,
                    'status' => $promotion->status,
                    'approved_by' => $request->user()->name,
                    'approved_at' => $promotion->approved_at,
                ],
            ]);

        } catch (Exception $e) {
            Log::error('UAT promotion approval failed', [
                'promotion_id' => $promotionId,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to approve promotion: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get promotion status
     *
     * @param string $promotionId
     * @return JsonResponse
     */
    public function getPromotionStatus(string $promotionId): JsonResponse
    {
        try {
            $promotion = Promotion::with([
                'sourceEnvironment',
                'targetEnvironment',
                'requester',
                'approver',
            ])->findOrFail($promotionId);

            return response()->json([
                'success' => true,
                'data' => [
                    'id' => $promotion->id,
                    'status' => $promotion->status,
                    'source_environment' => [
                        'id' => $promotion->sourceEnvironment->id,
                        'type' => $promotion->sourceEnvironment->type,
                        'name' => $promotion->sourceEnvironment->name,
                    ],
                    'target_environment' => [
                        'id' => $promotion->targetEnvironment->id,
                        'type' => $promotion->targetEnvironment->type,
                        'name' => $promotion->targetEnvironment->name,
                    ],
                    'source_version' => $promotion->source_version,
                    'target_version' => $promotion->target_version,
                    'requested_by' => $promotion->requester?->name,
                    'requested_at' => $promotion->requested_at,
                    'approved_by' => $promotion->approver?->name,
                    'approved_at' => $promotion->approved_at,
                    'completed_at' => $promotion->completed_at,
                    'approval_notes' => $promotion->approval_notes,
                    'smoke_test_summary' => $promotion->getSmokeTestSummary(),
                    'duration_seconds' => $promotion->getDuration(),
                ],
            ]);

        } catch (Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Promotion not found',
            ], 404);
        }
    }

    /**
     * Rollback promotion
     *
     * @param Request $request
     * @param string $promotionId
     * @return JsonResponse
     */
    public function rollbackPromotion(Request $request, string $promotionId): JsonResponse
    {
        try {
            $promotion = Promotion::findOrFail($promotionId);

            if (!$promotion->isCompleted()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Only completed promotions can be rolled back',
                    'current_status' => $promotion->status,
                ], 400);
            }

            // Perform rollback
            $rollbackResult = $this->workflowService->rollbackUAT($promotion->id);

            Log::info('UAT promotion rolled back', [
                'promotion_id' => $promotion->id,
                'rolled_back_by' => $request->user()?->name,
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Promotion rolled back successfully',
                'data' => $rollbackResult,
            ]);

        } catch (Exception $e) {
            Log::error('Promotion rollback failed', [
                'promotion_id' => $promotionId,
                'error' => $e->getMessage(),
            ]);

            return response()->json([
                'success' => false,
                'message' => 'Failed to rollback promotion: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Check if user can approve promotions
     *
     * @param \App\Models\User|null $user
     * @return bool
     */
    private function canApprovePromotion($user): bool
    {
        if (!$user) {
            return false;
        }

        // Check configured approver roles
        $approverRoles = explode(',', config('deployment.uat_approver_roles', 'admin,lead-developer'));

        // For now, check if user has admin role or is in approver list
        // TODO: Implement proper role-based access control
        return in_array($user->role ?? '', $approverRoles) || $user->is_admin ?? false;
    }
}

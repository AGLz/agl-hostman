<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Promotion;
use App\Services\Deployment\PromotionWorkflowService;
use App\Services\Deployment\PromotionApprovalService;
use Illuminate\Http\Request;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

class PromotionController extends Controller
{
    public function __construct(
        private readonly PromotionWorkflowService $workflowService,
        private readonly PromotionApprovalService $approvalService
    ) {}

    /**
     * Request promotion from QA to UAT
     */
    public function promoteQAtoUAT(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'version' => 'required|string',
        ]);

        try {
            $promotion = $this->workflowService->promoteQAtoUAT(
                version: $validated['version'],
                requestedBy: Auth::user()->email
            );

            return response()->json([
                'success' => true,
                'promotion' => $promotion,
                'message' => 'Promotion request created, awaiting approval',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Request promotion from UAT to Production
     */
    public function promoteUATtoProduction(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'version' => 'required|string',
        ]);

        try {
            $promotion = $this->workflowService->promoteUATtoProduction(
                version: $validated['version'],
                requestedBy: Auth::user()->email
            );

            return response()->json([
                'success' => true,
                'promotion' => $promotion,
                'message' => 'Promotion request created, awaiting 2 approvals',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Approve a promotion
     */
    public function approvePromotion(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'notes' => 'nullable|string',
        ]);

        try {
            $promotion = Promotion::findOrFail($id);
            
            $approval = $this->approvalService->approve(
                promotion: $promotion,
                approver: Auth::user(),
                notes: $validated['notes'] ?? null
            );

            return response()->json([
                'success' => true,
                'approval' => $approval,
                'promotion' => $promotion->fresh(),
                'message' => 'Promotion approved',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Reject a promotion
     */
    public function rejectPromotion(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'reason' => 'required|string',
        ]);

        try {
            $promotion = Promotion::findOrFail($id);
            
            $this->approvalService->reject(
                promotion: $promotion,
                approver: Auth::user(),
                reason: $validated['reason']
            );

            return response()->json([
                'success' => true,
                'message' => 'Promotion rejected',
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }

    /**
     * Get approval status for a promotion
     */
    public function getApprovalStatus(string $id): JsonResponse
    {
        $promotion = Promotion::findOrFail($id);
        
        $status = $this->approvalService->getApprovalStatus($promotion);

        return response()->json($status);
    }

    /**
     * Get pending approvals for authenticated user
     */
    public function getPendingApprovals(Request $request): JsonResponse
    {
        $approvals = $this->approvalService->getPendingApprovals(Auth::user());

        return response()->json([
            'approvals' => $approvals,
            'count' => count($approvals),
        ]);
    }

    /**
     * Rollback a promotion
     */
    public function rollbackPromotion(string $id): JsonResponse
    {
        try {
            $promotion = Promotion::findOrFail($id);
            
            $result = $this->workflowService->rollbackPromotion($promotion);

            return response()->json($result);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => $e->getMessage(),
            ], 400);
        }
    }
}

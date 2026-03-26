<?php

namespace App\Http\Controllers;

use App\Models\Environment;
use App\Models\ProductionApproval;
use App\Models\User;
use App\Services\DeploymentWorkflowService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Validator;

class ProductionApprovalController extends Controller
{
    public function __construct(
        private readonly DeploymentWorkflowService $deploymentService
    ) {}

    /**
     * Request production deployment with 2-level approval requirement.
     */
    public function requestProductionDeployment(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'environment_id' => ['required', 'exists:environments,id'],
            'deployment_version' => ['required', 'string', 'max:255'],
            'notes' => ['nullable', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $environment = Environment::findOrFail($request->environment_id);

            // Verify it's a production environment
            if ($environment->type !== 'production') {
                return response()->json([
                    'success' => false,
                    'message' => 'This endpoint is only for production environments',
                ], 400);
            }

            // Check if there's already a pending approval
            $existing = ProductionApproval::where('environment_id', $environment->id)
                ->where('deployment_version', $request->deployment_version)
                ->where('status', 'pending')
                ->exists();

            if ($existing) {
                return response()->json([
                    'success' => false,
                    'message' => 'A pending approval already exists for this version',
                ], 409);
            }

            // Create first-level approval (lead-developer)
            $firstApproval = ProductionApproval::create([
                'environment_id' => $environment->id,
                'deployment_version' => $request->deployment_version,
                'approval_level' => 'first',
                'approver_role' => 'lead-developer',
                'status' => 'pending',
                'expires_at' => now()->addHours(24),
            ]);

            // Create second-level approval (admin)
            $secondApproval = ProductionApproval::create([
                'environment_id' => $environment->id,
                'deployment_version' => $request->deployment_version,
                'approval_level' => 'second',
                'approver_role' => 'admin',
                'status' => 'pending',
                'expires_at' => now()->addHours(24),
            ]);

            return response()->json([
                'success' => true,
                'message' => 'Production deployment approval request created',
                'data' => [
                    'environment' => $environment->only(['id', 'name', 'type']),
                    'version' => $request->deployment_version,
                    'approvals' => [
                        'first_level' => $firstApproval,
                        'second_level' => $secondApproval,
                    ],
                    'expires_at' => $firstApproval->expires_at,
                ],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create approval request',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Approve production deployment (requires appropriate role).
     */
    public function approveProductionDeployment(Request $request, string $approvalId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'notes' => ['nullable', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $approval = ProductionApproval::findOrFail($approvalId);
            $user = $request->user();

            // Verify user has required role
            if (! $user->hasRole($approval->approver_role)) {
                return response()->json([
                    'success' => false,
                    'message' => "You must have the '{$approval->approver_role}' role to approve this deployment",
                ], 403);
            }

            // Check if already approved or expired
            if (! $approval->isPending()) {
                return response()->json([
                    'success' => false,
                    'message' => "This approval is already {$approval->status}",
                ], 409);
            }

            // Approve
            $approval->approve($user, $request->notes);

            // Check if all approvals are complete
            $allApprovals = ProductionApproval::where('environment_id', $approval->environment_id)
                ->where('deployment_version', $approval->deployment_version)
                ->get();

            $allApproved = $allApprovals->every(fn ($a) => $a->status === 'approved');

            $response = [
                'success' => true,
                'message' => 'Approval recorded successfully',
                'data' => [
                    'approval' => $approval,
                    'all_approved' => $allApproved,
                ],
            ];

            if ($allApproved) {
                $response['message'] = 'All approvals complete. Deployment can proceed.';
                $response['data']['deployment_ready'] = true;
            } else {
                $pendingCount = $allApprovals->filter(fn ($a) => $a->isPending())->count();
                $response['data']['pending_approvals'] = $pendingCount;
            }

            return response()->json($response);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to record approval',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Reject production deployment.
     */
    public function rejectProductionDeployment(Request $request, string $approvalId): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'reason' => ['required', 'string'],
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $approval = ProductionApproval::findOrFail($approvalId);
            $user = $request->user();

            // Verify user has required role
            if (! $user->hasRole($approval->approver_role)) {
                return response()->json([
                    'success' => false,
                    'message' => "You must have the '{$approval->approver_role}' role to reject this deployment",
                ], 403);
            }

            // Reject
            $approval->reject($user, $request->reason);

            // Reject all related approvals
            ProductionApproval::where('environment_id', $approval->environment_id)
                ->where('deployment_version', $approval->deployment_version)
                ->where('status', 'pending')
                ->update(['status' => 'rejected']);

            return response()->json([
                'success' => true,
                'message' => 'Deployment rejected',
                'data' => [
                    'approval' => $approval,
                ],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to reject deployment',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get approval status for a deployment version.
     */
    public function getApprovalStatus(Request $request, string $environmentId): JsonResponse
    {
        try {
            $environment = Environment::findOrFail($environmentId);

            $validator = Validator::make($request->all(), [
                'version' => ['required', 'string'],
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'errors' => $validator->errors(),
                ], 422);
            }

            $approvals = ProductionApproval::where('environment_id', $environment->id)
                ->where('deployment_version', $request->version)
                ->with('approver:id,name,email')
                ->get();

            if ($approvals->isEmpty()) {
                return response()->json([
                    'success' => false,
                    'message' => 'No approval request found for this version',
                ], 404);
            }

            $allApproved = $approvals->every(fn ($a) => $a->status === 'approved');
            $anyRejected = $approvals->contains(fn ($a) => $a->status === 'rejected');
            $anyExpired = $approvals->contains(fn ($a) => $a->isExpired());

            return response()->json([
                'success' => true,
                'data' => [
                    'environment' => $environment->only(['id', 'name', 'type']),
                    'version' => $request->version,
                    'approvals' => $approvals,
                    'summary' => [
                        'total' => $approvals->count(),
                        'approved' => $approvals->where('status', 'approved')->count(),
                        'pending' => $approvals->where('status', 'pending')->count(),
                        'rejected' => $approvals->where('status', 'rejected')->count(),
                        'expired' => $approvals->filter(fn ($a) => $a->isExpired())->count(),
                        'all_approved' => $allApproved,
                        'any_rejected' => $anyRejected,
                        'any_expired' => $anyExpired,
                        'deployment_ready' => $allApproved && ! $anyRejected && ! $anyExpired,
                    ],
                ],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to get approval status',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * List all pending approvals (for the current user).
     */
    public function listPendingApprovals(Request $request): JsonResponse
    {
        try {
            $user = $request->user();
            $roles = $user->getRoleNames()->toArray();

            // Get approvals matching user's roles
            $approvals = ProductionApproval::where('status', 'pending')
                ->whereIn('approver_role', $roles)
                ->with(['environment', 'approver'])
                ->orderBy('created_at', 'desc')
                ->get();

            // Mark expired approvals
            foreach ($approvals as $approval) {
                if ($approval->isExpired()) {
                    $approval->markExpired();
                }
            }

            // Refresh to get updated statuses
            $approvals = $approvals->reject(fn ($a) => $a->status === 'expired');

            return response()->json([
                'success' => true,
                'data' => [
                    'approvals' => $approvals,
                    'count' => $approvals->count(),
                ],
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to list pending approvals',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

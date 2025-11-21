<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\Alert;
use App\Services\AlertService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Inertia\Inertia;
use Inertia\Response;

/**
 * AlertController - Manages alert center UI and API
 *
 * Provides both Inertia pages and JSON API endpoints
 * for alert management functionality
 */
class AlertController extends Controller
{
    public function __construct(
        protected AlertService $alertService
    ) {}

    /**
     * Display alert center page (Inertia)
     */
    public function index(): Response
    {
        $alerts = $this->alertService->getActiveAlerts();
        $stats = $this->alertService->getAlertStats();

        return Inertia::render('Alerts/Index', [
            'alerts' => $alerts,
            'stats' => $stats,
        ]);
    }

    /**
     * Get active alerts (API)
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function getActive(Request $request): JsonResponse
    {
        $type = $request->query('type');
        $alerts = $this->alertService->getActiveAlerts($type);

        return response()->json([
            'success' => true,
            'alerts' => $alerts,
            'count' => $alerts->count(),
        ]);
    }

    /**
     * Get alert history (API)
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function getHistory(Request $request): JsonResponse
    {
        $days = (int) $request->query('days', 7);
        $alerts = $this->alertService->getAlertHistory($days);

        return response()->json([
            'success' => true,
            'alerts' => $alerts,
            'count' => $alerts->count(),
            'days' => $days,
        ]);
    }

    /**
     * Get alert statistics (API)
     *
     * @return JsonResponse
     */
    public function stats(): JsonResponse
    {
        $stats = $this->alertService->getAlertStats();

        return response()->json([
            'success' => true,
            'stats' => $stats,
        ]);
    }

    /**
     * Acknowledge an alert (API)
     *
     * @param Request $request
     * @param string $id
     * @return JsonResponse
     */
    public function acknowledge(Request $request, string $id): JsonResponse
    {
        $userId = $request->user()?->id ?? 'system';

        $success = $this->alertService->acknowledgeAlert($id, $userId);

        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to acknowledge alert. Alert may not exist or is already acknowledged.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Alert acknowledged successfully',
            'alert_id' => $id,
        ]);
    }

    /**
     * Resolve an alert (API)
     *
     * @param Request $request
     * @param string $id
     * @return JsonResponse
     */
    public function resolve(Request $request, string $id): JsonResponse
    {
        $userId = $request->user()?->id ?? 'system';

        $success = $this->alertService->resolveAlert($id, $userId);

        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to resolve alert. Alert may not exist.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => 'Alert resolved successfully',
            'alert_id' => $id,
        ]);
    }

    /**
     * Mute an alert (API)
     *
     * @param Request $request
     * @param string $id
     * @return JsonResponse
     */
    public function mute(Request $request, string $id): JsonResponse
    {
        $validated = $request->validate([
            'minutes' => 'required|integer|min:1|max:1440',
        ]);

        $success = $this->alertService->muteAlert($id, $validated['minutes']);

        if (!$success) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to mute alert. Alert may not exist.',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'message' => "Alert muted for {$validated['minutes']} minutes",
            'alert_id' => $id,
            'muted_for_minutes' => $validated['minutes'],
        ]);
    }

    /**
     * Bulk acknowledge alerts (API)
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function bulkAcknowledge(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'alert_ids' => 'required|array|min:1',
            'alert_ids.*' => 'required|uuid',
        ]);

        $userId = $request->user()?->id ?? 'system';
        $count = $this->alertService->bulkAcknowledge($validated['alert_ids'], $userId);

        return response()->json([
            'success' => true,
            'message' => "{$count} alerts acknowledged",
            'count' => $count,
        ]);
    }

    /**
     * Bulk resolve alerts (API)
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function bulkResolve(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'alert_ids' => 'required|array|min:1',
            'alert_ids.*' => 'required|uuid',
        ]);

        $userId = $request->user()?->id ?? 'system';
        $count = $this->alertService->bulkResolve($validated['alert_ids'], $userId);

        return response()->json([
            'success' => true,
            'message' => "{$count} alerts resolved",
            'count' => $count,
        ]);
    }
}

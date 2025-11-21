<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Models\AlertRule;
use App\Services\AlertRuleEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Str;

/**
 * AlertRuleController - Manages alert rules
 *
 * Provides API endpoints for creating, updating, and testing alert rules
 */
class AlertRuleController extends Controller
{
    public function __construct(
        protected AlertRuleEngine $ruleEngine
    ) {}

    /**
     * List all alert rules
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function index(Request $request): JsonResponse
    {
        $query = AlertRule::query();

        // Filter by type
        if ($request->has('type')) {
            $query->where('rule_type', $request->query('type'));
        }

        // Filter by enabled status
        if ($request->has('enabled')) {
            $enabled = filter_var($request->query('enabled'), FILTER_VALIDATE_BOOLEAN);
            $query->where('enabled', $enabled);
        }

        $rules = $query->orderBy('name')->get();

        return response()->json([
            'success' => true,
            'rules' => $rules,
            'count' => $rules->count(),
        ]);
    }

    /**
     * Create a new alert rule
     *
     * @param Request $request
     * @return JsonResponse
     */
    public function store(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'name' => 'required|string|max:255',
            'description' => 'nullable|string',
            'rule_type' => 'required|in:threshold,pattern,anomaly',
            'conditions' => 'required|array',
            'actions' => 'required|array',
            'enabled' => 'boolean',
            'cooldown_minutes' => 'integer|min:1|max:1440',
        ]);

        $rule = AlertRule::create([
            'id' => Str::uuid(),
            'name' => $validated['name'],
            'description' => $validated['description'] ?? null,
            'rule_type' => $validated['rule_type'],
            'conditions' => $validated['conditions'],
            'actions' => $validated['actions'],
            'enabled' => $validated['enabled'] ?? true,
            'cooldown_minutes' => $validated['cooldown_minutes'] ?? 15,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Alert rule created successfully',
            'rule' => $rule,
        ], 201);
    }

    /**
     * Get a specific alert rule
     *
     * @param string $id
     * @return JsonResponse
     */
    public function show(string $id): JsonResponse
    {
        $rule = AlertRule::find($id);

        if (!$rule) {
            return response()->json([
                'success' => false,
                'message' => 'Alert rule not found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'rule' => $rule,
        ]);
    }

    /**
     * Update an alert rule
     *
     * @param Request $request
     * @param string $id
     * @return JsonResponse
     */
    public function update(Request $request, string $id): JsonResponse
    {
        $rule = AlertRule::find($id);

        if (!$rule) {
            return response()->json([
                'success' => false,
                'message' => 'Alert rule not found',
            ], 404);
        }

        $validated = $request->validate([
            'name' => 'sometimes|string|max:255',
            'description' => 'nullable|string',
            'rule_type' => 'sometimes|in:threshold,pattern,anomaly',
            'conditions' => 'sometimes|array',
            'actions' => 'sometimes|array',
            'enabled' => 'boolean',
            'cooldown_minutes' => 'integer|min:1|max:1440',
        ]);

        $rule->update($validated);

        return response()->json([
            'success' => true,
            'message' => 'Alert rule updated successfully',
            'rule' => $rule->fresh(),
        ]);
    }

    /**
     * Delete an alert rule
     *
     * @param string $id
     * @return JsonResponse
     */
    public function destroy(string $id): JsonResponse
    {
        $rule = AlertRule::find($id);

        if (!$rule) {
            return response()->json([
                'success' => false,
                'message' => 'Alert rule not found',
            ], 404);
        }

        $rule->delete();

        return response()->json([
            'success' => true,
            'message' => 'Alert rule deleted successfully',
        ]);
    }

    /**
     * Toggle alert rule enabled status
     *
     * @param string $id
     * @return JsonResponse
     */
    public function toggle(string $id): JsonResponse
    {
        $rule = AlertRule::find($id);

        if (!$rule) {
            return response()->json([
                'success' => false,
                'message' => 'Alert rule not found',
            ], 404);
        }

        $newStatus = !$rule->enabled;
        $rule->update(['enabled' => $newStatus]);

        return response()->json([
            'success' => true,
            'message' => $newStatus ? 'Alert rule enabled' : 'Alert rule disabled',
            'rule' => $rule->fresh(),
        ]);
    }

    /**
     * Test an alert rule evaluation
     *
     * @param string $id
     * @return JsonResponse
     */
    public function test(string $id): JsonResponse
    {
        $rule = AlertRule::find($id);

        if (!$rule) {
            return response()->json([
                'success' => false,
                'message' => 'Alert rule not found',
            ], 404);
        }

        // Temporarily enable rule for testing
        $originalEnabled = $rule->enabled;
        $rule->enabled = true;

        try {
            $alert = $this->ruleEngine->evaluateRule($rule);

            $result = [
                'success' => true,
                'rule' => $rule->fresh(),
                'triggered' => $alert !== null,
                'alert' => $alert,
                'message' => $alert
                    ? 'Rule triggered successfully - alert created'
                    : 'Rule evaluated but did not trigger',
            ];
        } finally {
            // Restore original enabled status
            $rule->enabled = $originalEnabled;
            $rule->save();
        }

        return response()->json($result);
    }
}

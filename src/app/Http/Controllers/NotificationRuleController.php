<?php

namespace App\Http\Controllers;

use App\Models\NotificationRule;
use App\Services\Notifications\NotificationRulesEngine;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class NotificationRuleController extends Controller
{
    public function __construct(
        private NotificationRulesEngine $rulesEngine
    ) {}

    /**
     * Display a listing of notification rules.
     */
    public function index(Request $request): JsonResponse
    {
        $rules = NotificationRule::query()
            ->when($request->enabled !== null, fn($q) => $q->where('enabled', $request->boolean('enabled')))
            ->when($request->event_type, fn($q, $type) => $q->where('event_type', $type))
            ->orderBy('priority', 'desc')
            ->orderBy('name')
            ->with('channel')
            ->get();

        return response()->json([
            'rules' => $rules,
            'event_types' => NotificationRule::distinct('event_type')->pluck('event_type'),
        ]);
    }

    /**
     * Store a newly created rule.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|unique:notification_rules',
            'event_type' => 'required|string|max:100',
            'conditions' => 'required|array',
            'actions' => 'required|array',
            'actions.*.type' => 'required|in:notify,escalate,suppress',
            'actions.*.channel_id' => 'required_if:actions.*.type,notify|exists:notification_channels,id',
            'priority' => 'integer|min:0|max:100',
            'enabled' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $rule = DB::transaction(function () use ($request) {
            $priority = $request->input('priority', NotificationRule::max('priority') + 1);

            return NotificationRule::create([
                'name' => $request->name,
                'event_type' => $request->event_type,
                'conditions' => $request->conditions,
                'actions' => $request->actions,
                'priority' => $priority,
                'enabled' => $request->boolean('enabled', true),
            ]);
        });

        return response()->json([
            'message' => 'Rule created successfully',
            'rule' => $rule->load('channel'),
        ], 201);
    }

    /**
     * Update the specified rule.
     */
    public function update(Request $request, NotificationRule $rule): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255|unique:notification_rules,name,' . $rule->id,
            'conditions' => 'sometimes|array',
            'actions' => 'sometimes|array',
            'actions.*.type' => 'sometimes|in:notify,escalate,suppress',
            'actions.*.channel_id' => 'required_if:actions.*.type,notify|exists:notification_channels,id',
            'priority' => 'integer|min:0|max:100',
            'enabled' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $rule->update($request->only(['name', 'conditions', 'actions', 'priority', 'enabled']));

        return response()->json([
            'message' => 'Rule updated successfully',
            'rule' => $rule->fresh()->load('channel'),
        ]);
    }

    /**
     * Remove the specified rule.
     */
    public function destroy(NotificationRule $rule): JsonResponse
    {
        $rule->delete();

        return response()->json([
            'message' => 'Rule deleted successfully',
        ]);
    }

    /**
     * Reorder rules (drag-drop).
     */
    public function reorder(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'rules' => 'required|array',
            'rules.*.id' => 'required|exists:notification_rules,id',
            'rules.*.priority' => 'required|integer|min:0|max:100',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        DB::transaction(function () use ($request) {
            foreach ($request->rules as $ruleData) {
                NotificationRule::where('id', $ruleData['id'])
                    ->update(['priority' => $ruleData['priority']]);
            }
        });

        return response()->json([
            'message' => 'Rules reordered successfully',
            'rules' => NotificationRule::orderBy('priority', 'desc')->get(),
        ]);
    }

    /**
     * Test rule evaluation.
     */
    public function test(Request $request, NotificationRule $rule): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'event_data' => 'required|array',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $matches = $this->rulesEngine->evaluateConditions(
                $rule->conditions,
                $request->event_data
            );

            $actions = $matches ? $rule->actions : [];

            return response()->json([
                'matches' => $matches,
                'actions' => $actions,
                'rule' => $rule,
                'event_data' => $request->event_data,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Rule evaluation failed',
                'error' => $e->getMessage(),
            ], 500);
        }
    }
}

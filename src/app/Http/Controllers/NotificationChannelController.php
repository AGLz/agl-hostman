<?php

namespace App\Http\Controllers;

use App\Models\NotificationChannel;
use App\Services\Notifications\PagerDutyService;
use App\Services\Notifications\SlackNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\Rule;

class NotificationChannelController extends Controller
{
    /**
     * Display a listing of notification channels.
     */
    public function index(Request $request): JsonResponse
    {
        $channels = NotificationChannel::query()
            ->when($request->type, fn ($q, $type) => $q->where('type', $type))
            ->when($request->enabled !== null, fn ($q) => $q->where('enabled', $request->boolean('enabled')))
            ->withCount(['notifications as total_sent' => fn ($q) => $q->where('status', 'sent')])
            ->withCount(['notifications as failed' => fn ($q) => $q->where('status', 'failed')])
            ->get();

        $statistics = [
            'total_channels' => $channels->count(),
            'active_channels' => $channels->where('enabled', true)->count(),
            'types' => $channels->groupBy('type')->map->count(),
            'total_notifications_sent' => $channels->sum('total_sent'),
            'total_failed' => $channels->sum('failed'),
        ];

        return response()->json([
            'channels' => $channels,
            'statistics' => $statistics,
        ]);
    }

    /**
     * Store a newly created channel.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255|unique:notification_channels',
            'type' => ['required', Rule::in(['slack', 'pagerduty', 'email', 'webhook'])],
            'config' => 'required|array',
            'enabled' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Type-specific validation
        $configValidator = $this->validateConfig($request->type, $request->config);
        if ($configValidator->fails()) {
            return response()->json([
                'message' => 'Configuration validation failed',
                'errors' => $configValidator->errors(),
            ], 422);
        }

        $channel = NotificationChannel::create([
            'name' => $request->name,
            'type' => $request->type,
            'config' => $request->config,
            'enabled' => $request->boolean('enabled', true),
        ]);

        return response()->json([
            'message' => 'Channel created successfully',
            'channel' => $channel,
        ], 201);
    }

    /**
     * Update the specified channel.
     */
    public function update(Request $request, NotificationChannel $channel): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'name' => 'sometimes|string|max:255|unique:notification_channels,name,'.$channel->id,
            'config' => 'sometimes|array',
            'enabled' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        if ($request->has('config')) {
            $configValidator = $this->validateConfig($channel->type, $request->config);
            if ($configValidator->fails()) {
                return response()->json([
                    'message' => 'Configuration validation failed',
                    'errors' => $configValidator->errors(),
                ], 422);
            }
        }

        $channel->update($request->only(['name', 'config', 'enabled']));

        return response()->json([
            'message' => 'Channel updated successfully',
            'channel' => $channel->fresh(),
        ]);
    }

    /**
     * Remove the specified channel.
     */
    public function destroy(NotificationChannel $channel): JsonResponse
    {
        DB::transaction(function () use ($channel) {
            // Disable channel first
            $channel->update(['enabled' => false]);

            // Soft delete
            $channel->delete();
        });

        return response()->json([
            'message' => 'Channel deleted successfully',
        ]);
    }

    /**
     * Test channel connectivity.
     */
    public function test(Request $request, NotificationChannel $channel): JsonResponse
    {
        try {
            $service = match ($channel->type) {
                'slack' => app(SlackNotificationService::class),
                'pagerduty' => app(PagerDutyService::class),
                default => throw new \Exception("Unsupported channel type: {$channel->type}"),
            };

            $testData = [
                'title' => 'Test Notification',
                'message' => 'This is a test notification from AGL-HOSTMAN',
                'severity' => 'info',
                'data' => [
                    'test' => true,
                    'timestamp' => now()->toIso8601String(),
                ],
            ];

            $result = $service->send($testData, $channel);

            return response()->json([
                'message' => 'Test notification sent successfully',
                'result' => $result,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'message' => 'Test notification failed',
                'error' => $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get channel statistics.
     */
    public function statistics(NotificationChannel $channel): JsonResponse
    {
        $stats = [
            'total_sent' => $channel->notifications()->where('status', 'sent')->count(),
            'total_failed' => $channel->notifications()->where('status', 'failed')->count(),
            'last_24h' => $channel->notifications()
                ->where('created_at', '>=', now()->subDay())
                ->count(),
            'success_rate' => $this->calculateSuccessRate($channel),
            'avg_delivery_time' => $this->calculateAvgDeliveryTime($channel),
            'recent_failures' => $channel->notifications()
                ->where('status', 'failed')
                ->orderBy('created_at', 'desc')
                ->limit(10)
                ->get(['id', 'type', 'title', 'error_message', 'created_at']),
        ];

        return response()->json($stats);
    }

    /**
     * Validate channel configuration.
     */
    private function validateConfig(string $type, array $config): \Illuminate\Validation\Validator
    {
        $rules = match ($type) {
            'slack' => [
                'webhook_url' => 'required|url',
                'channel' => 'sometimes|string',
                'username' => 'sometimes|string',
            ],
            'pagerduty' => [
                'integration_key' => 'required|string',
                'severity_mapping' => 'sometimes|array',
            ],
            'email' => [
                'to' => 'required|email',
                'from' => 'sometimes|email',
            ],
            'webhook' => [
                'url' => 'required|url',
                'method' => 'sometimes|in:GET,POST,PUT',
                'headers' => 'sometimes|array',
            ],
            default => [],
        };

        return Validator::make($config, $rules);
    }

    /**
     * Calculate success rate for channel.
     */
    private function calculateSuccessRate(NotificationChannel $channel): float
    {
        $total = $channel->notifications()->count();
        if ($total === 0) {
            return 0.0;
        }

        $sent = $channel->notifications()->where('status', 'sent')->count();

        return round(($sent / $total) * 100, 2);
    }

    /**
     * Calculate average delivery time for channel.
     */
    private function calculateAvgDeliveryTime(NotificationChannel $channel): ?float
    {
        $avg = $channel->notifications()
            ->where('status', 'sent')
            ->whereNotNull('delivered_at')
            ->selectRaw('AVG(TIMESTAMPDIFF(SECOND, created_at, delivered_at)) as avg_time')
            ->value('avg_time');

        return $avg ? round($avg, 2) : null;
    }
}

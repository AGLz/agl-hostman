<?php

namespace App\Http\Controllers;

use App\Events\Notifications\OnCallRotation;
use App\Models\OnCallSchedule;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Carbon\Carbon;

class OnCallScheduleController extends Controller
{
    /**
     * Display a listing of on-call schedules.
     */
    public function index(Request $request): JsonResponse
    {
        $startDate = $request->input('start_date', now()->startOfMonth());
        $endDate = $request->input('end_date', now()->endOfMonth());

        $schedules = OnCallSchedule::query()
            ->whereBetween('start_time', [$startDate, $endDate])
            ->orWhereBetween('end_time', [$startDate, $endDate])
            ->orderBy('start_time')
            ->get();

        return response()->json([
            'schedules' => $schedules,
            'current' => $this->getCurrentOnCall(),
            'next_rotation' => $this->getNextRotation(),
        ]);
    }

    /**
     * Get current on-call engineer.
     */
    public function current(): JsonResponse
    {
        $current = $this->getCurrentOnCall();

        if (!$current) {
            return response()->json([
                'message' => 'No one is currently on-call',
                'current' => null,
            ]);
        }

        return response()->json([
            'current' => $current,
            'time_remaining' => now()->diffInHours($current->end_time) . ' hours',
        ]);
    }

    /**
     * Store a manual override.
     */
    public function store(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'engineer_name' => 'required|string|max:255',
            'engineer_email' => 'required|email',
            'start_time' => 'required|date|after:now',
            'end_time' => 'required|date|after:start_time',
            'reason' => 'sometimes|string|max:500',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        // Check for conflicts
        $conflict = OnCallSchedule::query()
            ->where(function ($q) use ($request) {
                $q->whereBetween('start_time', [$request->start_time, $request->end_time])
                    ->orWhereBetween('end_time', [$request->start_time, $request->end_time])
                    ->orWhere(function ($q2) use ($request) {
                        $q2->where('start_time', '<=', $request->start_time)
                            ->where('end_time', '>=', $request->end_time);
                    });
            })
            ->first();

        if ($conflict) {
            return response()->json([
                'message' => 'Schedule conflict detected',
                'conflict' => $conflict,
            ], 409);
        }

        $schedule = DB::transaction(function () use ($request) {
            $schedule = OnCallSchedule::create([
                'engineer_name' => $request->engineer_name,
                'engineer_email' => $request->engineer_email,
                'start_time' => $request->start_time,
                'end_time' => $request->end_time,
                'is_override' => true,
                'notes' => $request->reason,
            ]);

            event(new OnCallRotation($schedule));

            return $schedule;
        });

        return response()->json([
            'message' => 'On-call override created successfully',
            'schedule' => $schedule,
        ], 201);
    }

    /**
     * Trigger manual rotation.
     */
    public function rotate(Request $request): JsonResponse
    {
        $validator = Validator::make($request->all(), [
            'next_engineer' => 'required|string|max:255',
            'next_email' => 'required|email',
            'duration_hours' => 'required|integer|min:1|max:168', // Max 1 week
        ]);

        if ($validator->fails()) {
            return response()->json([
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $current = $this->getCurrentOnCall();
        $previousEngineer = $current?->engineer_name;

        $schedule = DB::transaction(function () use ($request, $current) {
            // End current schedule early if exists
            if ($current) {
                $current->update(['end_time' => now()]);
            }

            // Create new schedule
            $schedule = OnCallSchedule::create([
                'engineer_name' => $request->next_engineer,
                'engineer_email' => $request->next_email,
                'start_time' => now(),
                'end_time' => now()->addHours($request->duration_hours),
                'is_override' => false,
            ]);

            return $schedule;
        });

        event(new OnCallRotation($schedule, $previousEngineer));

        return response()->json([
            'message' => 'On-call rotation completed successfully',
            'schedule' => $schedule,
            'previous_engineer' => $previousEngineer,
        ]);
    }

    /**
     * Get rotation history.
     */
    public function history(Request $request): JsonResponse
    {
        $limit = $request->input('limit', 50);

        $history = OnCallSchedule::query()
            ->where('end_time', '<', now())
            ->orderBy('end_time', 'desc')
            ->limit($limit)
            ->get();

        $statistics = [
            'total_rotations' => $history->count(),
            'avg_duration' => $this->calculateAvgDuration($history),
            'engineers' => $history->pluck('engineer_name')->unique()->values(),
            'overrides' => $history->where('is_override', true)->count(),
        ];

        return response()->json([
            'history' => $history,
            'statistics' => $statistics,
        ]);
    }

    /**
     * Get current on-call schedule.
     */
    private function getCurrentOnCall(): ?OnCallSchedule
    {
        return OnCallSchedule::query()
            ->where('start_time', '<=', now())
            ->where('end_time', '>=', now())
            ->orderBy('is_override', 'desc')
            ->first();
    }

    /**
     * Get next rotation schedule.
     */
    private function getNextRotation(): ?OnCallSchedule
    {
        return OnCallSchedule::query()
            ->where('start_time', '>', now())
            ->orderBy('start_time')
            ->first();
    }

    /**
     * Calculate average rotation duration.
     */
    private function calculateAvgDuration($schedules): ?float
    {
        if ($schedules->isEmpty()) {
            return null;
        }

        $totalHours = $schedules->sum(function ($schedule) {
            return Carbon::parse($schedule->start_time)
                ->diffInHours(Carbon::parse($schedule->end_time));
        });

        return round($totalHours / $schedules->count(), 2);
    }
}

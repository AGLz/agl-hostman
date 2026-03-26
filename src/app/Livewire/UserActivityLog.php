<?php

namespace App\Livewire;

use App\Models\AuditLog;
use App\Models\User;
use Illuminate\Contracts\View\View;
use Livewire\Component;
use Livewire\WithPagination;

/**
 * User Activity Log Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Display user's activity history with filtering.
 */
class UserActivityLog extends Component
{
    use WithPagination;

    public User $user;

    public string $eventTypeFilter = '';

    public string $severityFilter = '';

    public string $statusFilter = '';

    public int $days = 30;

    public int $perPage = 20;

    protected $queryString = [
        'eventTypeFilter' => ['except' => ''],
        'severityFilter' => ['except' => ''],
        'statusFilter' => ['except' => ''],
        'days' => ['except' => 30],
    ];

    public function mount(User $user)
    {
        $this->authorize('view-audit-logs');
        $this->user = $user;
    }

    public function render(): View
    {
        $query = $this->user->auditLogs()
            ->where('created_at', '>=', now()->subDays($this->days));

        // Apply filters
        if ($this->eventTypeFilter) {
            $query->where('event_type', $this->eventTypeFilter);
        }

        if ($this->severityFilter) {
            $query->where('severity', $this->severityFilter);
        }

        if ($this->statusFilter) {
            $query->where('status', $this->statusFilter);
        }

        $auditLogs = $query->orderBy('created_at', 'desc')
            ->paginate($this->perPage);

        // Get statistics
        $stats = [
            'total_actions' => $this->user->auditLogs()
                ->where('created_at', '>=', now()->subDays($this->days))
                ->count(),
            'failed_actions' => $this->user->auditLogs()
                ->where('created_at', '>=', now()->subDays($this->days))
                ->where('status', AuditLog::STATUS_FAILED)
                ->count(),
            'security_events' => $this->user->auditLogs()
                ->where('created_at', '>=', now()->subDays($this->days))
                ->where('event_type', AuditLog::EVENT_SECURITY)
                ->count(),
        ];

        return view('livewire.user-activity-log', [
            'auditLogs' => $auditLogs,
            'stats' => $stats,
            'eventTypes' => $this->getEventTypes(),
            'severities' => $this->getSeverities(),
            'statuses' => $this->getStatuses(),
        ]);
    }

    public function updatingEventTypeFilter()
    {
        $this->resetPage();
    }

    public function updatingSeverityFilter()
    {
        $this->resetPage();
    }

    public function updatingStatusFilter()
    {
        $this->resetPage();
    }

    public function clearFilters()
    {
        $this->reset(['eventTypeFilter', 'severityFilter', 'statusFilter', 'days']);
        $this->resetPage();
    }

    protected function getEventTypes(): array
    {
        return [
            AuditLog::EVENT_AUTH => 'Authentication',
            AuditLog::EVENT_AUTHORIZATION => 'Authorization',
            AuditLog::EVENT_USER_MANAGEMENT => 'User Management',
            AuditLog::EVENT_ROLE_MANAGEMENT => 'Role Management',
            AuditLog::EVENT_INFRASTRUCTURE => 'Infrastructure',
            AuditLog::EVENT_MONITORING => 'Monitoring',
            AuditLog::EVENT_SECURITY => 'Security',
            AuditLog::EVENT_SYSTEM => 'System',
        ];
    }

    protected function getSeverities(): array
    {
        return [
            AuditLog::SEVERITY_INFO => 'Info',
            AuditLog::SEVERITY_WARNING => 'Warning',
            AuditLog::SEVERITY_ERROR => 'Error',
            AuditLog::SEVERITY_CRITICAL => 'Critical',
        ];
    }

    protected function getStatuses(): array
    {
        return [
            AuditLog::STATUS_SUCCESS => 'Success',
            AuditLog::STATUS_FAILED => 'Failed',
            AuditLog::STATUS_PENDING => 'Pending',
        ];
    }
}

<?php

namespace App\Livewire;

use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Contracts\View\View;
use Livewire\Component;
use Livewire\WithPagination;
use Spatie\Permission\Models\Role;

/**
 * User Table Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Interactive user listing with search, filters, and bulk actions.
 */
class UserTable extends Component
{
    use WithPagination;

    protected UserRepository $userRepository;

    // Filters
    public string $search = '';

    public string $roleFilter = '';

    public string $statusFilter = '';

    public string $sortBy = 'created_at';

    public string $sortOrder = 'desc';

    public int $perPage = 15;

    // Bulk actions
    public array $selectedUsers = [];

    public bool $selectAll = false;

    protected $queryString = [
        'search' => ['except' => ''],
        'roleFilter' => ['except' => ''],
        'statusFilter' => ['except' => ''],
        'sortBy' => ['except' => 'created_at'],
        'sortOrder' => ['except' => 'desc'],
    ];

    public function boot(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    public function mount()
    {
        $this->authorize('view-users');
    }

    public function render(): View
    {
        $filters = [
            'search' => $this->search,
            'role' => $this->roleFilter,
            'is_active' => $this->statusFilter === '' ? null : ($this->statusFilter === 'active'),
            'sort_by' => $this->sortBy,
            'sort_order' => $this->sortOrder,
        ];

        $users = $this->userRepository->getAllUsers($filters, $this->perPage);
        $roles = Role::orderBy('name')->get();

        return view('livewire.user-table', [
            'users' => $users,
            'roles' => $roles,
        ]);
    }

    public function updatingSearch()
    {
        $this->resetPage();
    }

    public function updatingRoleFilter()
    {
        $this->resetPage();
    }

    public function updatingStatusFilter()
    {
        $this->resetPage();
    }

    public function sortBy(string $field)
    {
        if ($this->sortBy === $field) {
            $this->sortOrder = $this->sortOrder === 'asc' ? 'desc' : 'asc';
        } else {
            $this->sortBy = $field;
            $this->sortOrder = 'asc';
        }
    }

    public function clearFilters()
    {
        $this->reset(['search', 'roleFilter', 'statusFilter', 'sortBy', 'sortOrder']);
        $this->resetPage();
    }

    public function toggleSelectAll()
    {
        if ($this->selectAll) {
            $this->selectedUsers = User::pluck('id')->toArray();
        } else {
            $this->selectedUsers = [];
        }
    }

    public function bulkActivate()
    {
        $this->authorize('activate-deactivate-users');

        foreach ($this->selectedUsers as $userId) {
            $user = User::find($userId);
            if ($user && ! $user->is_active) {
                $this->userRepository->activateUser($user, auth()->user());
            }
        }

        $this->selectedUsers = [];
        $this->selectAll = false;

        session()->flash('success', __('Selected users activated successfully.'));
    }

    public function bulkDeactivate()
    {
        $this->authorize('activate-deactivate-users');

        foreach ($this->selectedUsers as $userId) {
            $user = User::find($userId);
            if ($user && $user->is_active && $user->id !== auth()->id()) {
                try {
                    $this->userRepository->deactivateUser($user, auth()->user());
                } catch (\Exception $e) {
                    session()->flash('error', $e->getMessage());

                    return;
                }
            }
        }

        $this->selectedUsers = [];
        $this->selectAll = false;

        session()->flash('success', __('Selected users deactivated successfully.'));
    }

    public function deleteUser(int $userId)
    {
        $this->authorize('delete-users');

        $user = User::findOrFail($userId);

        try {
            $this->userRepository->deleteUser($user, auth()->user());
            session()->flash('success', __('User deleted successfully.'));
        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }
}

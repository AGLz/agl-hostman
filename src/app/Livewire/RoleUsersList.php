<?php

namespace App\Livewire;

use Illuminate\Contracts\View\View;
use Livewire\Component;
use Livewire\WithPagination;
use Spatie\Permission\Models\Role;

/**
 * Role Users List Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Display users assigned to a specific role.
 */
class RoleUsersList extends Component
{
    use WithPagination;

    public Role $role;
    public string $search = '';
    public int $perPage = 15;

    protected $queryString = [
        'search' => ['except' => ''],
    ];

    public function mount(Role $role)
    {
        $this->authorize('view-roles');
        $this->role = $role;
    }

    public function render(): View
    {
        $query = $this->role->users()->with('physicalLocations');

        if ($this->search) {
            $query->where(function ($q) {
                $q->where('name', 'like', "%{$this->search}%")
                  ->orWhere('email', 'like', "%{$this->search}%");
            });
        }

        $users = $query->orderBy('name')
            ->paginate($this->perPage);

        return view('livewire.role-users-list', [
            'users' => $users,
        ]);
    }

    public function updatingSearch()
    {
        $this->resetPage();
    }

    public function clearSearch()
    {
        $this->reset('search');
        $this->resetPage();
    }
}

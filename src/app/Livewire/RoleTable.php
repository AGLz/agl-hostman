<?php

namespace App\Livewire;

use Illuminate\Contracts\View\View;
use Livewire\Component;
use Livewire\WithPagination;
use Spatie\Permission\Models\Role;

/**
 * Role Table Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Interactive role listing with user counts and permission management.
 */
class RoleTable extends Component
{
    use WithPagination;

    public string $search = '';
    public string $sortBy = 'name';
    public string $sortOrder = 'asc';

    protected $queryString = [
        'search' => ['except' => ''],
        'sortBy' => ['except' => 'name'],
        'sortOrder' => ['except' => 'asc'],
    ];

    public function mount()
    {
        $this->authorize('view-roles');
    }

    public function render(): View
    {
        $query = Role::withCount(['users', 'permissions']);

        if ($this->search) {
            $query->where('name', 'like', "%{$this->search}%");
        }

        $query->orderBy($this->sortBy, $this->sortOrder);

        $roles = $query->paginate(15);

        // Get system roles (cannot be deleted)
        $systemRoles = ['super-admin', 'admin', 'operator', 'analyst', 'viewer'];

        return view('livewire.role-table', [
            'roles' => $roles,
            'systemRoles' => $systemRoles,
        ]);
    }

    public function updatingSearch()
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

    public function clearSearch()
    {
        $this->reset('search');
        $this->resetPage();
    }
}

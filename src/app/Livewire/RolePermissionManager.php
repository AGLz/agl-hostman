<?php

namespace App\Livewire;

use App\Models\AuditLog;
use Illuminate\Contracts\View\View;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Livewire\Component;
use Spatie\Permission\Models\Permission;
use Spatie\Permission\Models\Role;

/**
 * Role Permission Manager Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Manage role permissions with grouped display and quick toggles.
 */
class RolePermissionManager extends Component
{
    public Role $role;

    public array $selectedPermissions = [];

    public bool $showModal = false;

    protected $listeners = ['refreshPermissions' => '$refresh'];

    public function mount(Role $role)
    {
        $this->authorize('assign-permissions');
        $this->role = $role;
        $this->selectedPermissions = $role->permissions->pluck('name')->toArray();
    }

    public function render(): View
    {
        $permissions = Permission::orderBy('name')->get();

        // Group permissions by prefix
        $groupedPermissions = $permissions->groupBy(function ($permission) {
            $parts = explode('-', $permission->name);

            return $parts[0] ?? 'other';
        });

        return view('livewire.role-permission-manager', [
            'groupedPermissions' => $groupedPermissions,
        ]);
    }

    public function togglePermission(string $permissionName)
    {
        if (in_array($permissionName, $this->selectedPermissions)) {
            $this->selectedPermissions = array_diff($this->selectedPermissions, [$permissionName]);
        } else {
            $this->selectedPermissions[] = $permissionName;
        }
    }

    public function selectAllInGroup(string $group)
    {
        $permissions = Permission::orderBy('name')->get();

        $groupPermissions = $permissions->filter(function ($permission) use ($group) {
            $parts = explode('-', $permission->name);

            return ($parts[0] ?? 'other') === $group;
        })->pluck('name')->toArray();

        $this->selectedPermissions = array_unique(array_merge($this->selectedPermissions, $groupPermissions));
    }

    public function deselectAllInGroup(string $group)
    {
        $permissions = Permission::orderBy('name')->get();

        $groupPermissions = $permissions->filter(function ($permission) use ($group) {
            $parts = explode('-', $permission->name);

            return ($parts[0] ?? 'other') === $group;
        })->pluck('name')->toArray();

        $this->selectedPermissions = array_diff($this->selectedPermissions, $groupPermissions);
    }

    public function savePermissions()
    {
        // Prevent modification of system roles
        if (in_array($this->role->name, ['super-admin', 'admin'])) {
            session()->flash('error', __('Cannot modify permissions for system roles.'));

            return;
        }

        DB::beginTransaction();

        try {
            $oldPermissions = $this->role->permissions->pluck('name')->toArray();

            // Sync permissions
            $this->role->syncPermissions($this->selectedPermissions);

            // Log permission changes
            AuditLog::record([
                'user_id' => Auth::id(),
                'event_type' => AuditLog::EVENT_ROLE_MANAGEMENT,
                'event_category' => 'permissions_updated',
                'action' => 'update',
                'description' => "Permissions updated for role '{$this->role->name}'",
                'metadata' => [
                    'role_name' => $this->role->name,
                    'old_permissions' => $oldPermissions,
                    'new_permissions' => $this->selectedPermissions,
                    'added' => array_diff($this->selectedPermissions, $oldPermissions),
                    'removed' => array_diff($oldPermissions, $this->selectedPermissions),
                ],
            ]);

            DB::commit();

            $this->role->refresh();
            $this->showModal = false;

            $this->dispatch('permissions-updated', [
                'message' => __('Permissions updated successfully.'),
            ]);

            session()->flash('success', __('Permissions updated successfully.'));

        } catch (\Exception $e) {
            DB::rollBack();
            session()->flash('error', __('Failed to update permissions: :message', ['message' => $e->getMessage()]));
        }
    }

    public function openModal()
    {
        $this->showModal = true;
    }

    public function closeModal()
    {
        $this->showModal = false;
        $this->selectedPermissions = $this->role->permissions->pluck('name')->toArray();
    }
}

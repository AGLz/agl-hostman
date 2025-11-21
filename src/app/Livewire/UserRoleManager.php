<?php

namespace App\Livewire;

use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Contracts\View\View;
use Livewire\Component;
use Spatie\Permission\Models\Role;

/**
 * User Role Manager Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Manage user roles and permissions dynamically.
 */
class UserRoleManager extends Component
{
    protected UserRepository $userRepository;

    public User $user;
    public string $selectedRole = '';
    public bool $showModal = false;

    protected $rules = [
        'selectedRole' => 'required|exists:roles,name',
    ];

    public function boot(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    public function mount(User $user)
    {
        $this->authorize('assign-roles');
        $this->user = $user;
        $this->selectedRole = $user->roles->first()?->name ?? '';
    }

    public function render(): View
    {
        $roles = Role::orderBy('name')->get();
        $this->user->load('roles');

        return view('livewire.user-role-manager', [
            'roles' => $roles,
        ]);
    }

    public function assignRole()
    {
        $this->validate();

        try {
            $this->userRepository->assignRole(
                $this->user,
                $this->selectedRole,
                auth()->user()
            );

            $this->user->refresh();
            $this->showModal = false;

            $this->dispatch('role-assigned', [
                'message' => __('Role assigned successfully.'),
            ]);

            session()->flash('success', __('Role assigned successfully.'));

        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }

    public function removeRole(string $roleName)
    {
        try {
            $this->userRepository->removeRole(
                $this->user,
                $roleName,
                auth()->user()
            );

            $this->user->refresh();
            $this->selectedRole = $this->user->roles->first()?->name ?? '';

            $this->dispatch('role-removed', [
                'message' => __('Role removed successfully.'),
            ]);

            session()->flash('success', __('Role removed successfully.'));

        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }

    public function openModal()
    {
        $this->showModal = true;
    }

    public function closeModal()
    {
        $this->showModal = false;
        $this->reset('selectedRole');
    }
}

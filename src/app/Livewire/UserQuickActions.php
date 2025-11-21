<?php

namespace App\Livewire;

use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Contracts\View\View;
use Livewire\Component;

/**
 * User Quick Actions Livewire Component
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Quick action buttons for user management (activate, deactivate, etc.).
 */
class UserQuickActions extends Component
{
    protected UserRepository $userRepository;

    public User $user;
    public bool $confirmingAction = false;
    public string $actionType = '';

    public function boot(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    public function mount(User $user)
    {
        $this->user = $user;
    }

    public function render(): View
    {
        return view('livewire.user-quick-actions');
    }

    public function confirmAction(string $action)
    {
        $this->actionType = $action;
        $this->confirmingAction = true;
    }

    public function cancelAction()
    {
        $this->confirmingAction = false;
        $this->actionType = '';
    }

    public function activate()
    {
        try {
            $this->authorize('activate-deactivate-users');

            $this->userRepository->activateUser($this->user, auth()->user());
            $this->user->refresh();

            $this->confirmingAction = false;
            $this->actionType = '';

            $this->dispatch('user-updated', [
                'message' => __('User activated successfully.'),
            ]);

            session()->flash('success', __('User activated successfully.'));

        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }

    public function deactivate()
    {
        try {
            $this->authorize('activate-deactivate-users');

            $this->userRepository->deactivateUser($this->user, auth()->user());
            $this->user->refresh();

            $this->confirmingAction = false;
            $this->actionType = '';

            $this->dispatch('user-updated', [
                'message' => __('User deactivated successfully.'),
            ]);

            session()->flash('success', __('User deactivated successfully.'));

        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }

    public function delete()
    {
        try {
            $this->authorize('delete-users');

            $this->userRepository->deleteUser($this->user, auth()->user());

            $this->confirmingAction = false;
            $this->actionType = '';

            $this->dispatch('user-deleted', [
                'userId' => $this->user->id,
                'message' => __('User deleted successfully.'),
            ]);

            return redirect()->route('users.index')
                ->with('success', __('User deleted successfully.'));

        } catch (\Exception $e) {
            session()->flash('error', $e->getMessage());
        }
    }

    public function impersonate()
    {
        $this->authorize('admin-access');

        if (!$this->user->isActive()) {
            session()->flash('error', __('Cannot impersonate inactive user.'));
            return;
        }

        if ($this->user->isSuperAdmin() && !auth()->user()->isSuperAdmin()) {
            session()->flash('error', __('Cannot impersonate super admin.'));
            return;
        }

        // Store original user ID in session
        session()->put('impersonate_from', auth()->id());

        // Login as the target user
        auth()->loginUsingId($this->user->id);

        return redirect()->route('monitoring.index')
            ->with('success', __('You are now impersonating :name', ['name' => $this->user->name]));
    }
}

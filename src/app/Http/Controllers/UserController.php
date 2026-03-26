<?php

namespace App\Http\Controllers;

use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Validation\Rules\Password;
use Illuminate\View\View;
use Spatie\Permission\Models\Role;

/**
 * User Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles user management operations (CRUD, activation, role assignment).
 * Requires 'manage-users' or specific user permissions.
 */
class UserController extends Controller
{
    protected UserRepository $userRepository;

    public function __construct(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;

        // Apply middleware
        $this->middleware('auth');
        $this->middleware('active');
        $this->middleware('permission:view-users')->only(['index', 'show']);
        $this->middleware('permission:create-users')->only(['create', 'store']);
        $this->middleware('permission:edit-users')->only(['edit', 'update']);
        $this->middleware('permission:delete-users')->only(['destroy']);
        $this->middleware('permission:activate-deactivate-users')->only(['activate', 'deactivate']);
        $this->middleware('permission:assign-roles')->only(['assignRole', 'removeRole']);
    }

    /**
     * Display a listing of users
     */
    public function index(Request $request): View
    {
        $filters = $request->only(['search', 'role', 'is_active', 'location_code', 'sort_by', 'sort_order']);
        $perPage = $request->input('per_page', 15);

        $users = $this->userRepository->getAllUsers($filters, $perPage);
        $roles = Role::all();

        return view('users.index', [
            'users' => $users,
            'roles' => $roles,
            'filters' => $filters,
        ]);
    }

    /**
     * Show the form for creating a new user
     */
    public function create(): View
    {
        $roles = Role::all();

        return view('users.create', [
            'roles' => $roles,
        ]);
    }

    /**
     * Store a newly created user
     */
    public function store(Request $request): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'confirmed', Password::defaults()],
            'role' => ['required', 'string', 'exists:roles,name'],
            'is_active' => ['boolean'],
        ]);

        try {
            $user = $this->userRepository->createUser(
                $validated,
                Auth::user()
            );

            return redirect()->route('users.show', $user)
                ->with('success', __('User created successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withInput()
                ->withErrors(['error' => __('Failed to create user: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Display the specified user
     */
    public function show(User $user): View
    {
        $user->load(['roles', 'permissions', 'physicalLocations']);

        // Get user activity statistics
        $activityStats = $this->userRepository->getUserActivityStats($user, 30);

        return view('users.show', [
            'user' => $user,
            'activityStats' => $activityStats,
        ]);
    }

    /**
     * Show the form for editing the specified user
     */
    public function edit(User $user): View
    {
        $user->load(['roles', 'physicalLocations']);
        $roles = Role::all();

        return view('users.edit', [
            'user' => $user,
            'roles' => $roles,
        ]);
    }

    /**
     * Update the specified user
     */
    public function update(Request $request, User $user): RedirectResponse
    {
        $validated = $request->validate([
            'name' => ['sometimes', 'string', 'max:255'],
            'email' => ['sometimes', 'string', 'email', 'max:255', 'unique:users,email,'.$user->id],
            'password' => ['sometimes', 'nullable', 'confirmed', Password::defaults()],
        ]);

        // Remove password if not provided
        if (empty($validated['password'])) {
            unset($validated['password']);
        }

        try {
            $updatedUser = $this->userRepository->updateUser(
                $user,
                $validated,
                Auth::user()
            );

            return redirect()->route('users.show', $updatedUser)
                ->with('success', __('User updated successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withInput()
                ->withErrors(['error' => __('Failed to update user: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Remove the specified user
     */
    public function destroy(User $user): RedirectResponse
    {
        try {
            $this->userRepository->deleteUser($user, Auth::user());

            return redirect()->route('users.index')
                ->with('success', __('User deleted successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withErrors(['error' => __('Failed to delete user: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Activate a user account
     */
    public function activate(User $user): RedirectResponse
    {
        try {
            $this->userRepository->activateUser($user, Auth::user());

            return back()
                ->with('success', __('User activated successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withErrors(['error' => __('Failed to activate user: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Deactivate a user account
     */
    public function deactivate(User $user): RedirectResponse
    {
        try {
            $this->userRepository->deactivateUser($user, Auth::user());

            return back()
                ->with('success', __('User deactivated successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withErrors(['error' => __('Failed to deactivate user: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Assign a role to a user
     */
    public function assignRole(Request $request, User $user): RedirectResponse
    {
        $validated = $request->validate([
            'role' => ['required', 'string', 'exists:roles,name'],
        ]);

        try {
            $this->userRepository->assignRole(
                $user,
                $validated['role'],
                Auth::user()
            );

            return back()
                ->with('success', __('Role assigned successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withErrors(['error' => __('Failed to assign role: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Remove a role from a user
     */
    public function removeRole(Request $request, User $user): RedirectResponse
    {
        $validated = $request->validate([
            'role' => ['required', 'string', 'exists:roles,name'],
        ]);

        try {
            $this->userRepository->removeRole(
                $user,
                $validated['role'],
                Auth::user()
            );

            return back()
                ->with('success', __('Role removed successfully.'));

        } catch (\Exception $e) {
            return back()
                ->withErrors(['error' => __('Failed to remove role: :message', ['message' => $e->getMessage()])]);
        }
    }

    /**
     * Display user's audit log
     */
    public function auditLog(User $user): View
    {
        $this->authorize('view-audit-logs');

        $auditLogs = $user->auditLogs()
            ->with('user')
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return view('users.audit-log', [
            'user' => $user,
            'auditLogs' => $auditLogs,
        ]);
    }
}

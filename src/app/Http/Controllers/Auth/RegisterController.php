<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use App\Models\User;
use App\Repositories\UserRepository;
use Illuminate\Auth\Events\Registered;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rules\Password;
use Illuminate\View\View;

/**
 * Register Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles new user registration with automatic role assignment.
 */
class RegisterController extends Controller
{
    protected UserRepository $userRepository;

    public function __construct(UserRepository $userRepository)
    {
        $this->userRepository = $userRepository;
    }

    /**
     * Display the registration form
     */
    public function showRegistrationForm(): View
    {
        return view('auth.register');
    }

    /**
     * Handle registration request
     */
    public function register(Request $request): RedirectResponse
    {
        $request->validate([
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'string', 'email', 'max:255', 'unique:users'],
            'password' => ['required', 'confirmed', Password::defaults()],
        ]);

        try {
            // Create user with default viewer role
            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'is_active' => true,
            ]);

            // Assign default role (viewer - lowest privileges)
            $user->assignRole('viewer');

            // Log registration
            AuditLog::logAuth(
                $user,
                AuditLog::CATEGORY_USER_CREATED,
                AuditLog::STATUS_SUCCESS,
                [
                    'email' => $user->email,
                    'default_role' => 'viewer',
                    'registration_method' => 'self_registration',
                ]
            );

            // Fire registered event
            event(new Registered($user));

            // Auto-login the user
            Auth::login($user);

            return redirect()->route('home')
                ->with('success', __('Registration successful! Welcome to AGL Infrastructure Admin Platform.'));

        } catch (\Exception $e) {
            // Log failed registration
            AuditLog::record([
                'event_type' => AuditLog::EVENT_AUTH,
                'event_category' => AuditLog::CATEGORY_USER_CREATED,
                'action' => 'registration_failed',
                'description' => 'User registration failed',
                'status' => AuditLog::STATUS_FAILED,
                'severity' => AuditLog::SEVERITY_ERROR,
                'metadata' => [
                    'email' => $request->email,
                    'error' => $e->getMessage(),
                ],
            ]);

            return back()
                ->withInput($request->only('name', 'email'))
                ->withErrors(['email' => __('Registration failed. Please try again.')]);
        }
    }
}

<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Http\RedirectResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\Str;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Login Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles user authentication with audit logging and rate limiting.
 */
class LoginController extends Controller
{
    /**
     * Display the login form
     *
     * @return View
     */
    public function showLoginForm(): View
    {
        return view('auth.login');
    }

    /**
     * Handle login request
     *
     * @param Request $request
     * @return RedirectResponse
     * @throws ValidationException
     */
    public function login(Request $request): RedirectResponse
    {
        $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string'],
        ]);

        // Check rate limiting
        $this->ensureIsNotRateLimited($request);

        // Attempt authentication
        $credentials = $request->only('email', 'password');
        $remember = $request->boolean('remember');

        if (Auth::attempt($credentials, $remember)) {
            $request->session()->regenerate();

            $user = Auth::user();

            // Check if user is active
            if (!$user->isActive()) {
                Auth::logout();

                // Log failed login attempt
                AuditLog::logAuth(
                    $user,
                    AuditLog::CATEGORY_LOGIN_FAILED,
                    AuditLog::STATUS_FAILED,
                    [
                        'reason' => 'inactive_account',
                        'email' => $request->email,
                    ]
                );

                throw ValidationException::withMessages([
                    'email' => __('Your account has been deactivated. Please contact an administrator.'),
                ]);
            }

            // Update last login timestamp
            $user->updateLastLogin();

            // Log successful login
            AuditLog::logAuth(
                $user,
                AuditLog::CATEGORY_LOGIN,
                AuditLog::STATUS_SUCCESS,
                [
                    'email' => $user->email,
                    'remember' => $remember,
                ]
            );

            // Clear rate limiter
            RateLimiter::clear($this->throttleKey($request));

            // Redirect based on role
            return $this->redirectToDashboard($user);
        }

        // Increment rate limiter
        RateLimiter::hit($this->throttleKey($request));

        // Log failed login attempt
        AuditLog::logAuth(
            null,
            AuditLog::CATEGORY_LOGIN_FAILED,
            AuditLog::STATUS_FAILED,
            [
                'email' => $request->email,
                'reason' => 'invalid_credentials',
            ]
        );

        throw ValidationException::withMessages([
            'email' => __('These credentials do not match our records.'),
        ]);
    }

    /**
     * Handle logout request
     *
     * @param Request $request
     * @return RedirectResponse
     */
    public function logout(Request $request): RedirectResponse
    {
        $user = Auth::user();

        // Log logout
        if ($user) {
            AuditLog::logAuth(
                $user,
                AuditLog::CATEGORY_LOGOUT,
                AuditLog::STATUS_SUCCESS,
                [
                    'email' => $user->email,
                ]
            );
        }

        Auth::logout();

        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect()->route('login')
            ->with('status', __('You have been logged out successfully.'));
    }

    /**
     * Ensure the login request is not rate limited
     *
     * @param Request $request
     * @return void
     * @throws ValidationException
     */
    protected function ensureIsNotRateLimited(Request $request): void
    {
        if (!RateLimiter::tooManyAttempts($this->throttleKey($request), 5)) {
            return;
        }

        $seconds = RateLimiter::availableIn($this->throttleKey($request));

        // Log rate limit event
        AuditLog::logAuth(
            null,
            AuditLog::CATEGORY_LOGIN_FAILED,
            AuditLog::STATUS_FAILED,
            [
                'email' => $request->email,
                'reason' => 'rate_limited',
                'retry_after' => $seconds,
            ]
        );

        throw ValidationException::withMessages([
            'email' => trans('auth.throttle', [
                'seconds' => $seconds,
                'minutes' => ceil($seconds / 60),
            ]),
        ]);
    }

    /**
     * Get the rate limiting throttle key for the request
     *
     * @param Request $request
     * @return string
     */
    protected function throttleKey(Request $request): string
    {
        return Str::transliterate(Str::lower($request->input('email')) . '|' . $request->ip());
    }

    /**
     * Redirect to appropriate dashboard based on user role
     *
     * @param \App\Models\User $user
     * @return RedirectResponse
     */
    protected function redirectToDashboard($user): RedirectResponse
    {
        // Check user permissions and redirect accordingly
        if ($user->canAccessDashboard()) {
            return redirect()->intended(route('monitoring.index'))
                ->with('success', __('Welcome back, :name!', ['name' => $user->name]));
        }

        // Fallback to home/profile if no dashboard access
        return redirect()->route('home')
            ->with('success', __('Welcome back, :name!', ['name' => $user->name]));
    }
}

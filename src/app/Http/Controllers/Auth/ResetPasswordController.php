<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\AuditLog;
use Illuminate\Auth\Events\PasswordReset;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Password;
use Illuminate\Support\Str;
use Illuminate\Validation\Rules\Password as PasswordRule;
use Illuminate\Validation\ValidationException;
use Illuminate\View\View;

/**
 * Reset Password Controller
 * AGL Infrastructure Admin Platform - Phase 5
 *
 * Handles password reset with audit logging.
 */
class ResetPasswordController extends Controller
{
    /**
     * Display the password reset form
     */
    public function showResetForm(Request $request): View
    {
        return view('auth.reset-password', [
            'token' => $request->route('token'),
            'email' => $request->email,
        ]);
    }

    /**
     * Handle password reset request
     *
     * @throws ValidationException
     */
    public function reset(Request $request): RedirectResponse
    {
        $request->validate([
            'token' => ['required'],
            'email' => ['required', 'email'],
            'password' => ['required', 'confirmed', PasswordRule::defaults()],
        ]);

        // Attempt to reset password
        $status = Password::reset(
            $request->only('email', 'password', 'password_confirmation', 'token'),
            function ($user) use ($request) {
                $user->forceFill([
                    'password' => Hash::make($request->password),
                    'remember_token' => Str::random(60),
                ])->save();

                // Log successful password reset
                AuditLog::logAuth(
                    $user,
                    AuditLog::CATEGORY_PASSWORD_RESET,
                    AuditLog::STATUS_SUCCESS,
                    [
                        'email' => $user->email,
                        'action' => 'password_reset_completed',
                    ]
                );

                event(new PasswordReset($user));
            }
        );

        if ($status === Password::PASSWORD_RESET) {
            return redirect()->route('login')
                ->with('status', __('Your password has been reset successfully. Please login with your new password.'));
        }

        // Log failed password reset
        AuditLog::record([
            'event_type' => AuditLog::EVENT_AUTH,
            'event_category' => AuditLog::CATEGORY_PASSWORD_RESET,
            'action' => 'password_reset_failed',
            'description' => 'Password reset failed',
            'status' => AuditLog::STATUS_FAILED,
            'severity' => AuditLog::SEVERITY_WARNING,
            'metadata' => [
                'email' => $request->email,
                'reason' => $status,
            ],
        ]);

        throw ValidationException::withMessages([
            'email' => [__($status)],
        ]);
    }
}
